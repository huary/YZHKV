//
//  YZHKV.m
//  YZHKVDemo
//
//  Created by yuan on 2019/6/30.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHKV.h"
#import <string.h>
#import <sys/mman.h>
#import <zlib.h>
#import <CommonCrypto/CommonDigest.h>

#import "YZHCoder.h"
#import "YZHCodeData.h"
#import "YZHKVUtils.h"
#import "YZHMachTimeUtils.h"
#import "macro.h"

static int DEFAULT_PAGE_SIZE_s;
static int MIN_MMAP_SIZE_s;     //64KB


#define DEFAULT_YZHKV_NAME              @"yzh.kv.default"
#define YZHKV_CODE_DATA_HEAD_SIZE       (128)
#define YZHKV_CONTENT_HEADER_SIZE       (128)

//在keyItem为y1000个以上的时候可以进行回写
#define YZHKV_FULL_WRITE_BACK_KEY_MIN_CNT                   (1000)
//在keyItem占据CodeItem的比例小于0.5的时候可以进行回写
#define YZHKV_FULL_WRITE_BACK_KEY_CNT_WITH_CODE_CNT_MAX_RATIO   (0.5)

#define YZHKV_CRC_SIZE                  (134217728) //128MB

#define YZHKV_CHECK_CODE_QUEUE         //NSAssert([self _isInCodeQueue], @"must execute in codeQueue")

#define YZHKV_IS_FILE_OPEN              (self->_fd > 0 && self->_size > 0 && self->_ptr && self->_ptr != MAP_FAILED)

NSString *const _YZHKVErrorDomain = @"YZHKVErrorDomain";


typedef NS_ENUM(uint32_t, _YZHHeaderOffset)
{
    _YZHHeaderOffsetVersion             = 0,
    _YZHHeaderOffsetSize                = 2,
    _YZHHeaderOffsetKeyItemCnt          = 10,
    _YZHHeaderOffsetCodeItemCnt         = 14,
    _YZHHeaderOffsetCodeContentCRC      = 18,
    _YZHHeaderOffsetCryptor             = 22,
    _YZHHeaderOffsetKeyHash             = 23,
};

typedef NS_ENUM(uint8_t, _YZHHashType)
{
    _YZHHashTypeMD2         = 1,
    _YZHHashTypeMD4         = 2,
    _YZHHashTypeMD5         = 3,
    _YZHHashTypeSHA1        = 4,
    _YZHHashTypeSHA224      = 5,
    _YZHHashTypeSHA256      = 6,
    _YZHHashTypeSHA384      = 7,
    _YZHHashTypeSHA512      = 8,
    _YZHHashTypeSHA3        = 9,
};

typedef NS_ENUM(NSInteger, _YZHCryptorType)
{
    _YZHCryptorTypeAES = 0,
};

//内部错误,从2^16次方开始
typedef NS_ENUM(NSInteger, _YZHKVInterError)
{
    //密码长度错误
    _YZHKVInterErrorKeySizeError        = 65536,
    //加密模式错误
    _YZHKVInterErrorCryptModeError      = 65537,
};

typedef NS_ENUM(NSInteger, _YZHKVCacheObjectType)
{
    //空
    _YZHKVCacheObjectTypeNone           = 0,
    //这个对于无密码时的
    _YZHKVCacheObjectTypeDataRange      = 1,
    //这个是解码后对象
    _YZHKVCacheObjectTypeDecodeObject   = 2,
    //这个是明文的data
    _YZHKVCacheObjectTypePlainData      = 3,
};


static inline void _sync_lock(dispatch_semaphore_t lock, void (^block)(void)) {
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    if (block) {
        block();
    }
    dispatch_semaphore_signal(lock);
}

typedef id(^YZHKVCodeBlock)(YZHKV *kv);
typedef void(^YZHKVCodeCompletionBlock)(YZHKV *kv, id result);




/**********************************************************************
 *_YZHKVCacheObject
 * objectType == _YZHKVCacheObjectTypeDataRange，记录dataRange
 * objectType == _YZHKVCacheObjectTypeDecodeObject,记录decodeObject
 * objectType == _YZHKVCacheObjectTypePlainData, 记录objectData
 *对于密文的时候，记录的是解码后的对象
 ***********************************************************************/
@interface _YZHKVCacheObject : NSObject

@property (nonatomic, assign, readonly) _YZHKVCacheObjectType objectType;

@property (nonatomic, assign, readonly) NSRange dataRange;

@end

@implementation _YZHKVCacheObject
{
@private
    id _object;
}

- (id)decodeObject
{
    return _object;
}

- (NSData*)objectData
{
    return (NSData*)_object;
}

- (id)object
{
    return _object;
}

- (void)setObject:(id)object withObjectType:(_YZHKVCacheObjectType)objectType
{
    if (objectType == _YZHKVCacheObjectTypeNone) {
        _object = nil;
        _objectType = objectType;
    }
    else if (objectType == _YZHKVCacheObjectTypeDecodeObject) {
        if ([object isKindOfClass:[NSObject class]]) {
            _object = object;
            _objectType = objectType;
        }
    }
    else if (objectType == _YZHKVCacheObjectTypePlainData) {
        if ([object isKindOfClass:[NSData class]]) {
            _object = object;
            _objectType = objectType;
        }
    }
}

- (void)setRange:(NSRange)range
{
    _dataRange = range;
    _objectType = _YZHKVCacheObjectTypeDataRange;
}

@end



/**********************************************************************
 *
 *|---2字节(version)---|---8字节(size)---|---4字节(keyItemCnt)---|---4字节(codeItemCnt)---|---4字节(crc)---|---1字节(cryptor)---|
 *|---32字节keyHash(sha256)---|---73字节(保留)---|
 *
 *其中---1字节(cryptor)---如下：
 *|---6bit的加密模式（YZHCryptMode）,2bit的keytype（YZHAESKeyType+1）---|
 *
 ***********************************************************************/

@interface YZHKV ()
{
@private
    int _fd;
    int64_t _size;
    uint8_t *_ptr;
    uint16_t _version;
    int64_t _codeSize;
    uint32_t _keyItemCnt;
    uint32_t _codeItemCnt;
    uint32_t _codeContentCRC;
    uint8_t _cryptorInfo;
    uint8_t _hashKey[CC_SHA256_DIGEST_LENGTH];
    
    YZHCodeData *_headerData;
    YZHCodeData *_contentData;
    YZHAESCryptor *_cryptor;
}

@property (nonatomic, copy) NSString *filePath;

@property (nonatomic, strong) NSMutableDictionary<id, _YZHKVCacheObject*> *dict;

@property (nonatomic, strong) dispatch_semaphore_t lock;

@property (nonatomic, strong) NSError *lastError;

@property (nonatomic, strong) YZHMutableCodeData *tmpCodeData;

@end

@implementation YZHKV

+ (void)initialize
{
    if (self == YZHKV.class) {
        DEFAULT_PAGE_SIZE_s = getpagesize();
        MIN_MMAP_SIZE_s = TYPE_LS(DEFAULT_PAGE_SIZE_s, 5);//64KB //DEFAULT_PAGE_SIZE_s * 16;
    }
}

- (instancetype)init
{
    self =[super init];
    if (self) {
        [self _setupDefault];
    }
    return self;
}

- (void)_setupDefault
{
    _fd = 0;
    _size = 0;
    _ptr = NULL;
    _version = 1;
    _codeSize = 0;
    _keyItemCnt = 0;
    _codeItemCnt = 0;
    _codeContentCRC = 0;
    memset(_hashKey, 0, sizeof(_hashKey));
    
    _headerData = NULL;
    _contentData = NULL;
}

- (NSMutableDictionary<id, _YZHKVCacheObject*>*)dict
{
    if (_dict == nil) {
        _dict = [NSMutableDictionary dictionary];
    }
    return _dict;
}

- (dispatch_semaphore_t)lock
{
    if (_lock == nil) {
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (YZHMutableCodeData*)tmpCodeData
{
    if (_tmpCodeData == nil) {
        _tmpCodeData = [[YZHMutableCodeData alloc] init];
    }
    return _tmpCodeData;
}

+ (instancetype)defaultKV
{
    return [[YZHKV alloc] initWithName:DEFAULT_YZHKV_NAME path:nil];
}

- (instancetype)initWithName:(NSString*)name path:(NSString*)path
{
    return [self initWithName:name path:path cryptKey:nil];
}

- (instancetype)initWithName:(NSString *)name path:(NSString *)path cryptKey:(NSData *)cryptKey
{
    self = [self init];
    if (self) {
        name = name ? name : DEFAULT_YZHKV_NAME;
        if (path.length == 0) {
            path = [YZHKVUtils applicationDocumentsDirectory:nil];
        }
        
        self.filePath = [path stringByAppendingPathComponent:name];
        
        [YZHMachTimeUtils recordPointWithText:@"开始创建文件夹"];
        
        [YZHKVUtils checkAndMakeDirectory:[self.filePath stringByDeletingLastPathComponent]];
        
        [YZHMachTimeUtils recordPointWithText:@"创建文件夹结束"];
        
        _sync_lock(self.lock, ^{
            [YZHMachTimeUtils recordPointWithText:@"开始加载文件"];
            NSMutableDictionary *dict = [self _loadFromFileWithCryptKey:cryptKey];
            self.dict = dict;
            NSLog(@"dict.count=%ld",dict.count);
        });
    }
    return self;
}

- (void)_readHeaderInfo
{
    YZHKV_CHECK_CODE_QUEUE;
    if (self->_headerData == nil) {
        return;
    }
    [self->_headerData seek:YZHDataSeekTypeSET];
    self->_version = [self->_headerData readLittleEndian16];
    self->_codeSize = [self->_headerData readLittleEndian64];
    self->_keyItemCnt = [self->_headerData readLittleEndian32];
    self->_codeItemCnt = [self->_headerData readLittleEndian32];
    self->_codeContentCRC = [self->_headerData readLittleEndian32];
    self->_cryptorInfo = [self->_headerData readByte];
    [self->_headerData read:self->_hashKey size:CC_SHA256_DIGEST_LENGTH];
}

- (void)_readContentData
{
    [self->_contentData seekTo:self->_codeSize + YZHKV_CONTENT_HEADER_SIZE];
}

- (BOOL)_checkDataWithCRC
{
    YZHKV_CHECK_CODE_QUEUE;
    if (!YZHKV_IS_FILE_OPEN) {
        return NO;
    }
    int64_t size = 0;
    uint32_t crc = 0;
    uint8_t *ptr = [self->_contentData bytes] + YZHKV_CONTENT_HEADER_SIZE;
    while (size < self->_codeSize) {
        uint32_t cSize = YZHKV_CRC_SIZE;
        if (self->_codeSize < size + cSize) {
            cSize = (uint32_t)(self->_codeSize - size);
        }
        crc = (uint32_t)crc32((uint32_t)crc, ptr + size, (uint32_t)cSize);
        if (size + cSize >= self->_codeSize) {
            break;
        }
        size += cSize;
    }
    return self->_codeContentCRC == crc;
}

- (void)_updateCodeSize:(int64_t)codeSize
{
    YZHKV_CHECK_CODE_QUEUE;

    if (codeSize < 0) {
        return;
    }
    if (codeSize + YZHKV_CODE_DATA_HEAD_SIZE + YZHKV_CONTENT_HEADER_SIZE > self->_size) {
        NSLog(@"=============你他妈的什么鬼,codeSize=%@,_size=%@,remSize=%@",@(codeSize),@(_size),@([_contentData remSize]));
        return;
    }
    self->_codeSize = codeSize;
    [self->_headerData seekTo:_YZHHeaderOffsetSize];
    [self->_headerData writeLittleEndian64:self->_codeSize];
}

- (void)_updateKeyItemCnt
{
    self->_keyItemCnt = (uint32_t)self.dict.count;
    [self->_headerData seekTo:_YZHHeaderOffsetKeyItemCnt];
    [self->_headerData writeLittleEndian32:self->_keyItemCnt];
}

- (void)_updateCodeItemCnt:(uint32_t)codeItemCnt
{
    if (codeItemCnt < self.dict.count) {
        return;
    }
    self->_codeItemCnt = codeItemCnt;
    [self->_headerData seekTo:_YZHHeaderOffsetCodeItemCnt];
    [self->_headerData writeLittleEndian32:self->_codeItemCnt];
}

- (void)_updateCRC:(uint32_t)srcCRC buffer:(uint8_t *)ptr size:(uint32_t)size
{
    YZHKV_CHECK_CODE_QUEUE;
    uint32_t crc = (uint32_t)crc32((uint32_t)srcCRC, ptr, (uint32_t)size);
    self->_codeContentCRC = crc;
    [self->_headerData seekTo:_YZHHeaderOffsetCodeContentCRC];
    [self->_headerData writeLittleEndian32:self->_codeContentCRC];
}

- (void)_updateCryptorInfoWithCryptKey:(NSData*)cryptKey
{
    YZHKV_CHECK_CODE_QUEUE;
    if (self->_cryptor) {
        self->_cryptorInfo = TYPE_OR(TYPE_LS(self->_cryptor.cryptMode, 2), TYPE_AND(self->_cryptor.keyType + 1, 3));
        [self->_headerData seekTo:_YZHHeaderOffsetCryptor];
        [self->_headerData writeByte:self->_cryptorInfo];
        //这里的hashKey不可能为nil
        NSData *hash = [self _hashForData:cryptKey hashType:_YZHHashTypeSHA256];
        memcpy(self->_hashKey, (uint8_t*)hash.bytes, CC_SHA256_DIGEST_LENGTH);
    }
    else {
        
        self->_cryptorInfo = 0;
        [self->_headerData seekTo:_YZHHeaderOffsetCryptor];
        [self->_headerData writeByte:self->_cryptorInfo];
        
        memset(self->_hashKey, 0, sizeof(self->_hashKey));
    }
    
    [self->_headerData seekTo:_YZHHeaderOffsetKeyHash];
    [self->_headerData writeBuffer:self->_hashKey size:CC_SHA256_DIGEST_LENGTH];
}

- (BOOL)_checkContentCryptKeyHeader
{
    return memcmp([self->_contentData bytes], self->_hashKey, sizeof(_hashKey)) == 0;
}

- (BOOL)_shouldFullWriteBack
{
    if (self->_keyItemCnt > YZHKV_FULL_WRITE_BACK_KEY_MIN_CNT &&
        self->_keyItemCnt <= self->_codeItemCnt * YZHKV_FULL_WRITE_BACK_KEY_CNT_WITH_CODE_CNT_MAX_RATIO) {
        return YES;
    }
    return NO;
}

- (BOOL)_ensureAppendSize:(uint64_t)appendSize currentDict:(NSDictionary*)dict withNewDict:(NSDictionary**)newDict
{
    YZHKV_CHECK_CODE_QUEUE;
    
    if (!YZHKV_IS_FILE_OPEN) {
        if ([self _loadFromFileWithCryptKey:nil] == nil) {
            return NO;
        }
    }
    if ([self->_contentData remSize] > appendSize) {
        return YES;
    }
    
    //首先看下是否有许多重复的或者删除了的数据，就考虑先重新写一次，避免无条件的扩张内存
    if ([self _shouldFullWriteBack]) {
        dict = [self _fullWriteBack:dict checkCondition:YES error:NULL];
        if (newDict) {
            *newDict = dict;
        }
        
        if ([self->_contentData remSize] > appendSize) {
            return YES;
        }
    }

    
    uint64_t newSize = (self->_size + appendSize + DEFAULT_PAGE_SIZE_s - 1)/ DEFAULT_PAGE_SIZE_s * DEFAULT_PAGE_SIZE_s + MIN_MMAP_SIZE_s;
    if (newSize < MIN_MMAP_SIZE_s) {
        newSize = MIN_MMAP_SIZE_s;
    }

    if ([self _updateSize:newSize truncate:YES] == NO) {
        return NO;
    }
    
    NSLog(@"AppendSize:%lld,fullwriteBack",newSize);
    if ([self _shouldFullWriteBack]) {
        dict = [self _fullWriteBack:dict checkCondition:YES error:NULL];
        if (newDict) {
            *newDict = dict;
        }
    }
    return YES;
}

- (NSMutableDictionary*)_loadFromFileWithCryptKey:(NSData*)cryptKey
{
    YZHKV_CHECK_CODE_QUEUE;
    self->_fd = open(self.filePath.UTF8String, O_RDWR|O_CREAT, S_IRWXU);
    if (self->_fd < 0) {
        return nil;
    }
    [YZHMachTimeUtils recordPointWithText:@"创建文件"];

    int64_t fileSize  = [YZHKVUtils fileSize:self->_fd];
    uint64_t size = 0;
    if (fileSize <= MIN_MMAP_SIZE_s) {
        size = MIN_MMAP_SIZE_s;
    }
    else {
        size = (fileSize + DEFAULT_PAGE_SIZE_s - 1)/DEFAULT_PAGE_SIZE_s * DEFAULT_PAGE_SIZE_s;
    }
    [YZHMachTimeUtils recordPointWithText:@"获取文件大小"];
    
    if ([self _updateSize:size truncate:size != fileSize] == NO) {
        [self _closeFile];
        return nil;
    }
    [YZHMachTimeUtils recordPointWithText:@"mmap文件"];
    
    BOOL fullWriteBack = [self _shouldFullWriteBack];
    if (self->_codeSize > 0 && ![self _checkDataWithCRC]) {
        fullWriteBack = NO;
        //error
        BOOL ret = NO;
        NSError *error = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCRCError userInfo:nil];
        self.lastError = error;
        if ([self.delegate respondsToSelector:@selector(kv:reportCheckFailedError:)]) {
            ret = [self.delegate kv:self reportCheckFailedError:error];
            if (ret) {
                fullWriteBack = YES;
            }
        }
    }
    
    if (self->_cryptorInfo > 0 && self->_cryptor == nil && cryptKey.length == 0) {
        NSError *error = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCryptKeyError userInfo:nil];
        [self _reportError:error];
        return nil;
    }
    
    
    BOOL doDecrypt = self->_cryptor ? YES : NO;
    if (self->_cryptor == nil && cryptKey.length > 0) {
        NSError *error = nil;
        BOOL oldHave = [self _setupCryptorWithCryptKey:cryptKey checkCryptKey:YES error:&error];
        if (error) {
            if (error.code == YZHKVErrorCryptKeyError) {
                NSLog(@"密码错误，error=%@",error);
            }
            else if (error.code == _YZHKVInterErrorKeySizeError) {
                NSLog(@"密码长度错误，error=%@",error);
            }
            else if (error.code == _YZHKVInterErrorCryptModeError) {
                NSLog(@"加密模式错误，error=%@",error);
            }
            else {
                NSLog(@"创建加密器错误，error=%@",error);
            }
            [self _reportError:error];
            return nil;
        }
        
        doDecrypt = oldHave;
        //以前没有，现在有密码，相当于修改密码，需要回写
        if (oldHave == NO) {
            fullWriteBack = YES;
        }
    }
    [YZHMachTimeUtils recordPointWithText:@"开始解密"];
    NSError *error = nil;
    YZHCodeData *plainData = [self _startDecryptContentDataWithDecryptCondition:doDecrypt error:&error];
    if (error) {
        NSLog(@"密码错误，error=%@",error);
        [self _reportError:error];
        return nil;
    }
    
    [YZHMachTimeUtils recordPointWithText:@"解密完成，开始解码"];
    
    NSMutableDictionary *dict = [self _decodeBuffer:(uint8_t*)plainData.bytes + YZHKV_CONTENT_HEADER_SIZE cacheObjectDataRangeOffset:YZHKV_CONTENT_HEADER_SIZE size:self->_codeSize];
    
    [YZHMachTimeUtils recordPointWithText:@"解码完毕"];
    
    NSInteger dictCnt = dict.count;
    if ((dictCnt == 0 && self->_codeSize > 0) || self->_keyItemCnt != dictCnt) {
        //说明出现解码错误，不回写数据，做close
        NSError *error = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCoderError userInfo:nil];
        NSLog(@"解码错误，error=%@",error);
        [self _reportError:error];
        return nil;
    }
    
    if (fullWriteBack) {
        error = nil;
        [YZHMachTimeUtils recordPointWithText:@"开始回写"];
        dict = [self _fullWriteBack:dict checkCondition:NO error:&error];
        [YZHMachTimeUtils recordPointWithText:@"回写完毕"];

        if (error) {
            [self _reportError:error];
            return nil;
        }
    }

    return dict;
}

- (void)_reportError:(NSError*)error
{
    [self _closeFile];
    self.lastError = error;
    if ([self.delegate respondsToSelector:@selector(kv:reportError:)]) {
        [self.delegate kv:self reportError:error];
    }
}

- (YZHMutableCodeData*)_startEncryptContentDataFromDict:(NSDictionary<id, _YZHKVCacheObject*>*)dict toNewDict:(NSMutableDictionary<id, _YZHKVCacheObject*>**)newDict checkCondition:(BOOL)checkCondition error:(NSError**)error
{
    YZHMutableCodeData *encodeData = [[YZHMutableCodeData alloc] init];
    
    [encodeData ensureRemSize:YZHKV_CONTENT_HEADER_SIZE];
    [encodeData seekTo:YZHKV_CONTENT_HEADER_SIZE];
    NSMutableDictionary<id, _YZHKVCacheObject*> *newDictTmp = [self _encodeDictionary:dict intoCodeData:encodeData];
    if (newDict) {
        *newDict = newDictTmp;
    }
    
    if (self->_cryptor) {
        if (checkCondition && ![self _checkContentCryptKeyHeader]) {
            if (error) {
                *error = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCryptKeyError userInfo:nil];
            }
            return nil;
        }
    
        int64_t dataSize = encodeData.dataSize;
        int64_t outSize = dataSize;
        
        [encodeData ensureRemSize:dataSize + YZHAESKeySize128];
        
        memcpy(encodeData.bytes, self->_hashKey, sizeof(_hashKey));
        
        [self->_cryptor reset];
        [self->_cryptor crypt:YZHCryptOperationEncrypt input:encodeData.bytes inSize:dataSize output:encodeData.bytes outSize:&outSize];
        if (dataSize != outSize) {
            if (error) {
                *error = [NSError errorWithDomain:_YZHKVErrorDomain code:_YZHKVInterErrorCryptModeError userInfo:nil];
            }
        }
    }
    return encodeData;
}

- (YZHCodeData*)_startDecryptContentDataWithDecryptCondition:(BOOL)decryptCondition error:(NSError**)error
{
    YZHKV_CHECK_CODE_QUEUE;
    if (self->_cryptor && decryptCondition) {
        uint8_t *input = [self->_contentData bytes];
        
        int64_t dataSize = [_contentData dataSize];
        int64_t outSize = dataSize;
        YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] initWithSize:outSize];
        
        [self->_cryptor reset];
        [self->_cryptor crypt:YZHCryptOperationDecrypt input:input inSize:dataSize output:codeData.bytes outSize:&outSize];
        if (outSize < YZHKV_CONTENT_HEADER_SIZE || dataSize != outSize || memcmp(codeData.bytes, self->_hashKey, sizeof(_hashKey))) {
            if (error) {
                *error = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCryptKeyError userInfo:nil];
            }
        }
        [codeData seekTo:outSize];
        return codeData;
    }
    else {
        return _contentData;
    }
}

//返回原来是否有密码
- (BOOL)_setupCryptorWithCryptKey:(NSData*)cryptKey checkCryptKey:(BOOL)checkCryptKey error:(NSError**)error
{
    YZHKV_CHECK_CODE_QUEUE;
    NSData *hashKey = nil;
    YZHAESKeySize keySize = YZHAESKeySize128;
    YZHAESKeyType keyType = YZHAESKeyType128;
    
    YZHCryptMode cryptMode = YZHCryptModeCFB;
    
    uint8_t cryptorInfo = self->_cryptorInfo;
    
    BOOL oldHave = NO;
    if (cryptorInfo == 0) {
        hashKey = [self _hashCryptKey:cryptKey keyType:&keyType];
    }
    else {
        oldHave = YES;
        keyType = TYPE_AND(cryptorInfo, 3) - 1;
        cryptMode = TYPE_RS(cryptorInfo, 2);
        
        hashKey = [self _hashForData:cryptKey hashType:_YZHHashTypeSHA512];
        
        if (checkCryptKey) {
            NSData *cryptKeyHash = [self _hashForData:cryptKey hashType:_YZHHashTypeSHA256];
            if (memcmp(cryptKeyHash.bytes, self->_hashKey, CC_SHA256_DIGEST_LENGTH)) {
                //密码不一致
                NSError *err = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCryptKeyError userInfo:nil];
                if (error) {
                    *error = err;
                }
                return oldHave;
            }
        }
    }
    keySize = AES_KEYSIZE_FROM_KEYTYPE(keyType);
    if (hashKey.length < keySize) {
        NSError *err = [NSError errorWithDomain:_YZHKVErrorDomain code:_YZHKVInterErrorKeySizeError userInfo:nil];
        if (error) {
            *error = err;
        }
        return oldHave;
    }
    NSData *key = [hashKey subdataWithRange:NSMakeRange(0, keySize)];
    //只运行这几种流式加密的方式
    if (cryptMode != YZHCryptModeCFB &&
        cryptMode != YZHCryptModeCFB1 &&
        cryptMode != YZHCryptModeCFB8 &&
        cryptMode != YZHCryptModeOFB) {
        NSError *err = [NSError errorWithDomain:_YZHKVErrorDomain code:_YZHKVInterErrorCryptModeError userInfo:nil];
        if (error) {
            *error = err;
        }
        return oldHave;
    }

    NSData *iv = [hashKey subdataWithRange:NSMakeRange(hashKey.length - YZHAESKeySize128, YZHAESKeySize128)];
    self->_cryptor = [[YZHAESCryptor alloc] initWithAESKey:key keyType:keyType inVector:iv cryptMode:cryptMode];
    [self _updateCryptorInfoWithCryptKey:cryptKey];
    return oldHave;
}

- (NSData*)_hashCryptKey:(NSData*)cryptKey keyType:(YZHAESKeyType*)keyType
{
    YZHAESKeyType keyTypeTmp = YZHAESKeyType128;
    if (cryptKey.length == 0) {
        return nil;
    }
    NSData *hashData = [self _hashForData:cryptKey hashType:_YZHHashTypeSHA512];
    if (cryptKey.length >= YZHAESKeySize256) {
        keyTypeTmp = YZHAESKeyType256;
    }
    else if (cryptKey.length >= YZHAESKeySize192) {
        keyTypeTmp = YZHAESKeyType192;
    }
    else {
        keyTypeTmp = YZHAESKeyType128;
    }
    if (keyType) {
        *keyType = keyTypeTmp;
    }
    return hashData;
}

- (NSData*)_hashForData:(NSData*)data hashType:(_YZHHashType)hashType
{
    if (data.length == 0) {
        return nil;
    }
    uint8_t md[CC_SHA512_DIGEST_LENGTH] = {0};
    uint8_t length = 0;
    switch (hashType) {
        case _YZHHashTypeSHA256: {
            CC_SHA256(data.bytes, (CC_LONG)data.length, md);
            length = CC_SHA256_DIGEST_LENGTH;
            break;
        }
        case _YZHHashTypeSHA512: {
            CC_SHA512(data.bytes, (CC_LONG)data.length, md);
            length = CC_SHA512_DIGEST_LENGTH;
            break;
        }
        default:
            break;
    }
    return [NSData dataWithBytes:md length:length];
}


- (BOOL)_updateSize:(int64_t)size truncate:(BOOL)truncate
{
    YZHKV_CHECK_CODE_QUEUE;
    if (self->_fd <= 0) {
        if ([self _loadFromFileWithCryptKey:nil] == nil) {
            return NO;
        }
    }
    
    if (size < MIN_MMAP_SIZE_s) {
        size = MIN_MMAP_SIZE_s;
    }
    
    [YZHMachTimeUtils recordPointWithText:@"开始 ftruncate"];
    if (truncate) {
        //这个函数涉及到IO操作，最影响性能
        if (ftruncate(self->_fd, size) != 0) {
            return NO;
        }
    }
    [YZHMachTimeUtils recordPointWithText:@"结束 ftruncate"];

    
    if (self->_ptr && self->_ptr != MAP_FAILED) {
        if (munmap(self->_ptr, (size_t)self->_size)) {
            return NO;
        }
    }
    
    uint8_t *newPtr = mmap(self->_ptr, (size_t)size, PROT_READ | PROT_WRITE, MAP_SHARED, self->_fd, 0);
    if (newPtr == NULL || newPtr == MAP_FAILED) {
        return NO;
    }
    self->_ptr = newPtr;
    self->_size = size;
    
    self->_headerData = [[YZHCodeData alloc] initWithBuffer:self->_ptr size:YZHKV_CODE_DATA_HEAD_SIZE];
    self->_contentData = [[YZHCodeData alloc] initWithBuffer:self->_ptr + YZHKV_CODE_DATA_HEAD_SIZE size:self->_size - YZHKV_CODE_DATA_HEAD_SIZE];
    
    [self _readHeaderInfo];
    [self _readContentData];
    return YES;
}

- (NSMutableDictionary<id, _YZHKVCacheObject*>*)_fullWriteBack:(NSDictionary*)dict checkCondition:(BOOL)checkCondition error:(NSError**)error
{
    YZHKV_CHECK_CODE_QUEUE;
    NSError *err = nil;
    NSMutableDictionary *newDict = nil;
    YZHMutableCodeData *encodeNewData = [self _startEncryptContentDataFromDict:dict toNewDict:&newDict checkCondition:checkCondition error:&err];;
    if (error) {
        *error = err;
    }
    if (err) {
        return newDict;
    }

    [self _updateCodeItemCnt:(uint32_t)newDict.count];
    
    int64_t dataSize = encodeNewData.dataSize;
    int64_t codeSize = dataSize - YZHKV_CONTENT_HEADER_SIZE;
    if (self->_codeSize != codeSize || memcmp([self->_contentData bytes], encodeNewData.bytes, (size_t)dataSize) != 0) {
        
        [self _updateCodeSize:codeSize];

        [self->_contentData bzero];
        [self->_contentData writeCodeData:encodeNewData];
        
        [self _updateCRC:0 buffer:(uint8_t*)encodeNewData.bytes + YZHKV_CONTENT_HEADER_SIZE size:(uint32_t)codeSize];
    }
    else {
        [self _readContentData];
    }
    
    return newDict;
}

- (void)_clearEncodeData
{
    YZHKV_CHECK_CODE_QUEUE;
    [self _updateSize:0 truncate:YES];
    [self->_contentData bzero];
    self->_codeSize = 0;
    self->_keyItemCnt = 0;
    self->_codeItemCnt = 0;
    self->_codeContentCRC = 0;
    if (self->_cryptor) {
        [self->_cryptor reset];
    }
}

- (void)_closeFile
{
    YZHKV_CHECK_CODE_QUEUE;
    if (self->_ptr != NULL && self->_ptr != MAP_FAILED) {
        munmap(self->_ptr, (size_t)self->_size);
        self->_ptr = NULL;
        self->_size = 0;
    }
    if (self->_fd) {
        close(self->_fd);
        self->_fd = 0;
    }
    self->_version = 0;
    self->_codeSize = 0;
    self->_keyItemCnt = 0;
    self->_codeItemCnt = 0;
    self->_codeContentCRC = 0;
    self->_cryptorInfo = 0;
    
    
    self->_headerData = nil;
    self->_contentData = nil;
    if (self->_cryptor) {
        [self->_cryptor reset];
        self->_cryptor = nil;
    }
    
    self.lastError = nil;
    
    self.tmpCodeData = nil;
}

- (_YZHKVCacheObject*)_writeData:(YZHMutableCodeData*)data keySize:(int64_t)keySize currentDict:(NSDictionary*)dict newDict:(NSDictionary**)newDict
{
    YZHKV_CHECK_CODE_QUEUE;
    _YZHKVCacheObject *cacheObject = [[_YZHKVCacheObject alloc] init];
    int64_t dataSize = [data dataSize];
    if (self->_cryptor) {
        int64_t outSize = dataSize;
        [self->_cryptor crypt:YZHCryptOperationEncrypt input:data.bytes inSize:dataSize output:data.bytes outSize:&outSize];
        if (outSize != dataSize) {
            return nil;
        }
    }
    
    BOOL isOK = [self _ensureAppendSize:dataSize currentDict:dict withNewDict:newDict];
    if (isOK == NO) {
        return nil;
    }
    
    if (self->_cryptor == nil) {
        [cacheObject setRange:NSMakeRange((NSUInteger)(_contentData.dataSize + keySize), (NSUInteger)dataSize - keySize)];
    }
    [_contentData writeCodeData:data];
    
    [self _updateCodeItemCnt:self->_codeItemCnt + 1];
    
    uint8_t *ptr = [_contentData bytes] + YZHKV_CONTENT_HEADER_SIZE + _codeSize;
    
    [self _updateCodeSize:_codeSize + dataSize];
    
    [self _updateCRC:_codeContentCRC buffer:ptr size:(uint32_t)dataSize];
    
    return cacheObject;
}

- (BOOL)_updateCryptKey:(NSData*)cryptKey withNewDict:(NSMutableDictionary**)newDict
{
    YZHKV_CHECK_CODE_QUEUE;
    
    NSData *hashKey = [self _hashForData:cryptKey hashType:_YZHHashTypeSHA256];
    if (hashKey && memcmp(hashKey.bytes, self->_hashKey, CC_SHA256_DIGEST_LENGTH) == 0) {
        return YES;
    }

    NSError *error = nil;
    YZHCodeData *plainData = [self _startDecryptContentDataWithDecryptCondition:YES error:&error];
    if (error) {
        NSLog(@"解密错误，error=%@",error);
        [self _reportError:error];
        return NO;
    }

    NSMutableDictionary *dict = [self _decodeBuffer:(uint8_t*)plainData.bytes + YZHKV_CONTENT_HEADER_SIZE cacheObjectDataRangeOffset:YZHKV_CONTENT_HEADER_SIZE size:self->_codeSize];
    NSInteger dictCnt = [dict count];
    if ((dict.count == 0 && self->_codeSize > 0) || self->_keyItemCnt != dictCnt) {
        //说明出现解码错误，不回写数据，做close
        NSError *error = [NSError errorWithDomain:_YZHKVErrorDomain code:YZHKVErrorCoderError userInfo:nil];
        NSLog(@"解码错误，error=%@",error);
        [self _reportError:error];
        return NO;
    }

    if (cryptKey.length == 0) {
        [self->_cryptor reset];
        self->_cryptor = nil;
        [self _updateCryptorInfoWithCryptKey:nil];
    }
    else {
        [self _setupCryptorWithCryptKey:cryptKey checkCryptKey:NO error:NULL];
    }

    error = nil;
    BOOL OK = YES;
    NSMutableDictionary<id, _YZHKVCacheObject*> *tmp = [self _fullWriteBack:dict checkCondition:NO error:&error];
    if (error) {
        OK = NO;
        
        [self->_cryptor reset];
        self->_cryptor = nil;
        [self _updateCryptorInfoWithCryptKey:nil];

        [self _reportError:error];
    }
    
    if (newDict) {
        *newDict = tmp;
    }

    return OK;
}

- (NSMutableDictionary<id, _YZHKVCacheObject*>*)_encodeDictionary:(NSDictionary<id, _YZHKVCacheObject*>*)dict intoCodeData:(YZHMutableCodeData*)codeData
{
    NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, _YZHKVCacheObject * _Nonnull obj, BOOL * _Nonnull stop) {

        [YZHCoder encodeObject:key topEdgeSuperClass:nil intoCodeData:codeData];
        int64_t startLoc = [codeData dataSize];
        
        if (obj.objectType == _YZHKVCacheObjectTypeDataRange) {
            [codeData appendWriteBuffer:self->_contentData.bytes + obj.dataRange.location size:obj.dataRange.length];
        }
        else if (obj.objectType == _YZHKVCacheObjectTypePlainData) {
            [codeData appendWriteData:[obj objectData]];
        }
        else if (obj.objectType == _YZHKVCacheObjectTypeDecodeObject) {
            [YZHCoder encodeObject:[obj decodeObject] intoCodeData:codeData];
        }
        
        int64_t endLoc = [codeData dataSize];
        //retDict
        _YZHKVCacheObject *cacheObj = [[_YZHKVCacheObject alloc] init];
        if (self->_cryptor) {
            //是加密的话则保持原样
            [cacheObj setObject:[obj object] withObjectType:obj.objectType];
        }
        else {
            [cacheObj setRange:NSMakeRange((NSUInteger)startLoc, endLoc - startLoc)];
        }
        [newDict setObject:cacheObj forKey:key];
    }];
    
    return newDict;
}

- (NSMutableDictionary<id, _YZHKVCacheObject*>*)_decodeBuffer:(uint8_t*)ptr cacheObjectDataRangeOffset:(int32_t)offset size:(int64_t)size
{
    if (ptr == NULL || size <= 0) {
        return [NSMutableDictionary dictionary];
    }
    int64_t location = offset;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    while (size > 0) {
        int64_t offsetTmp = 0;
        id key = [YZHCoder decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
        ptr += offsetTmp;
        size -= offsetTmp;
        location += offsetTmp;
        if (size <= 0 || offsetTmp <= 0 /*|| key == nil*/) {
            break;
        }
        
        NSRange r = [YZHCoder unpackBuffer:ptr bufferSize:size codeType:NULL len:NULL size:NULL offset:&offsetTmp];
        ptr += offsetTmp;
        size -= offsetTmp;
        location += offsetTmp;
        if (key && r.location != NSNotFound) {
            if (r.length > 0) {
                _YZHKVCacheObject *cacheObject = [[_YZHKVCacheObject alloc] init];
                if (self->_cryptor) {
                    [cacheObject setObject:[NSData dataWithBytes:ptr - offsetTmp length:offsetTmp] withObjectType:_YZHKVCacheObjectTypePlainData];
                }
                else {
                    [cacheObject setRange:NSMakeRange((NSUInteger)(location - offsetTmp),  offsetTmp)];

//                    NSData *data = [NSData dataWithBytes:ptrSRC + cacheObject.dataRange.location - offset length:cacheObject.dataRange.length];
//
//                    id objTmp = [YZHCoder decodeObjectWithData:data];
//                    if ([key integerValue] != [objTmp integerValue]) {
//                        NSLog(@"decode====key=%@,objTmp=%@",key,objTmp);
//                    }
                }
                [dict setObject:cacheObject forKey:key];
            }
            else {
                [dict removeObjectForKey:key];
            }
        }
        else {
            //这里避免空转
            if (offsetTmp <= 0) {
                break;
            }
        }
    }
    return dict;
}


- (BOOL)setObject:(id)object forKey:(id)key
{
    Class topEdgeSuperClass = [object hz_getObjectCodeTopEdgeSuperClass];
    return [self setObject:object topEdgeSuperClass:topEdgeSuperClass forKey:key];
}

- (BOOL)setObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass forKey:(id)key
{
    if (YZHKV_IS_FILE_OPEN == NO || key == nil) {
        return NO;
    }
    
    if (object == nil) {
        object = [NSData data];
    }
    
    __block BOOL isOK = NO;
    _sync_lock(self.lock, ^{
        [self.tmpCodeData truncateTo:0];
        [YZHCoder encodeObject:key topEdgeSuperClass:nil intoCodeData:self.tmpCodeData];
        int64_t keySize = [self.tmpCodeData dataSize];
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        [YZHCoder encodeObject:object topEdgeSuperClass:topEdgeSuperClass intoCodeData:self.tmpCodeData];
        
        NSMutableDictionary *newDict = self.dict;
        _YZHKVCacheObject *cacheObj = [self _writeData:self.tmpCodeData keySize:keySize currentDict:self.dict newDict:&newDict];
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (self.dict != newDict) {
            self.dict = newDict;
        }
        
        if (self->_cryptor) {
            [cacheObj setObject:object withObjectType:_YZHKVCacheObjectTypeDecodeObject];
        }
        
        [self.dict setObject:cacheObj forKey:key];
        
        [self _updateKeyItemCnt];
        
        isOK = YES;
    });
    return isOK;
}

- (BOOL)setFloat:(float)val forKey:(id)key
{
    __block BOOL isOK = NO;
    _sync_lock(self.lock, ^{
        [self.tmpCodeData truncateTo:0];
        [YZHCoder encodeObject:key topEdgeSuperClass:nil intoCodeData:self.tmpCodeData];
        int64_t keySize = [self.tmpCodeData dataSize];
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        [YZHCoder encodeFloat:val intoCodeData:self.tmpCodeData];
        
        NSMutableDictionary *newDict = self.dict;
        _YZHKVCacheObject *cacheObj = [self _writeData:self.tmpCodeData keySize:keySize currentDict:self.dict newDict:&newDict];
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (self.dict != newDict) {
            self.dict = newDict;
        }
        
        if (self->_cryptor) {
            [cacheObj setObject:[NSNumber numberWithFloat:val] withObjectType:_YZHKVCacheObjectTypeDecodeObject];
        }
        
        [self.dict setObject:cacheObj forKey:key];
        
        [self _updateKeyItemCnt];
        
        isOK = YES;
    });
    return isOK;
}

- (BOOL)setDouble:(double)val forKey:(id)key
{
    __block BOOL isOK = NO;
    _sync_lock(self.lock, ^{
        [self.tmpCodeData truncateTo:0];
        [YZHCoder encodeObject:key topEdgeSuperClass:nil intoCodeData:self.tmpCodeData];
        int64_t keySize = [self.tmpCodeData dataSize];
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        [YZHCoder encodeDouble:val intoCodeData:self.tmpCodeData];
        
        NSMutableDictionary *newDict = self.dict;
        _YZHKVCacheObject *cacheObj = [self _writeData:self.tmpCodeData keySize:keySize currentDict:self.dict newDict:&newDict];
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (self.dict != newDict) {
            self.dict = newDict;
        }
        
        if (self->_cryptor) {
            [cacheObj setObject:[NSNumber numberWithDouble:val] withObjectType:_YZHKVCacheObjectTypeDecodeObject];
        }
        
        [self.dict setObject:cacheObj forKey:key];
        
        [self _updateKeyItemCnt];
        
        isOK = YES;
    });
    return isOK;
}

- (BOOL)setInteger:(int64_t)val forKey:(id)key
{
    __block BOOL isOK = NO;
    _sync_lock(self.lock, ^{
        [self.tmpCodeData truncateTo:0];
        [YZHCoder encodeObject:key topEdgeSuperClass:NULL intoCodeData:self.tmpCodeData];
        int64_t keySize = [self.tmpCodeData dataSize];
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        [YZHCoder encodeInteger:val intoCodeData:self.tmpCodeData];
        
        NSMutableDictionary *newDict = self.dict;
        _YZHKVCacheObject *cacheObj = [self _writeData:self.tmpCodeData keySize:keySize currentDict:self.dict newDict:&newDict];
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (self.dict != newDict) {
            self.dict = newDict;
        }
        
        if (self->_cryptor) {
            //有密码时保存decode的object
            [cacheObj setObject:@(val) withObjectType:_YZHKVCacheObjectTypeDecodeObject];
        }
        
        [self.dict setObject:cacheObj forKey:key];
        
        [self _updateKeyItemCnt];
        
        isOK = YES;
    });
    return isOK;
}

- (BOOL)setBool:(BOOL)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setInt8:(int8_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setUInt8:(uint8_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setInt16:(int16_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setUInt16:(uint16_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setInt32:(int32_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setUInt32:(uint32_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setInt64:(int64_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (BOOL)setUInt64:(uint64_t)val forKey:(id)key
{
    return [self setInteger:val forKey:key];
}

- (id)getObjectForKey:(id)key
{
    __block id decodeObject = nil;
    __block _YZHKVCacheObject *object = nil;
    _sync_lock(self.lock, ^{
        object = [self.dict objectForKey:key];
        if (object.objectType == _YZHKVCacheObjectTypeDataRange) {
            decodeObject = [YZHCoder decodeObjectFromBuffer:self->_contentData.bytes + object.dataRange.location length:object.dataRange.length];
        }
    });
    if (decodeObject == nil) {
        if (object.objectType == _YZHKVCacheObjectTypeDecodeObject) {
            decodeObject = [object decodeObject];
        }
        else if (object.objectType == _YZHKVCacheObjectTypePlainData) {
            decodeObject = [YZHCoder decodeObjectWithData:[object objectData]];
        }
    }
    return decodeObject;
}

- (BOOL)getBoolForKey:(id)key
{
    return [[self getObjectForKey:key] boolValue];
}

- (int8_t)getInt8ForKey:(id)key
{
    return [[self getObjectForKey:key] charValue];
}

- (uint8_t)getUInt8ForKey:(id)key
{
    return [[self getObjectForKey:key] unsignedCharValue];
}

- (int16_t)getInt16ForKey:(id)key
{
    return [[self getObjectForKey:key] shortValue];
}

- (uint16_t)getUInt16ForKey:(id)key
{
    return [[self getObjectForKey:key] unsignedShortValue];
}

- (int32_t)getInt32ForKey:(id)key
{
    return [[self getObjectForKey:key] intValue];
}

- (uint32_t)getUInt32ForKey:(id)key
{
    return [[self getObjectForKey:key] unsignedIntValue];
}

- (int64_t)getInt64ForKey:(id)key
{
    return [[self getObjectForKey:key] longLongValue];
}

- (uint64_t)getUInt64ForKey:(id)key
{
    return [[self getObjectForKey:key] unsignedLongLongValue];
}

- (float)getFloatForKey:(id)key
{
    return [[self getObjectForKey:key] floatValue];
}

- (double)getDoubleForKey:(id)key
{
    return [[self getObjectForKey:key] doubleValue];
}

- (NSDictionary*)allEntries
{
    __block NSDictionary *dict = nil;
    _sync_lock(self.lock, ^{
        dict = [self.dict copy];
    });
    return dict;
}

- (void)removeObjectForKey:(id)key
{
    [self setObject:nil topEdgeSuperClass:NULL forKey:key];
}

- (void)clear
{
    _sync_lock(self.lock, ^{
        [self _clearEncodeData];
        [self.dict removeAllObjects];
    });
}

- (void)close
{
    _sync_lock(self.lock, ^{
        [self _closeFile];
        [self.dict removeAllObjects];
    });
}

- (void)updateCryptKey:(NSData*)cryptKey
{
    _sync_lock(self.lock, ^{
        NSMutableDictionary *newDict = self.dict;
        [self _updateCryptKey:cryptKey withNewDict:&newDict];
        if (self.dict != newDict) {
            self.dict = newDict;
        }
    });
}

- (NSError*)lastError
{
    return _lastError;
}

- (void)dealloc
{
    _sync_lock(self.lock, ^{
        [self _closeFile];        
    });
}

@end
