//
//  YZHCFKV.m
//  YZHKVDemo
//
//  Created by yuan on 2019/9/8.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHCFKV.h"
#import <sys/mman.h>
#import <zlib.h>
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>

#import <vector>

#import "macro.h"
#import "YZHAESCryptor.h"
#import "NSObject+YZHCodeToTopSuperClass.h"
#import "YZHCFKVDelegate.h"
#import "YZHMachTimeUtils.h"

static int DEFAULT_PAGE_SIZE_s = getpagesize();
static int MIN_MMAP_SIZE_s;     //64KB

#define DEFAULT_YZHCFKV_NAME              "yzh.cfkv.default"
#define YZHCFKV_CODE_DATA_HEAD_SIZE       (128)
#define YZHCFKV_CONTENT_HEADER_SIZE       (128)
#define YZHCFKV_CRC_SIZE                  (134217728) //128MB

//在keyItem为y1000个以上的时候可以进行回写
#define YZHCFKV_FULL_WRITE_BACK_KEY_MIN_CNT                         (1000)
//在keyItem占据CodeItem的比例小于0.5的时候可以进行回写
#define YZHCFKV_FULL_WRITE_BACK_KEY_CNT_WITH_CODE_CNT_MAX_RATIO     (0.6)

#define YZHCFKV_CHECK_CODE_QUEUE         //NSAssert([self _isInCodeQueue], @"must execute in codeQueue")

#define YZHCFKV_IS_FILE_OPEN(CTX)         (CTX->_fd > 0 && CTX->_size > 0 && CTX->_ptr && CTX->_ptr != MAP_FAILED)

//NSString *const _YZHCFKVErrorDomain = @"YZHCFKVErrorDomain";


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

//内部错误,从2^16次方开始
typedef NS_ENUM(int32_t, _YZHCFKVInterError)
{
    //密码长度错误
    _YZHCFKVInterErrorKeySizeError        = 65536,
    //加密模式错误
    _YZHCFKVInterErrorCryptModeError      = 65537,
};

typedef NS_ENUM(int32_t, _YZHCFKVCacheObjectType)
{
    //空
    _YZHCFKVCacheObjectTypeNone             = 0,
    //这个是明文的区域
    _YZHCFKVCacheObjectTypeDataRange        = 1,
    //这个就是未编码的对象
    _YZHCFKVCacheObjectTypeUncodedObject    = 2,
    //这个是编码后的
    _YZHCFKVCacheObjectTypeEncodedData      = 3,
    //这个是C语言所含有的基本数据类型,这个可以和上面的进行|运算
    _YZHCFKVCacheObjectTypeCTypeValue       = (1 << 16),
};

static inline void _sync_lock(dispatch_semaphore_t lock, void (^block)(void)) {
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    if (block) {
        block();
    }
    dispatch_semaphore_signal(lock);
}

typedef id(^YZHCFKVCodeBlock)(YZHCFKV *kv);
typedef void(^YZHCFKVCodeCompletionBlock)(YZHCFKV *kv, id result);



/**********************************************************************
 *_YZHCFKVCacheObject
 * cacheObjType == _YZHCFKVCacheObjectTypeDataRange，记录dataRange
 * cacheObjType == _YZHCFKVCacheObjectTypeUncodedObject,记录cacheObject
 * cacheObjType == _YZHCFKVCacheObjectTypeEncodedData, 记录objectData
 *对于密文的时候，记录的是解码后的对象
 ***********************************************************************/
@interface _YZHCFKVCacheObject : NSObject

@property (nonatomic, assign, readonly) _YZHCFKVCacheObjectType cacheObjectType;

@property (nonatomic, assign, readonly) NSRange dataRange;

//存储解码后的数据对象
@property (nonatomic, strong) id decodeObject;

@property (nonatomic, assign, readonly) int64_t CTypeValue;

@property (nonatomic, assign, readonly) YZHCodeItemType CTypeItemType;


@end

@implementation _YZHCFKVCacheObject
{
@private
    id _cacheObject;
}

- (instancetype)initWithCacheObject:(_YZHCFKVCacheObject*)cacheObject
{
    self = [super init];
    if (self) {
        _cacheObjectType = cacheObject.cacheObjectType;
        _dataRange = cacheObject.dataRange;
        _decodeObject = cacheObject.decodeObject;
        _CTypeValue = cacheObject.CTypeValue;
        _CTypeItemType = cacheObject.CTypeItemType;
    }
    return self;
}

- (NSData*)objectEncodedData
{
    return (NSData*)_cacheObject;
}

- (id)cacheObject
{
    return _cacheObject;
}

- (void)setCacheObject:(id)cacheObject withType:(_YZHCFKVCacheObjectType)type
{
    if (type == _YZHCFKVCacheObjectTypeNone) {
        _cacheObject = nil;
        _cacheObjectType = type;
    }
    else if (type == _YZHCFKVCacheObjectTypeUncodedObject) {
        if ([cacheObject isKindOfClass:[NSObject class]]) {
            _cacheObject = cacheObject;
            _cacheObjectType = type;
        }
    }
    else if (type == _YZHCFKVCacheObjectTypeEncodedData) {
        if ([cacheObject isKindOfClass:[NSData class]]) {
            _cacheObject = cacheObject;
            _cacheObjectType = type;
        }
    }
}

- (void)setRange:(NSRange)range
{
    _dataRange = range;
    _cacheObjectType = _YZHCFKVCacheObjectTypeDataRange;
}

- (void)addCTypeValue:(int64_t)CTypeValue CTypeItemType:(YZHCodeItemType)CTypeItemType
{
    _cacheObjectType =  (_YZHCFKVCacheObjectType)(_cacheObjectType | _YZHCFKVCacheObjectTypeCTypeValue);
    _CTypeValue = CTypeValue;
    _CTypeItemType = CTypeItemType;
}

- (BOOL)haveCTypeValue
{
    return (_cacheObjectType & _YZHCFKVCacheObjectTypeCTypeValue);
}

@end

static inline NSMutableDictionary *_loadFromFileWithCryptKey(struct YZHCFKVContext *ctx, YZHCodeData *cryptKey);
static inline void _closeFile(struct YZHCFKVContext *ctx);

/**********************************************************************
 *
 *|---2字节(version)---|---8字节(size)---|---4字节(keyItemCnt)---|---4字节(codeItemCnt)---|---4字节(crc)---|---1字节(cryptor)---|
 *|---32字节keyHash(sha256)---|---73字节(保留)---|
 *
 *其中---1字节(cryptor)---如下：
 *|---6bit的加密模式（YZHCryptMode）,2bit的keytype（YZHAESKeyType+1）---|
 *
 ***********************************************************************/

typedef struct YZHCFKVContext {
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

    shared_ptr<YZHCodeData> _sharedPtrHeaderData;
    shared_ptr<YZHCodeData> _sharedPtrContentData;
    //这个只是存储从文件mmap后解密后的contentData，主要是为了在decode的时候不需要生成NSData影响性能。
    shared_ptr<YZHCodeData> _sharedPtrPlainContentData;
    
    shared_ptr<YZHAESCryptor> _sharedPtrCryptor;
    
    string _filePath;
    NSMutableDictionary<id, _YZHCFKVCacheObject*> *_dict;
    dispatch_semaphore_t _lock;
    shared_ptr<YZHMutableCodeData> _sharedPtrTmpCodeData;
    
    YZHCFKVError lastError;
    
    YZHCFKV *CFKV;
}YZHCFKVContext_S;

static inline YZHCodeData* _hashForData(YZHCodeData *data, _YZHHashType hashType)
{
    int64_t dataSize = data->dataSize();
    if (dataSize == 0) {
        return NULL;
    }
    YZHMutableCodeData *hashData = new YZHMutableCodeData(CC_SHA512_DIGEST_LENGTH);
    uint8_t length = 0;
    switch (hashType) {
        case _YZHHashTypeSHA256: {
            CC_SHA256(data->bytes(), (CC_LONG)dataSize, hashData->bytes());
            length = CC_SHA256_DIGEST_LENGTH;
            break;
        }
        case _YZHHashTypeSHA512: {
            CC_SHA512(data->bytes(), (CC_LONG)dataSize, hashData->bytes());
            length = CC_SHA512_DIGEST_LENGTH;
            break;
        }
        default:
            break;
    }
    hashData->truncateTo(length);
    return hashData;
}

static inline YZHCodeData * _hashCryptKey(YZHCodeData *cryptKey, YZHAESKeyType *keyType)
{
    YZHAESKeyType keyTypeTmp = YZHAESKeyType128;
    int64_t cryptKeySize = cryptKey->dataSize();
    if (cryptKeySize == 0) {
        return NULL;
    }
    YZHCodeData *hashData = _hashForData(cryptKey, _YZHHashTypeSHA512);
    if (cryptKeySize >= YZHAESKeySize256) {
        keyTypeTmp = YZHAESKeyType256;
    }
    else if (cryptKeySize >= YZHAESKeySize192) {
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

static inline BOOL _checkAndMakeDirectory(string &filepath)
{
    if (filepath.length() == 0) {
        return NO;
    }
    vector<size_t> vec;
    string sub = filepath;
    while (access(sub.c_str(), F_OK) != F_OK) {
        vec.insert(vec.begin(), sub.length());
        size_t p = sub.find_last_of('/');
        sub = sub.substr(0,p);
    }
    
    size_t cnt = vec.size();
    for (int i = 0; i < cnt; ++i) {
        size_t p = vec[i];
        string sub = filepath.substr(0, p);
        mkdir(sub.c_str(), S_IRWXU);
    }
    return YES;
//    return access(filepath.c_str(), F_OK) == F_OK;
}

static inline int64_t _getFileSizeWithFD(int fd)
{
    struct stat st = {};
    if (fstat(fd, &st) == F_OK) {
        return st.st_size;
    }
    return -1;
}

static inline BOOL _readHeaderInfo(struct YZHCFKVContext *ctx)
{
    ctx->_sharedPtrHeaderData->seek(YZHDataSeekTypeSET);
    ctx->_version = ctx->_sharedPtrHeaderData->readLittleEndian16();
    ctx->_codeSize = ctx->_sharedPtrHeaderData->readLittleEndian64();
    ctx->_keyItemCnt = ctx->_sharedPtrHeaderData->readLittleEndian32();
    ctx->_codeItemCnt = ctx->_sharedPtrHeaderData->readLittleEndian32();
    ctx->_codeContentCRC = ctx->_sharedPtrHeaderData->readLittleEndian32();
    ctx->_cryptorInfo = ctx->_sharedPtrHeaderData->readByte();
    ctx->_sharedPtrHeaderData->read(ctx->_hashKey, CC_SHA256_DIGEST_LENGTH);
    return YES;
}

static inline BOOL _readContentData(struct YZHCFKVContext *ctx)
{
    ctx->_sharedPtrContentData->seekTo(ctx->_codeSize + YZHCFKV_CONTENT_HEADER_SIZE);
    return YES;
}

static inline BOOL _checkDataWithCRC(struct YZHCFKVContext *ctx)
{
    int64_t size = 0;
    uint32_t crc = 0;
    uint8_t *ptr = ctx->_sharedPtrContentData->bytes() + YZHCFKV_CONTENT_HEADER_SIZE;
    while (size < ctx->_codeSize) {
        uint32_t cSize = YZHCFKV_CRC_SIZE;
        if (ctx->_codeSize < size + cSize) {
            cSize = (uint32_t)(ctx->_codeSize - size);
        }
        crc = (uint32_t)crc32((uint32_t)crc, ptr + size, (uint32_t)cSize);
        if (size + cSize >= ctx->_codeSize) {
            break;
        }
        size += cSize;
    }
    return ctx->_codeContentCRC == crc;
}

static inline void _updateCodeSize(struct YZHCFKVContext *ctx, int64_t codeSize)
{
    if (codeSize < 0 || codeSize + YZHCFKV_CODE_DATA_HEAD_SIZE + YZHCFKV_CONTENT_HEADER_SIZE > ctx->_size) {
        return;
    }

    ctx->_codeSize = codeSize;
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetSize);
    ctx->_sharedPtrHeaderData->writeLittleEndian64(ctx->_codeSize);
}

static inline void _updateKeyItemCnt(struct YZHCFKVContext *ctx)
{
    ctx->_keyItemCnt = (uint32_t)ctx->_dict.count;
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetKeyItemCnt);
    ctx->_sharedPtrHeaderData->writeLittleEndian32(ctx->_keyItemCnt);
}

static inline void _updateCodeItemCnt(struct YZHCFKVContext *ctx, uint32_t codeItemCnt)
{
    if (codeItemCnt < ctx->_dict.count) {
        return;
    }
    ctx->_codeItemCnt = codeItemCnt;
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetCodeItemCnt);
    ctx->_sharedPtrHeaderData->writeLittleEndian32(ctx->_codeItemCnt);
}

static inline void _updateCRC(struct YZHCFKVContext *ctx, uint32_t srcCRC, uint8_t *ptr, uint32_t size)
{
    uint32_t crc = ptr ? (uint32_t)crc32((uint32_t)srcCRC, ptr, (uint32_t)size) : srcCRC;
    ctx->_codeContentCRC = crc;
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetCodeContentCRC);
    ctx->_sharedPtrHeaderData->writeLittleEndian32(ctx->_codeContentCRC);
}

static inline void _updateCryptorInfoWithCryptKey(struct YZHCFKVContext *ctx, YZHCodeData *cryptKey)
{
    if (ctx->_sharedPtrCryptor.get() != nullptr) {
        YZHAESKeyType keyType = ctx->_sharedPtrCryptor->getKeyType();
        YZHCryptMode cryptMode = ctx->_sharedPtrCryptor->getCryptMode();
        ctx->_cryptorInfo = TYPE_OR(TYPE_LS(cryptMode, 2), TYPE_AND(keyType + 1, 3));
        ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetCryptor);
        ctx->_sharedPtrHeaderData->writeByte(ctx->_cryptorInfo);
        //这里的hashKey不可能为nil
        YZHCodeData *hash = _hashForData(cryptKey, _YZHHashTypeSHA256);
        if (hash) {
            memcpy(ctx->_hashKey, hash->bytes(), CC_SHA256_DIGEST_LENGTH);
            delete hash;
        }
    }
    else {
        
        ctx->_cryptorInfo = 0;
        ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetCryptor);
        ctx->_sharedPtrHeaderData->writeByte(ctx->_cryptorInfo);
        
        memset(ctx->_hashKey, 0, sizeof(ctx->_hashKey));
    }
    
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetKeyHash);
    ctx->_sharedPtrHeaderData->writeBuffer(ctx->_hashKey, CC_SHA256_DIGEST_LENGTH);
}

static inline void _updateCryptorInfoWithHashKey(struct YZHCFKVContext *ctx, uint8_t cryptorInfo, uint8_t hashKey[CC_SHA256_DIGEST_LENGTH], uint8_t contentHeader[YZHCFKV_CONTENT_HEADER_SIZE])
{
    ctx->_cryptorInfo = cryptorInfo;
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetCryptor);
    ctx->_sharedPtrHeaderData->writeByte(ctx->_cryptorInfo);
    
    memcpy(ctx->_hashKey, hashKey, CC_SHA256_DIGEST_LENGTH);
    ctx->_sharedPtrHeaderData->seekTo(_YZHHeaderOffsetKeyHash);
    ctx->_sharedPtrHeaderData->writeBuffer(ctx->_hashKey, CC_SHA256_DIGEST_LENGTH);
    
    memcpy(ctx->_sharedPtrContentData->bytes(), contentHeader, YZHCFKV_CONTENT_HEADER_SIZE);
}

static inline BOOL _checkContentCryptKeyHeader(struct YZHCFKVContext *ctx)
{
    return memcmp(ctx->_sharedPtrContentData->bytes(), ctx->_hashKey, sizeof(ctx->_hashKey)) == 0;
}

static inline BOOL _shouldFullWriteBack(struct YZHCFKVContext *ctx)
{
    if (ctx->_keyItemCnt == ctx->_codeItemCnt) {
        return NO;
    }
    if ((ctx->_keyItemCnt == 0 && ctx->_codeItemCnt > 0) ||
        (ctx->_keyItemCnt > YZHCFKV_FULL_WRITE_BACK_KEY_MIN_CNT &&
        ctx->_keyItemCnt <= ctx->_codeItemCnt * YZHCFKV_FULL_WRITE_BACK_KEY_CNT_WITH_CODE_CNT_MAX_RATIO)) {
        return YES;
    }
    return NO;
}

static inline void _reportError(struct YZHCFKVContext *ctx, YZHCFKVError error)
{
    YZHCFKV *CFKV = ctx->CFKV;
    _closeFile(ctx);
//    if (CFKV->delegate.expired() == NO) {
//        shared_ptr<YZHCFKVDelegateInterface> delegate = CFKV->delegate.lock();
//        delegate->notifyError(CFKV, error);
//    }
    ctx->lastError = error;
//    NSLog(@"error=%ld",error);
    if (CFKV->delegate) {
        CFKV->delegate->notifyError(CFKV, error);
    }
}

static inline BOOL _reportWarning(struct YZHCFKVContext *ctx, YZHCFKVError error)
{
    YZHCFKV *CFKV = ctx->CFKV;
//    if (!CFKV->delegate.expired()) {
//        shared_ptr<YZHCFKVDelegateInterface> delegate = CFKV->delegate.lock();
//        return delegate->notifyWarning(CFKV, error);
//    }
    ctx->lastError = error;
    if (CFKV->delegate) {
        return CFKV->delegate->notifyWarning(CFKV, error);
    }
    return YES;
}

static inline NSMutableDictionary<id, _YZHCFKVCacheObject*>* _encodeDictionary(struct YZHCFKVContext *ctx, NSDictionary<id, _YZHCFKVCacheObject*>*dict, YZHMutableCodeData *codeData)
{
    NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
    
    [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, _YZHCFKVCacheObject * _Nonnull obj, BOOL * _Nonnull stop) {
        
        
        encodeObjectToTopSuperClassIntoCodeData(key, NULL, codeData, NULL);
        int64_t startLoc = codeData->currentSeek();
        
        _YZHCFKVCacheObjectType cacheObjectType = (_YZHCFKVCacheObjectType)(obj.cacheObjectType & 0XFFFF);
        if (cacheObjectType == _YZHCFKVCacheObjectTypeDataRange) {
            codeData->appendWriteBuffer(ctx->_sharedPtrPlainContentData->bytes() + obj.dataRange.location, obj.dataRange.length);
        }
        else if (cacheObjectType == _YZHCFKVCacheObjectTypeEncodedData) {
            codeData->appendWriteData([obj objectEncodedData]);
        }
        else if (cacheObjectType == _YZHCFKVCacheObjectTypeUncodedObject) {
            encodeObjectIntoCodeData([obj cacheObject], codeData, NULL);
        }
        
        int64_t endLoc = codeData->currentSeek();
        //retDict
        _YZHCFKVCacheObject *cacheObj = [[_YZHCFKVCacheObject alloc] initWithCacheObject:obj];
        
        [cacheObj setRange:NSMakeRange((NSUInteger)startLoc, (NSUInteger)(endLoc - startLoc))];
        [newDict setObject:cacheObj forKey:key];
    }];
    
    return newDict;
}

static inline NSMutableDictionary<id, _YZHCFKVCacheObject*>* _decodeBuffer(uint8_t *ptr, int32_t offset, int64_t size, BOOL copyData)
{
    if (ptr == NULL || size <= 0) {
        return [NSMutableDictionary dictionary];
    }
    ptr = ptr + offset;
    int64_t location = offset;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    while (size > 0) {
        int64_t offsetTmp = 0;
        id key = decodeObjectFromBuffer(ptr, size, &offsetTmp, NULL, NULL);
        ptr += offsetTmp;
        size -= offsetTmp;
        location += offsetTmp;
        if (size <= 0 || offsetTmp <= 0 /*|| key == nil*/) {
            break;
        }
        
        NSRange r = unpackBuffer(ptr, size, NULL, NULL, NULL, &offsetTmp);
        ptr += offsetTmp;
        size -= offsetTmp;
        location += offsetTmp;
        if (key && r.location != NSNotFound) {
            if (r.length > 0) {
                _YZHCFKVCacheObject *cacheObject = [[_YZHCFKVCacheObject alloc] init];
                if (copyData) {
                    [cacheObject setCacheObject:[NSData dataWithBytes:ptr - offsetTmp length:(NSUInteger)offsetTmp] withType:_YZHCFKVCacheObjectTypeEncodedData];
                }
                else {
                    [cacheObject setRange:NSMakeRange((NSUInteger)(location - offsetTmp),  (NSUInteger)offsetTmp)];
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

static inline YZHMutableCodeData *_startEncryptContentDataFromDict(struct YZHCFKVContext *ctx, NSDictionary<id, _YZHCFKVCacheObject*> *currentDict, NSMutableDictionary<id, _YZHCFKVCacheObject*>** outNewDict, BOOL checkCondition, YZHCFKVError *error)
{
    YZHAESCryptor *cryptor = ctx->_sharedPtrCryptor.get();
    if (cryptor && checkCondition && !_checkContentCryptKeyHeader(ctx)) {
        if (error) {
            *error = YZHCFKVErrorCryptKeyError;
        }
        return NULL;
    }
    
    YZHMutableCodeData *encodeData = new YZHMutableCodeData();
    
    encodeData->ensureRemSize(YZHCFKV_CONTENT_HEADER_SIZE);
    encodeData->seekTo(YZHCFKV_CONTENT_HEADER_SIZE);
    
    NSMutableDictionary<id, _YZHCFKVCacheObject*> *newDictTmp = _encodeDictionary(ctx, currentDict, encodeData);
    if (outNewDict) {
        *outNewDict = newDictTmp;
    }
    
    if (cryptor) {
        ctx->_sharedPtrPlainContentData = make_shared<YZHMutableCodeData>(encodeData);
        
        int64_t dataSize = encodeData->dataSize();
        int64_t outSize = dataSize;
        
        encodeData->ensureRemSize(dataSize + YZHAESKeySize128);
        
        memcpy(encodeData->bytes(), ctx->_hashKey, sizeof(ctx->_hashKey));
        ctx->_sharedPtrCryptor->reset();
        ctx->_sharedPtrCryptor->crypt(YZHCryptOperationEncrypt, encodeData, encodeData);
        outSize = encodeData->dataSize();
        if (dataSize != outSize) {
            if (error) {
                *error = (YZHCFKVError)_YZHCFKVInterErrorCryptModeError;
            }
        }
    }
    
    return encodeData;
}

static inline YZHCodeData *_startDecryptContentDataWithDecryptCondition(struct YZHCFKVContext *ctx, BOOL decryptCondition, YZHCFKVError *error)
{
    if (ctx->_sharedPtrCryptor.get() != nullptr && decryptCondition) {
        int64_t dataSize = ctx->_sharedPtrContentData->dataSize();
        int64_t outSize = dataSize;
        YZHMutableCodeData *codeData = new YZHMutableCodeData(outSize);
        
        ctx->_sharedPtrCryptor->reset();
        ctx->_sharedPtrCryptor->crypt(YZHCryptOperationDecrypt, ctx->_sharedPtrContentData.get(), codeData);
        outSize = codeData->dataSize();
        if (outSize < YZHCFKV_CONTENT_HEADER_SIZE || dataSize != outSize || memcmp(codeData->bytes(), ctx->_hashKey, sizeof(ctx->_hashKey))) {
            if (error) {
                *error = YZHCFKVErrorCryptKeyError;
            }
            delete codeData;
            return NULL;
        }
        codeData->seekTo(outSize);
        
        memset(codeData->bytes(), 0, YZHCFKV_CONTENT_HEADER_SIZE);
        
        ctx->_sharedPtrPlainContentData = shared_ptr<YZHCodeData>(codeData);
        
        return codeData;
    }
    else {
        return ctx->_sharedPtrContentData.get();
    }
}

//返回原来是否有密码
static inline BOOL _setupCryptorWithCryptKey(struct YZHCFKVContext *ctx, YZHCodeData *cryptKey, BOOL checkCryptKey, YZHCFKVError *error)
{
    YZHCodeData *hashKey = nil;
    YZHAESKeySize keySize = YZHAESKeySize128;
    YZHAESKeyType keyType = YZHAESKeyType128;
    
    YZHCryptMode cryptMode = YZHCryptModeCFB;
    
    YZHCodeData *key = nil;
    YZHCodeData *vector = nil;
    uint8_t cryptorInfo = ctx->_cryptorInfo;
    int64_t hashKeyDataSize = 0;
    
    BOOL oldHave = NO;
    if (cryptorInfo == 0) {
        hashKey = _hashCryptKey(cryptKey, &keyType);
    }
    else {
        oldHave = YES;
        keyType = (YZHAESKeyType)(TYPE_AND(cryptorInfo, 3) - 1);
        cryptMode = (YZHCryptMode)TYPE_RS(cryptorInfo, 2);
        
        hashKey = _hashForData(cryptKey, _YZHHashTypeSHA512);
        
        if (checkCryptKey) {
            YZHCodeData *cryptKeyHash = _hashForData(cryptKey, _YZHHashTypeSHA256);
            if (cryptKeyHash) {
                if (memcmp(cryptKeyHash->bytes(), ctx->_hashKey, CC_SHA256_DIGEST_LENGTH)) {
                    //密码不一致
                    if (error) {
                        *error = YZHCFKVErrorCryptKeyError;
                    }
                    delete cryptKeyHash;
                    goto SETUP_CRYPTOR_WITH_CRYPT_KEY_ERR_END;
                }
                else {
                    delete cryptKeyHash;
                }
            }
        }
    }
    
    hashKeyDataSize = hashKey->dataSize();
    keySize = AES_KEYSIZE_FROM_KEYTYPE(keyType);
    if (hashKeyDataSize < keySize) {
        if (error) {
            *error = (YZHCFKVError)_YZHCFKVInterErrorKeySizeError;
        }
        goto SETUP_CRYPTOR_WITH_CRYPT_KEY_ERR_END;
    }
    key = new YZHMutableCodeData(keySize);
    key->writeBuffer(hashKey->bytes(), keySize);
    //只运行这几种流式加密的方式
    if (cryptMode != YZHCryptModeCFB &&
        cryptMode != YZHCryptModeCFB1 &&
        cryptMode != YZHCryptModeCFB8 &&
        cryptMode != YZHCryptModeOFB) {
        if (error) {
            *error = (YZHCFKVError)_YZHCFKVInterErrorCryptModeError;
        }
        goto SETUP_CRYPTOR_WITH_CRYPT_KEY_ERR_END;
    }
    
    vector = new YZHMutableCodeData(YZHAESKeySize128);
    vector->writeBuffer(hashKey->bytes() + hashKeyDataSize - YZHAESKeySize128, YZHAESKeySize128);
    
    ctx->_sharedPtrCryptor = make_shared<YZHAESCryptor>(key, keyType, vector, cryptMode);

    _updateCryptorInfoWithCryptKey(ctx, cryptKey);
    
SETUP_CRYPTOR_WITH_CRYPT_KEY_ERR_END:
    if (hashKey) {
        delete hashKey;
    }
    if (key) {
        delete key;
    }
    if (vector) {
        delete vector;
    }
    return oldHave;
}

static inline NSMutableDictionary *_fullWriteBack(struct YZHCFKVContext *ctx, NSDictionary *dict, BOOL checkCondition, YZHCFKVError *error)
{
    YZHCFKVError err = YZHCFKVErrorNone;
    NSMutableDictionary *newDict = nil;
    int64_t dataSize = 0;
    int64_t codeSize = 0;
    YZHMutableCodeData *encodeNewData = _startEncryptContentDataFromDict(ctx, dict, &newDict, checkCondition, &err);
    if (error) {
        *error = err;
    }
    if (err) {
        goto _FULL_WRITE_BACK_ERR_END;
    }
    
    NSLog(@"fullWriteBack");
    _updateCodeItemCnt(ctx, (uint32_t)newDict.count);
    
    dataSize = encodeNewData->dataSize();
    codeSize = dataSize - YZHCFKV_CONTENT_HEADER_SIZE;
    if (ctx->_codeSize != codeSize || memcmp(ctx->_sharedPtrContentData->bytes(), encodeNewData->bytes(), (size_t)dataSize) != 0) {
        
        _updateCodeSize(ctx, codeSize);
        
        ctx->_sharedPtrContentData->bzero();
        ctx->_sharedPtrContentData->writeCodeData(encodeNewData);
        _updateCRC(ctx, 0, (uint8_t*)encodeNewData->bytes() + YZHCFKV_CONTENT_HEADER_SIZE, (uint32_t)codeSize);
    }
    else {
        _readContentData(ctx);
    }
    
_FULL_WRITE_BACK_ERR_END:
    if (encodeNewData) {
        delete encodeNewData;
    }
    
    return newDict;
}

BOOL _updateCryptKey(struct YZHCFKVContext *ctx, YZHCodeData *cryptKey, NSMutableDictionary **outNewDict)
{
    if ((cryptKey == NULL || cryptKey->dataSize() == 0) && ctx->_cryptorInfo == 0) {
        return YES;
    }
    YZHCodeData *hashKey = _hashForData(cryptKey, _YZHHashTypeSHA256);
    if (hashKey) {
        if (memcmp(hashKey->bytes(), ctx->_hashKey, CC_SHA256_DIGEST_LENGTH) == 0) {
            delete hashKey;
            return YES;
        }
        delete hashKey;
    }

    
    YZHCFKVError error = YZHCFKVErrorNone;
    YZHCodeData *plainData = _startDecryptContentDataWithDecryptCondition(ctx, YES, &error);
    if (error) {
        NSLog(@"解密错误，error=%@",@(error));
        _reportError(ctx, error);
        return NO;
    }
    
    NSMutableDictionary *dict = _decodeBuffer(plainData->bytes(), YZHCFKV_CONTENT_HEADER_SIZE, ctx->_codeSize, NO);
    NSInteger dictCnt = [dict count];
    if (/*(dict.count == 0 && ctx->_codeSize > 0) ||*/ ctx->_keyItemCnt != dictCnt) {
        //说明出现解码错误，不回写数据，做close
        error = YZHCFKVErrorCoderError;
        NSLog(@"解码错误，error=%@",@(error));
        _reportError(ctx, error);
        return NO;
    }
    
    uint8_t oldCryptorInfo = ctx->_cryptorInfo;
    uint8_t oldHashKey[CC_SHA256_DIGEST_LENGTH] = {0};
    memcpy(oldHashKey, ctx->_hashKey, CC_SHA256_DIGEST_LENGTH);
    
    uint8_t oldContentHeader[YZHCFKV_CONTENT_HEADER_SIZE] = {0};
    memcpy(oldContentHeader, ctx->_sharedPtrContentData->bytes(), YZHCFKV_CONTENT_HEADER_SIZE);
    
    shared_ptr<YZHAESCryptor> oldCryptor;
    ctx->_sharedPtrCryptor.swap(oldCryptor);
    
    if (cryptKey->dataSize() == 0) {
        _updateCryptorInfoWithCryptKey(ctx, cryptKey);
    }
    else {
        _setupCryptorWithCryptKey(ctx, cryptKey, NO, NULL);
    }
    
    error = YZHCFKVErrorNone;
    BOOL OK = YES;
    NSMutableDictionary<id, _YZHCFKVCacheObject*> *tmp = _fullWriteBack(ctx, dict, NO, &error);
    if (error) {
        OK = NO;
        
        //更新为原来的密码和cryptor
        _updateCryptorInfoWithHashKey(ctx, oldCryptorInfo, oldHashKey, oldContentHeader);

        ctx->_sharedPtrCryptor.swap(oldCryptor);
        oldCryptor.reset();

        _reportError(ctx, error);
    }
    else {
        if (oldCryptor.get()) {
            oldCryptor->reset();
        }
    }
    
    if (outNewDict) {
        *outNewDict = tmp;
    }
    
    return OK;
}

static inline BOOL _updateSize(struct YZHCFKVContext *ctx, int64_t size, BOOL truncate)
{
    if (ctx->_fd <= 0) {
        if (_loadFromFileWithCryptKey(ctx, NULL) == nil) {
            return NO;
        }
    }
    
    if (size < MIN_MMAP_SIZE_s) {
        size = MIN_MMAP_SIZE_s;
    }
    
    if (ctx->_ptr && ctx->_ptr != MAP_FAILED) {
        if (munmap(ctx->_ptr, (size_t)ctx->_size)) {
            return NO;
        }
    }
    
    if (ctx->_size != size /*truncate*/) {
        //这个函数涉及到IO操作，最影响性能
        if (ftruncate(ctx->_fd, size) != 0) {
            return NO;
        }
    }
    
    uint8_t *newPtr = (uint8_t*)mmap(ctx->_ptr, (size_t)size, PROT_READ | PROT_WRITE, MAP_SHARED, ctx->_fd, 0);
    if (newPtr == NULL || newPtr == MAP_FAILED) {
        return NO;
    }
    ctx->_ptr = newPtr;
    ctx->_size = size;
    
    ctx->_sharedPtrHeaderData = make_shared<YZHCodeData>(ctx->_ptr, YZHCFKV_CODE_DATA_HEAD_SIZE);
    ctx->_sharedPtrContentData = make_shared<YZHCodeData>(ctx->_ptr + YZHCFKV_CODE_DATA_HEAD_SIZE, ctx->_size - YZHCFKV_CODE_DATA_HEAD_SIZE);
    
    ctx->_sharedPtrPlainContentData = ctx->_sharedPtrContentData;
    
    _readHeaderInfo(ctx);
    
//    int64_t maxCodeSize = ctx->_size - YZHCFKV_CODE_DATA_HEAD_SIZE - YZHCFKV_CODE_DATA_HEAD_SIZE;
//    if (ctx->_codeSize > maxCodeSize) {
//        _updateCodeSize(ctx, maxCodeSize);
//    }
    
    _readContentData(ctx);
    
    return YES;
}

static inline NSMutableDictionary *_loadFromFileWithCryptKey(struct YZHCFKVContext *ctx, YZHCodeData *cryptKey)
{
    ctx->_fd = open(ctx->_filePath.c_str(), O_RDWR|O_CREAT, S_IRWXU);
    if (ctx->_fd < 0) {
        return nil;
    }
//    [YZHMachTimeUtils recordPointWithText:@"创建文件"];
    
    int64_t fileSize  = _getFileSizeWithFD(ctx->_fd);
    uint64_t size = 0;
    if (fileSize <= MIN_MMAP_SIZE_s) {
        size = MIN_MMAP_SIZE_s;
    }
    else {
        size = (fileSize + DEFAULT_PAGE_SIZE_s - 1)/DEFAULT_PAGE_SIZE_s * DEFAULT_PAGE_SIZE_s;
    }
//    [YZHMachTimeUtils recordPointWithText:@"获取文件大小"];
    
    if (_updateSize(ctx, size, size != fileSize) == NO) {
        _closeFile(ctx);
        return nil;
    }
//    [YZHMachTimeUtils recordPointWithText:@"mmap文件"];
    
    BOOL fullWriteBack = _shouldFullWriteBack(ctx);
    if (ctx->_codeSize > 0 && !_checkDataWithCRC(ctx)) {
        fullWriteBack = _reportWarning(ctx, YZHCFKVErrorCRCError);
    }
    
    /*
     *如果cryptorInfo>0表示有加密的，但是现在没有加密器和密钥，表示有错误
     *如果第一次启动，cryptor为NULL，但是cryptKey应该有数据
     *如果非第一次启动，CFKV内部会调用_loadFromFileWithCryptKey，此时可以为cryptKey为NULL，但是cryptor不能为NULL
    */
    YZHAESCryptor *cryptor = ctx->_sharedPtrCryptor.get();
    if (ctx->_cryptorInfo > 0 && cryptor == NULL && (cryptKey == NULL || cryptKey->dataSize() == 0)) {
        _reportError(ctx, YZHCFKVErrorCryptKeyError);
        return nil;
    }
    
    
    uint8_t oldCryptorInfo = ctx->_cryptorInfo;
    uint8_t oldHashKey[CC_SHA256_DIGEST_LENGTH] = {0};
    memcpy(oldHashKey, ctx->_hashKey, CC_SHA256_DIGEST_LENGTH);
    
    uint8_t oldContentHeader[YZHCFKV_CONTENT_HEADER_SIZE] = {0};
    memcpy(oldContentHeader, ctx->_sharedPtrContentData->bytes(), YZHCFKV_CONTENT_HEADER_SIZE);
    
    YZHCFKVError error = YZHCFKVErrorNone;
    
    BOOL doDecrypt = cryptor ? YES : NO;
    //如果为第一次启动，
    if (cryptor == NULL && cryptKey && cryptKey->dataSize() > 0) {
        BOOL oldHave = _setupCryptorWithCryptKey(ctx, cryptKey, YES, &error);
        if (error) {
            if (error == YZHCFKVErrorCryptKeyError) {
                NSLog(@"密码错误，error=%@",@(error));
            }
            else if ((_YZHCFKVInterError)error == _YZHCFKVInterErrorKeySizeError) {
                NSLog(@"密码长度错误，error=%@",@(error));
            }
            else if ((_YZHCFKVInterError)error == _YZHCFKVInterErrorCryptModeError) {
                NSLog(@"加密模式错误，error=%@",@(error));
            }
            else {
                NSLog(@"创建加密器错误，error=%@",@(error));
            }
            _reportError(ctx, error);
            return nil;
        }
        
        doDecrypt = oldHave;
        //以前没有，现在有密码，相当于修改密码，需要回写
        if (oldHave == NO) {
            fullWriteBack = YES;
        }
    }
//    [YZHMachTimeUtils recordPointWithText:@"开始解密"];
    YZHCodeData *plainData = _startDecryptContentDataWithDecryptCondition(ctx, doDecrypt, &error);
    if (error) {
        _updateCryptorInfoWithHashKey(ctx, oldCryptorInfo, oldHashKey, oldContentHeader);
        NSLog(@"密码错误，error=%@",@(error));
        _reportError(ctx, error);
        return nil;
    }
    
//    [YZHMachTimeUtils recordPointWithText:@"开始解码"];
    
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (ctx->_codeSize > 0) {
        dict = _decodeBuffer((uint8_t*)plainData->bytes(), YZHCFKV_CONTENT_HEADER_SIZE, ctx->_codeSize, NO);
    }
    
//    [YZHMachTimeUtils recordPointWithText:@"解码完毕"];
    
    NSInteger dictCnt = dict.count;
    if (ctx->_keyItemCnt != dictCnt) {
        //说明出现解码错误，不回写数据，做close
        error = YZHCFKVErrorCoderError;
        NSLog(@"解码错误，error=%@",@(error));
        _reportError(ctx, error);
        return nil;
    }
    
    if (fullWriteBack) {
//        [YZHMachTimeUtils recordPointWithText:@"开始回写"];
        dict = _fullWriteBack(ctx, dict, NO, &error);
//        [YZHMachTimeUtils recordPointWithText:@"回写完毕"];
        
        if (error != YZHCFKVErrorNone) {
            _reportError(ctx, error);
            return nil;
        }
    }
    
    return dict;
}


static inline BOOL _ensureAppendSize(struct YZHCFKVContext *ctx, uint64_t appendSize, NSDictionary *currentDict, NSDictionary **newOutDict)
{
    if (ctx == NULL ) {
        return NO;
    }
    if (!YZHCFKV_IS_FILE_OPEN(ctx)) {
        if (_loadFromFileWithCryptKey(ctx, nil) == nil) {
            return NO;
        }
    }
    int64_t remSize = ctx->_sharedPtrContentData->remSize();
    if (remSize > appendSize) {
        return YES;
    }
    
    //首先看下是否有许多重复的或者删除了的数据，就考虑先重新写一次，避免无条件的扩张内存
    if (_shouldFullWriteBack(ctx)) {
        NSDictionary *dict = _fullWriteBack(ctx, currentDict, YES, NULL);
        if (newOutDict) {
            *newOutDict = dict;
        }
        
        remSize = ctx->_sharedPtrContentData->remSize();

        if (remSize > appendSize) {
            return YES;
        }
    }
    
    uint64_t newSize = ctx->_size;
    uint64_t needSize = ctx->_size + appendSize;
    do {
        newSize = TYPE_LS(newSize, 1);
    } while (newSize < needSize);
    
    if (_updateSize(ctx, newSize,YES) == NO) {
        return NO;
    }
    
    NSLog(@"appendSize:%lld,newSize:%lld",appendSize,newSize);
    if (_shouldFullWriteBack(ctx)) {
        NSDictionary *dict = _fullWriteBack(ctx, currentDict, YES, NULL);
        if (newOutDict) {
            *newOutDict = dict;
        }
    }
    return YES;
}

_YZHCFKVCacheObject* _writeData(struct YZHCFKVContext *ctx, YZHMutableCodeData *data, int64_t keySize, NSDictionary *currentDict, NSDictionary** outNewDict)
{
    _YZHCFKVCacheObject *cacheObject = [[_YZHCFKVCacheObject alloc] init];
    int64_t dataSize = data->dataSize();
    
    YZHAESCryptor *cryptor = ctx->_sharedPtrCryptor.get();
    YZHCodeData *contentData = ctx->_sharedPtrContentData.get();
    
    if (cryptor) {
        int64_t outSize = dataSize;
        cryptor->crypt(YZHCryptOperationEncrypt, data, data);
        outSize = data->dataSize();
        if (outSize != dataSize) {
            return nil;
        }
    }
    
    BOOL isOK = _ensureAppendSize(ctx, dataSize, currentDict, outNewDict);
    if (isOK == NO) {
        return nil;
    }
    contentData = ctx->_sharedPtrContentData.get();
    
    if (cryptor == NULL && dataSize > keySize) {
        [cacheObject setRange:NSMakeRange((NSUInteger)(contentData->dataSize() + keySize), (NSUInteger)(dataSize - keySize))];
    }
    contentData->writeCodeData(data);

    _updateCodeItemCnt(ctx, ctx->_codeItemCnt + 1);
    
    uint8_t *ptr = contentData->bytes() + YZHCFKV_CONTENT_HEADER_SIZE + ctx->_codeSize;
    
    _updateCodeSize(ctx, ctx->_codeSize + dataSize);
    
    _updateCRC(ctx, ctx->_codeContentCRC, ptr, (uint32_t)dataSize);
    
    return cacheObject;
}

static inline void _clearEncodeData(struct YZHCFKVContext *ctx, BOOL truncateFileSize)
{
    [ctx->_dict removeAllObjects];
    
    _updateCodeSize(ctx, 0);
    _updateKeyItemCnt(ctx);
    _updateCodeItemCnt(ctx, 0);
    _updateCRC(ctx, 0, NULL, 0);
    
    ctx->_sharedPtrContentData->bzero();
    
    if (truncateFileSize) {
        _updateSize(ctx, 0, YES);
    }

    if (ctx->_sharedPtrCryptor.get()) {
        ctx->_sharedPtrCryptor->reset();
        //加密HashKey
        ctx->_sharedPtrContentData->writeBuffer(ctx->_hashKey, CC_SHA256_DIGEST_LENGTH);
        ctx->_sharedPtrCryptor->crypt(YZHCryptOperationEncrypt, ctx->_sharedPtrContentData.get(), ctx->_sharedPtrContentData.get());
        
        ctx->_sharedPtrPlainContentData.reset();
    }
}

static inline void _closeFile(struct YZHCFKVContext *ctx)
{
    if (ctx->_ptr != NULL && ctx->_ptr != MAP_FAILED) {
        munmap(ctx->_ptr, (size_t)ctx->_size);
        ctx->_ptr = NULL;
        ctx->_size = 0;
    }
    if (ctx->_fd) {
        close(ctx->_fd);
        ctx->_fd = 0;
    }
    ctx->_version = 0;
    ctx->_codeSize = 0;
    ctx->_keyItemCnt = 0;
    ctx->_codeItemCnt = 0;
    ctx->_codeContentCRC = 0;
    ctx->_cryptorInfo = 0;
    
    [ctx->_dict removeAllObjects];
    
    memset(ctx->_hashKey, 0, sizeof(ctx->_hashKey));

    ctx->_sharedPtrHeaderData.reset();
    ctx->_sharedPtrContentData.reset();
    ctx->_sharedPtrCryptor.reset();
    ctx->_sharedPtrTmpCodeData.reset();

    ctx->_sharedPtrPlainContentData.reset();
    ctx->lastError = YZHCFKVErrorNone;
    ctx->CFKV = NULL;
    
}




void YZHCFKV::setupCFKVDefault()
{
    //    DEFAULT_PAGE_SIZE_s = getpagesize();
    MIN_MMAP_SIZE_s = DEFAULT_PAGE_SIZE_s;
    
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)calloc(1, sizeof(struct YZHCFKVContext));
    if (ctx) {
        ctx->_fd = 0;
        ctx->_size = 0;
        ctx->_ptr = NULL;
        ctx->_version = 1;
        ctx->_codeSize = 0;
        ctx->_keyItemCnt = 0;
        ctx->_codeItemCnt = 0;
        ctx->_codeContentCRC = 0;
        ctx->_cryptorInfo = 0;
        
        memset(ctx->_hashKey, 0, sizeof(ctx->_hashKey));
        
        ctx->_dict = [NSMutableDictionary dictionary];
        ctx->_lock = dispatch_semaphore_create(1);
        
        ctx->_sharedPtrTmpCodeData = make_shared<YZHMutableCodeData>();
        
        ctx->CFKV = this;
        ctx->lastError = YZHCFKVErrorNone;
    }
    delegate = NULL;
    ptrCFKVContext = ctx;
}

YZHCFKV::YZHCFKV()
{
    YZHCFKV(DEFAULT_YZHCFKV_NAME, "", NULL);
}

YZHCFKV::YZHCFKV(const string &name)
{
    YZHCFKV(name, "", NULL);
}

YZHCFKV::YZHCFKV(const string &name, const string &path)
{
    YZHCFKV(name, path, NULL);
}

YZHCFKV::YZHCFKV(const string &name, const string &path, YZHCodeData *cryptKey)
{
    setupCFKVDefault();
    if (ptrCFKVContext) {
        
        struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
        
        string nameT = name;
        string pathT = path;
        if (nameT.length() == 0) {
            nameT = DEFAULT_YZHCFKV_NAME;
        }
        
        if (pathT.length() == 0) {
            pathT = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject].UTF8String;
        }
        
        ctx->_filePath = pathT + "/" + nameT;
        
        size_t p = ctx->_filePath.find_last_of('/');
        string dir = ctx->_filePath.substr(0, p);
//        [YZHMachTimeUtils recordPointWithText:@"创建目录"];
        _checkAndMakeDirectory(dir);
//        [YZHMachTimeUtils recordPointWithText:@"创建目录finish"];
        
        _sync_lock(ctx->_lock, ^{
            NSMutableDictionary *dict = _loadFromFileWithCryptKey(ctx, cryptKey);
            ctx->_dict = dict;
        });
//        [YZHMachTimeUtils recordPointWithText:@"构造完毕"];
    }
}

YZHCFKV::~YZHCFKV()
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    _closeFile(ctx);
    if (ctx) {
        free(ctx);
        ptrCFKVContext = NULL;
    }
}

string YZHCFKV::getFilePath()
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    return ctx->_filePath;
}

BOOL YZHCFKV::updateCryptKey(YZHCodeData *cryptKey)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO) {
        return NO;
    }
    
    _sync_lock(ctx->_lock, ^{
        NSMutableDictionary *newDict = ctx->_dict;
        _updateCryptKey(ctx, cryptKey, &newDict);
        if (ctx->_dict != newDict) {
            ctx->_dict = newDict;
        }
    });
    return YES;
}

/**
 设置以Key作为键，以Object作为值
 
 @param object 作为值，在object为nil是removeObject的操作
 @param key 作为键，不可为空
 @return 返回是否成功，YES-成功，NO-失败
 */
BOOL YZHCFKV::setObjectForKey(id object, id key)
{
    Class topSuperClass = [object hz_codeToTopSuperClass];
    return setObjectForKey(object, topSuperClass, key);
}

/**
 设置以Key作为键，以Object作为值
 
 @param object 作为值，在object为nil是removeObject的操作
 @param topSuperClass object编码到父类的类名
 @param key key 作为键，不可为空
 @return 返回是否成功，YES-成功，NO-失败
 */
BOOL YZHCFKV::setObjectForKey(id object, Class topSuperClass, id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return NO;
    }
    
    id encodeObject = object;
    if (object == nil) {
        encodeObject = [NSData data];
    }
    
    __block BOOL isOK = NO;
    _sync_lock(ctx->_lock, ^{
        YZHMutableCodeData *tmpCodeData = ctx->_sharedPtrTmpCodeData.get();
        YZHAESCryptor *cryptor = ctx->_sharedPtrCryptor.get();
        tmpCodeData->truncateTo(0);
        encodeObjectToTopSuperClassIntoCodeData(key, NULL, tmpCodeData, NULL);
        int64_t keySize = tmpCodeData->currentSeek();
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        if (object) {
            encodeObjectToTopSuperClassIntoCodeData(encodeObject, topSuperClass, tmpCodeData, NULL);
        }
        else {
            encodeDataIntoCodeData(encodeObject, tmpCodeData);
        }
        
        NSMutableDictionary *newDict = ctx->_dict;
        _YZHCFKVCacheObject *cacheObj = _writeData(ctx, tmpCodeData, keySize, ctx->_dict, &newDict);
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (ctx->_dict != newDict) {
            ctx->_dict = newDict;
        }
        
        if (object) {
            if (cryptor) {
                [cacheObj setCacheObject:object withType:_YZHCFKVCacheObjectTypeUncodedObject];
            }
            [ctx->_dict setObject:cacheObj forKey:key];
        }
        else {
            [ctx->_dict removeObjectForKey:key];
        }
        _updateKeyItemCnt(ctx);
        
        isOK = YES;
    });
    return isOK;
}

BOOL YZHCFKV::setFloatForKey(float val, id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return NO;
    }
    
    __block BOOL isOK = NO;
    _sync_lock(ctx->_lock, ^{
        YZHMutableCodeData *tmpCodeData = ctx->_sharedPtrTmpCodeData.get();
        
        tmpCodeData->truncateTo(0);
        encodeObjectToTopSuperClassIntoCodeData(key, NULL, tmpCodeData, NULL);
        int64_t keySize = tmpCodeData->currentSeek();
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        encodeFloatIntoCodeData(val, tmpCodeData);
        
        NSMutableDictionary *newDict = ctx->_dict;
        _YZHCFKVCacheObject *cacheObj = _writeData(ctx, tmpCodeData, keySize, ctx->_dict, &newDict);
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (ctx->_dict != newDict) {
            ctx->_dict = newDict;
        }
        
        int32_t ival = Int32FromFloat(val);
        [cacheObj addCTypeValue:ival CTypeItemType:YZHCodeItemTypeRealF];
        
        [ctx->_dict setObject:cacheObj forKey:key];
        
        _updateKeyItemCnt(ctx);
        
        isOK = YES;
    });
    return isOK;
}

BOOL YZHCFKV::setDoubleForKey(double val, id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return NO;
    }
    
    __block BOOL isOK = NO;
    _sync_lock(ctx->_lock, ^{
        YZHMutableCodeData *tmpCodeData = ctx->_sharedPtrTmpCodeData.get();
        
        tmpCodeData->truncateTo(0);
        encodeObjectToTopSuperClassIntoCodeData(key, NULL, tmpCodeData, NULL);
        int64_t keySize = tmpCodeData->currentSeek();
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        encodeDoubleIntoCodeData(val, tmpCodeData);
        
        NSMutableDictionary *newDict = ctx->_dict;
        _YZHCFKVCacheObject *cacheObj = _writeData(ctx, tmpCodeData, keySize, ctx->_dict, &newDict);
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (ctx->_dict != newDict) {
            ctx->_dict = newDict;
        }
        
        int64_t ival = Int64FromDouble(val);
        [cacheObj addCTypeValue:ival CTypeItemType:YZHCodeItemTypeReal];
        
        [ctx->_dict setObject:cacheObj forKey:key];
        
        _updateKeyItemCnt(ctx);
        
        isOK = YES;
    });
    return isOK;
}

BOOL YZHCFKV::setIntegerForKey(int64_t val, id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return NO;
    }
    
    __block BOOL isOK = NO;
    _sync_lock(ctx->_lock, ^{
        YZHMutableCodeData *tmpCodeData = ctx->_sharedPtrTmpCodeData.get();
        tmpCodeData->truncateTo(0);
        encodeObjectToTopSuperClassIntoCodeData(key, NULL, tmpCodeData, NULL);
        int64_t keySize = tmpCodeData->currentSeek();
        if (keySize == 0) {
            isOK = NO;
            return;
        }
        encodeIntegerIntoCodeData(val, tmpCodeData);
        
        NSMutableDictionary *newDict = ctx->_dict;
        _YZHCFKVCacheObject *cacheObj = _writeData(ctx, tmpCodeData, keySize, ctx->_dict, &newDict);
        if (cacheObj == nil) {
            isOK = NO;
            return;
        }
        
        if (ctx->_dict != newDict) {
            ctx->_dict = newDict;
        }

        [cacheObj addCTypeValue:val CTypeItemType:YZHCodeItemTypeInteger];
        
        [ctx->_dict setObject:cacheObj forKey:key];
        
        _updateKeyItemCnt(ctx);
        
        isOK = YES;
    });
    return isOK;
}

id YZHCFKV::getObjectForKey(id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return nil;
    }
    
    __block id decodeObject = nil;
    _sync_lock(ctx->_lock, ^{
        _YZHCFKVCacheObject *cacheObject = [ctx->_dict objectForKey:key];
        
        decodeObject = cacheObject.decodeObject;
        if (decodeObject == nil) {
            _YZHCFKVCacheObjectType cacheObjectType = (_YZHCFKVCacheObjectType)(cacheObject.cacheObjectType & 0XFFFF);

            if (cacheObjectType == _YZHCFKVCacheObjectTypeDataRange) {
                
                YZHCodeData *plainContentData = ctx->_sharedPtrPlainContentData.get();
                
                decodeObject = decodeObjectFromBuffer(plainContentData->bytes() + cacheObject.dataRange.location, cacheObject.dataRange.length, NULL, NULL, NULL);
            }
            else if (cacheObjectType == _YZHCFKVCacheObjectTypeUncodedObject) {
                decodeObject = [cacheObject cacheObject];
            }
            else if (cacheObjectType == _YZHCFKVCacheObjectTypeEncodedData) {
                decodeObject =  decodeObjectFromData([cacheObject objectEncodedData]);
            }
            cacheObject.decodeObject = decodeObject;
        }
    });
    
    return decodeObject;
}

float YZHCFKV::getFloatForKey(id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return 0;
    }
    
    __block int64_t CTypeVal = 0;
    _sync_lock(ctx->_lock, ^{
        _YZHCFKVCacheObject *cacheObject = [ctx->_dict objectForKey:key];
        
        if ([cacheObject haveCTypeValue]) {
            CTypeVal = cacheObject.CTypeValue;
        }
        else {
            id decodeObject = cacheObject.decodeObject;
            if (decodeObject == nil) {
                YZHCodeItemType codeType = YZHCodeItemTypeRealF;
                if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeDataRange) {

                    YZHCodeData *plainContentData = ctx->_sharedPtrPlainContentData.get();

                    decodeObject = decodeObjectFromBuffer(plainContentData->bytes() + cacheObject.dataRange.location, cacheObject.dataRange.length, NULL, &codeType, NULL);
                }
                else if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeUncodedObject) {
                    decodeObject = [cacheObject cacheObject];
                }
                else if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeEncodedData) {
                    NSData *data = [cacheObject objectEncodedData];
                    decodeObject = decodeObjectFromBuffer((uint8_t*)data.bytes, data.length, NULL, &codeType, NULL);
                }
                
                if (codeType == YZHCodeItemTypeRealF) {
                    float fval = [decodeObject floatValue];
                    CTypeVal = Int32FromFloat(fval);
                    
                    cacheObject.decodeObject = decodeObject;
                    [cacheObject addCTypeValue:CTypeVal CTypeItemType:codeType];
                }
            }
        }
    });
    
    int32_t ival = TYPE_AND(CTypeVal, 0XFFFFFFFF);
    return FloatFromInt32(ival);
}

double YZHCFKV::getDoubleForKey(id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return 0;
    }
    
    __block int64_t CTypeVal = 0;
    _sync_lock(ctx->_lock, ^{
        _YZHCFKVCacheObject *cacheObject = [ctx->_dict objectForKey:key];
        
        if ([cacheObject haveCTypeValue]) {
            CTypeVal = cacheObject.CTypeValue;
        }
        else {
            id decodeObject = cacheObject.decodeObject;
            if (decodeObject == nil) {
                YZHCodeItemType codeType = YZHCodeItemTypeReal;
                if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeDataRange) {

                    YZHCodeData *plainContentData = ctx->_sharedPtrPlainContentData.get();
                    
                    decodeObject = decodeObjectFromBuffer(plainContentData->bytes() + cacheObject.dataRange.location, cacheObject.dataRange.length, NULL, &codeType, NULL);
                }
                else if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeUncodedObject) {
                    decodeObject = [cacheObject cacheObject];
                }
                else if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeEncodedData) {
                    NSData *data = [cacheObject objectEncodedData];
                    decodeObject = decodeObjectFromBuffer((uint8_t*)data.bytes, data.length, NULL, &codeType, NULL);
                }
                
                if (codeType == YZHCodeItemTypeReal) {
                    double dval = [decodeObject doubleValue];
                    CTypeVal = Int64FromDouble(dval);
                    
                    cacheObject.decodeObject = decodeObject;
                    [cacheObject addCTypeValue:CTypeVal CTypeItemType:codeType];
                }
            }
        }
    });

    return DoubleFromInt64(CTypeVal);
}

int64_t YZHCFKV::getIntegerForKey(id key)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO || key == nil) {
        return 0;
    }
    
    __block int64_t CTypeVal = 0;
    _sync_lock(ctx->_lock, ^{
        _YZHCFKVCacheObject *cacheObject = [ctx->_dict objectForKey:key];
        
        if ([cacheObject haveCTypeValue]) {
            CTypeVal = cacheObject.CTypeValue;
        }
        else {
            id decodeObject = cacheObject.decodeObject;
            if (decodeObject == nil) {
                YZHCodeItemType codeType = YZHCodeItemTypeInteger;
                if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeDataRange) {
                    
                    YZHCodeData *plainContentData = ctx->_sharedPtrPlainContentData.get();
                    
                    decodeObject = decodeObjectFromBuffer(plainContentData->bytes() + cacheObject.dataRange.location, cacheObject.dataRange.length, NULL, &codeType, NULL);
                }
                else if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeUncodedObject) {
                    decodeObject = [cacheObject cacheObject];
                }
                else if (cacheObject.cacheObjectType == _YZHCFKVCacheObjectTypeEncodedData) {
                    NSData *data = [cacheObject objectEncodedData];
                    decodeObject = decodeObjectFromBuffer((uint8_t*)data.bytes, data.length, NULL, &codeType, NULL);
                }
                
                if (codeType == YZHCodeItemTypeInteger) {
                    CTypeVal = [decodeObject longLongValue];
                    
                    cacheObject.decodeObject = decodeObject;
                    [cacheObject addCTypeValue:CTypeVal CTypeItemType:codeType];
                }
            }
        }
    });
    
    return CTypeVal;
}

NSDictionary *YZHCFKV::getAllEntries()
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO) {
        return nil;
    }
    
    __block NSDictionary *dict = nil;
    _sync_lock(ctx->_lock, ^{
        dict = [ctx->_dict copy];
    });
    return dict;
}

void YZHCFKV::removeObjectForKey(id key)
{
    setObjectForKey(nil, NULL, key);
}

YZHCFKVError YZHCFKV::getLastError()
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    return ctx->lastError;
}

void YZHCFKV::clear(BOOL truncateFileSize)
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO) {
        return;
    }
    _sync_lock(ctx->_lock, ^{
        _clearEncodeData(ctx, truncateFileSize);
    });
}

void YZHCFKV::close()
{
    struct YZHCFKVContext *ctx = (struct YZHCFKVContext *)ptrCFKVContext;
    if (YZHCFKV_IS_FILE_OPEN(ctx) == NO) {
        return;
    }
    _sync_lock(ctx->_lock, ^{
        _closeFile(ctx);
    });
}
