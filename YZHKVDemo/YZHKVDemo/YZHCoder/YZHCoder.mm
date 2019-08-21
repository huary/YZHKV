//
//  YZHCoder.m
//  PBDemo
//
//  Created by yuan on 2019/5/26.
//  Copyright © 2019年 yuan. All rights reserved.
//

#import "YZHCoder.h"
#import "type.h"
#import "macro.h"
#import <objc/runTime.h>


#define BYTE_CNT_FIELD_LEN      (4)
#define BYTE_CNT_FIELD_MASK     (TYPE_LS(1,BYTE_CNT_FIELD_LEN) - 1)

#define TYPE_FIELD_OFFSET       BYTE_CNT_FIELD_LEN
#define TYPE_FIELD_LEN          (7 - BYTE_CNT_FIELD_LEN)
#define TYPE_FIELD_MASK         (TYPE_LS(1, TYPE_FIELD_LEN) - 1)


#define YZH_CODER_ESTIMATE_RESERVED_BYTE_CNT     (3)

template <typename F, typename T>
union Converter {
    static_assert(sizeof(F) == sizeof(T),"size not match");
    F from;
    T to;
    
public:
    void decodeFromBuffer(uint8_t *ptr) {
        if (ptr == NULL) return;
        uint8_t len = sizeof(from);
        to = 0;
        for (uint8_t i = 0; i < len; ++i) {
            T v = ptr[i];
            to |= TYPE_LS(v, TYPE_LS(i, 3));
        }
    }
    void decodeFromData(NSData *data) {
        decodeFromBuffer(data.bytes);
    }
    
    void encodeToBuffer(uint8_t *buffer) {
        if (buffer == NULL) return;
        uint8_t len = sizeof(from);
        for (uint8_t i = 0; i < len; ++i) {
            buffer[i] = TYPE_AND(TYPE_RS(to, TYPE_LS(i, 3)), FIR_BYTE_MASK);
        }
    }
    NSData *encodeToData() {
        uint8_t len = sizeof(from);
        NSMutableData *dt = [NSMutableData dataWithLength:len];
        encodeToBuffer((uint8_t*)dt.bytes);
        return dt;
    }

};


/**********************************************************************
 *<#desc#>
 ***********************************************************************/
@implementation NSObject (YZHCoderToTopEdgeSuperClass)

-(Class)hz_getObjectCodeTopEdgeSuperClass
{
    Class objCls = object_getClass(self);
    if ([objCls respondsToSelector:@selector(hz_objectCodeTopEdgeSuperClass)]) {
        return [objCls hz_objectCodeTopEdgeSuperClass];
    }
    return nil;
}

@end


/**********************************************************************
 *YZHCoder
 ***********************************************************************/
@interface YZHCoder ()
@end

@implementation YZHCoder

static inline int64_t integerToZigzag(int64_t n)
{
    return (n << 1 ) ^ (n >> 63);
}

static inline int64_t zigzagToInteger(int64_t n)
{
    return (((uint64_t)n) >> 1 ) ^ (-(n & 1));
}

+ (NSInteger)_encodeInt64Size:(int64_t)val
{
    return TYPEULL_BYTES_N(val);
}

+ (NSData*)_encodeInt64:(int64_t)val
{
    uint8_t len = TYPEULL_BYTES_N(val);
    NSMutableData *dt = [NSMutableData dataWithLength:len];
    uint8_t *ptr = (uint8_t*)dt.mutableBytes;
    for (uint8_t i = 0; i < len; ++i) {
        ptr[i] = TYPE_AND(TYPE_RS(val, TYPE_LS(i, 3)), FIR_BYTE_MASK);
    }
    return dt;//[dt copy];
}

+ (uint8_t)_encodeInt64:(int64_t)val toBuffer:(uint8_t*)buffer
{
    if (buffer == NULL) {
        return 0;
    }
    uint8_t len = TYPEULL_BYTES_N(val);
    for (uint8_t i = 0; i < len; ++i) {
        buffer[i] = TYPE_AND(TYPE_RS(val, TYPE_LS(i, 3)), FIR_BYTE_MASK);
    }
    return len;
}

+ (int64_t)_decodeInt64:(uint8_t*)ptr len:(uint8_t)len
{
    int64_t val = 0;
    for (uint8_t i = 0; i < len; ++i) {
        int64_t v = ptr[i];
        val |= TYPE_LS(v, TYPE_LS(i, 3));
    }
    return val;
}

+ (NSData*)_encodeDouble:(double)val
{
    Converter<double, uint64_t> converter;
    converter.from = val;
    return converter.encodeToData();
}

+ (void)_encodeDouble:(double)val toBuffer:(uint8_t*)buffer
{
    if (buffer == NULL) {
        return;
    }
    Converter<double, uint64_t> converter;
    converter.from = val;
    converter.encodeToBuffer(buffer);
}

+ (double)_decodeDouble:(uint8_t*)ptr
{
    Converter<double, uint64_t> converter;
    converter.decodeFromBuffer(ptr);
    return converter.from;
}


+ (NSData*)_encodeFloat:(float)val
{
    Converter<float, uint32_t> converter;
    converter.from = val;
    return converter.encodeToData();
}

+ (void)_encodeFloat:(float)val toBuffer:(uint8_t*)buffer
{
    if (buffer == NULL) {
        return;
    }
    Converter<float, uint32_t> converter;
    converter.from = val;
    converter.encodeToBuffer(buffer);
}

+ (float)_decodeFloat:(uint8_t*)ptr
{
    Converter<float, uint32_t> converter;
    converter.decodeFromBuffer(ptr);
    return converter.from;
}


+ (NSData*)_archivedDataWithObject:(id)object
{
    NSData *data = nil;
    if ([object conformsToProtocol:@protocol(NSCoding)]) {
        if ([NSKeyedArchiver respondsToSelector:@selector(archivedDataWithRootObject:requiringSecureCoding:error:)]) {
            NSError *error = nil;
            data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:&error];
            NSLog(@"error=%@",error);
        }
        if (data == nil && [NSKeyedArchiver respondsToSelector:@selector(archivedDataWithRootObject:)]) {
            data = [NSKeyedArchiver archivedDataWithRootObject:object];
        }
    }
    return data;
}

+ (id)_unarchiveObjectWithData:(NSData*)data withClass:(Class)cls
{
    if (data == nil) {
        return nil;
    }
    id object = [cls new];
    if ([object conformsToProtocol:@protocol(NSCoding)]) {
        if ([NSKeyedUnarchiver respondsToSelector:@selector(unarchivedObjectOfClass:fromData:error:)]) {
            NSError *error = nil;
            object = [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:&error];
            NSLog(@"error=%@",error);
        }
        
        if (object == nil && [NSKeyedUnarchiver respondsToSelector:@selector(unarchiveObjectWithData:)]) {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
    }
    return object;
}

+ (NSArray<NSString*>*)_propertiesForClass:(Class)cls
{
    uint32_t count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    NSMutableArray *list = [NSMutableArray new];
    for (uint32_t i = 0; i < count; ++i) {
        @autoreleasepool {
            objc_property_t property = properties[i];
            const char *nameStr = property_getName(property);
            NSString *name = [NSString stringWithUTF8String:nameStr];
            
            const char *attr = property_getAttributes(property);
            NSString *attrName = [NSString stringWithUTF8String:attr];
            
            //只保护property的，分类动态联合的不进行编码
            NSString *contains = [NSString stringWithFormat:@"V_%@",name];
            if ([attrName containsString:contains]) {
                [list addObject:name];
            }
        }
    }
    if (properties) {
        free(properties);
    }
    return list;//[list copy];
}

/*
 *这个是不对参数object、from、topEdgeSupperClass检查
 */
+ (void)_recursionObjectWithoutCheck:(id)object fromClass:(Class)from topEdgeSuperClass:(Class)topEdgeSuperClass intoCodeData:(YZHMutableCodeData*)codeData
{
    if (codeData == nil) {
        return;
    }
    if (topEdgeSuperClass && [from isEqual:topEdgeSuperClass] == NO) {
        [self _recursionObjectWithoutCheck:object fromClass:[from superclass] topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
    }
    
    NSArray *codeKeyPaths = nil;
    if ([from respondsToSelector:@selector(hz_objectCodeKeyPaths)]) {
        codeKeyPaths = [from hz_objectCodeKeyPaths];
    }
    else {
        codeKeyPaths = [self _propertiesForClass:from];
    }
    
    [codeKeyPaths enumerateObjectsUsingBlock:^(id  _Nonnull key, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([object respondsToSelector:NSSelectorFromString(key)]) {
            id propertyValue = [object valueForKeyPath:key];
            
            [self _mergeEncodeObject:propertyValue topEdgeSuperClass:[propertyValue hz_getObjectCodeTopEdgeSuperClass] withKey:key intoCodeData:codeData];
        }
    }];
}

+ (void)_encodeObject:(id)object fromClass:(Class)from topEdgeSuperClass:(Class)topEdgeSuperClass intoCodeData:(YZHMutableCodeData*)codeData
{
    if (!object) {
        return;
    }
    
    if (from == NULL || [object isKindOfClass:from] == NO) {
        from = object_getClass(object);
    }
    
    if (topEdgeSuperClass == NULL) {
        topEdgeSuperClass = from;
    }
    else {
        if ([object isKindOfClass:topEdgeSuperClass] == NO || [from isSubclassOfClass:topEdgeSuperClass] == NO) {
            topEdgeSuperClass = NULL;
        }
    }
    [self _recursionObjectWithoutCheck:object fromClass:from topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
}

/*
 *这个是不对参数object、from、topEdgeSupperClass检查
 */
//+ (NSMutableData*)_recursionObjectWithoutCheck:(id)object fromClass:(Class)from topEdgeSuperClass:(Class)topEdgeSuperClass
//{
//    YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] init];
//    [self _recursionObjectWithoutCheck:object fromClass:from topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
//    return [codeData mutableCopyData];
//}

//+ (NSData*)_encodeObject:(id)object fromClass:(Class)from topEdgeSuperClass:(Class)topEdgeSuperClass
//{
//    YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] init];
//    [self _encodeObject:object fromClass:from topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
//    return [codeData copyData];
//}

//+ (NSData*)_mergeEncodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass withKey:(id)key
//{
//    YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] init];
//    [self _mergeEncodeObject:object topEdgeSuperClass:topEdgeSuperClass withKey:key intoCodeData:codeData];
//    return [codeData copyData];
//}

+ (void)_mergeEncodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass withKey:(id)key intoCodeData:(YZHMutableCodeData*)codeData
{
    int64_t start = [codeData currentSeek];
    [self _encodeObject:key topEdgeSuperClass:nil intoCodeData:codeData];
    int64_t keyOffset = [codeData currentSeek];
    if (keyOffset - start <= 0) {
        [codeData truncateTo:start];
        return;
    }
    [self _encodeObject:object topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
    int64_t objectOffset = [codeData currentSeek];
    if (objectOffset - keyOffset <= 0) {
        [codeData truncateTo:start];
    }
}

+ (void)_estimateReservedEncodeObjectWithCodeType:(YZHCodeItemType)codeType intoCodeData:(YZHMutableCodeData*)codeData withEncodeBlock:(void(^)(YZHMutableCodeData *codeData))encodeBlock
{
    int64_t oldSize = [codeData dataSize];
    [codeData ensureRemSize:YZH_CODER_ESTIMATE_RESERVED_BYTE_CNT];
    int64_t startOffset = oldSize + YZH_CODER_ESTIMATE_RESERVED_BYTE_CNT;
    [codeData seekTo:startOffset];
    
    if (encodeBlock) {
        encodeBlock(codeData);
    }
    
    int64_t endOffset = [codeData dataSize];
    int64_t addSize = endOffset - startOffset;
    if (addSize > 0) {
        int8_t payloadHeaderSize = TYPEULL_BYTES_N(addSize) + 1;
        int8_t shift = payloadHeaderSize - YZH_CODER_ESTIMATE_RESERVED_BYTE_CNT;
        if (shift != 0) {
            if (shift > 0) {
                [codeData ensureRemSize:shift];
            }
            memmove(codeData.bytes + oldSize + payloadHeaderSize, codeData.bytes + startOffset, codeData.dataSize - startOffset);
        }
        [codeData seekTo:oldSize];
        [self _packetHeader:addSize codeType:codeType intoCodeData:codeData];
//        [codeData seekTo:oldSize + payloadHeaderSize + addSize];
        [codeData truncateTo:oldSize + payloadHeaderSize + addSize];
    }
    else {
        [codeData truncateTo:oldSize];
    }
}
    

+ (void)_encodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass intoCodeData:(YZHMutableCodeData*)codeData
{
    if (object == nil || codeData == nil) {
        return;
    }
    
    if ([object isKindOfClass:[NSNumber class]]) {
        NSNumber *num = object;
        int8_t type = num.objCType ? num.objCType[0] : 0;
        if (type == 'd') {
            double val = [num doubleValue];
            [self encodeDouble:val intoCodeData:codeData];
        }
        else if (type == 'f') {
            float val = [num floatValue];
            [self encodeFloat:val intoCodeData:codeData];
        }
        else {
            int64_t val = [num longLongValue];
            [self encodeInteger:val intoCodeData:codeData];
        }
    }
    else if ([object isKindOfClass:[NSString class]]) {
        NSString *text = object;
        [self encodeString:text intoCodeData:codeData];
    }
    else if ([object isKindOfClass:[NSData class]]) {
        NSData *data = object;
        return [self packetData:data codeType:YZHCodeItemTypeBlob intoCodeData:codeData];
    }
    else if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        
        [self _estimateReservedEncodeObjectWithCodeType:YZHCodeItemTypeArray intoCodeData:codeData withEncodeBlock:^(YZHMutableCodeData *codeData) {
            [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self encodeObject:obj intoCodeData:codeData];
            }];
        }];
    }
    else if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = object;
        
        [self _estimateReservedEncodeObjectWithCodeType:YZHCodeItemTypeDictionary intoCodeData:codeData withEncodeBlock:^(YZHMutableCodeData *codeData) {
            [dict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [self _mergeEncodeObject:obj topEdgeSuperClass:[obj hz_getObjectCodeTopEdgeSuperClass] withKey:key intoCodeData:codeData];
            }];
        }];
    }
    else if ([object isKindOfClass:[NSObject class]]) {
        [self _estimateReservedEncodeObjectWithCodeType:YZHCodeItemTypeObject intoCodeData:codeData withEncodeBlock:^(YZHMutableCodeData *codeData) {
            
            uint64_t startOffset = codeData.dataSize;
            
            Class cls = object_getClass(object);
            NSString *clsName = [NSString stringWithUTF8String:class_getName(cls)];
            [self encodeString:clsName intoCodeData:codeData];
            
            uint64_t startObjOffset = codeData.dataSize;
            
            [self _estimateReservedEncodeObjectWithCodeType:YZHCodeItemTypeBlob intoCodeData:codeData withEncodeBlock:^(YZHMutableCodeData *codeData) {
                if ([object conformsToProtocol:@protocol(NSCoding)]) {
                    NSData *objDt = [self _archivedDataWithObject:object];
                    [codeData appendWriteData:objDt];
                }
                else {
                    [self _encodeObject:object fromClass:object_getClass(object) topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
                }
            }];
            
            int64_t endObjOffset = codeData.dataSize;
            if (endObjOffset - startObjOffset <= 0) {
                [codeData truncateTo:startOffset];
            }
        }];
    }
    else {
        
    }
}

+ (NSData*)encodeObject:(id)object
{
    Class topEdgeClass = [object hz_getObjectCodeTopEdgeSuperClass];
    return [self encodeObject:object topEdgeSuperClass:topEdgeClass];
}

+ (NSData*)encodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass
{
    return [self _encodeObject:object topEdgeSuperClass:topEdgeSuperClass];
}

+ (void)encodeObject:(id)object intoCodeData:(YZHMutableCodeData*)codeData
{
    Class topEdgeClass = [object hz_getObjectCodeTopEdgeSuperClass];
    [self _encodeObject:object topEdgeSuperClass:topEdgeClass intoCodeData:codeData];
}

+ (void)encodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass intoCodeData:(YZHMutableCodeData*)codeData
{
    [self _encodeObject:object topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
}

+ (NSData*)_encodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass
{
    YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] init];
    [self _encodeObject:object topEdgeSuperClass:topEdgeSuperClass intoCodeData:codeData];
    return [codeData copyData];
}

#pragma mark decode
+ (id)decodeObjectWithData:(NSData*)data
{
    return [self decodeObjectFromBuffer:(uint8_t*)data.bytes length:data.length offset:NULL];
}

+ (id)decodeObjectFromBuffer:(uint8_t*)buffer length:(NSInteger)length
{
    return [self decodeObjectFromBuffer:buffer length:length offset:NULL];
}

+ (id)decodeObjectFromBuffer:(uint8_t*)buffer length:(NSInteger)length offset:(int64_t*)offset
{
    if (buffer == nil || length <= 0) {
        if (offset) {
            *offset = 0;
        }
        return nil;
    }
    
    int8_t len = 0;
    int64_t size = 0;
    YZHCodeItemType codeType;
    NSRange r = [self unpackBuffer:buffer bufferSize:length codeType:&codeType len:&len size:&size offset:offset];
    if (r.location == NSNotFound) {
        return nil;
    }
    uint8_t *ptr = buffer + r.location;
    
    switch (codeType) {
        case YZHCodeItemTypeReal: {
            double val = [self _decodeDouble:ptr];
            return [NSNumber numberWithDouble:val];
        }
        case YZHCodeItemTypeRealF: {
            float val = [self _decodeFloat:ptr];
            return [NSNumber numberWithFloat:val];
        }
        case YZHCodeItemTypeInteger: {
            int64_t val = size;
            val = zigzagToInteger(val);
            return @(val);
        }
        case YZHCodeItemTypeText: {
            NSString *text = [[NSString alloc] initWithBytes:ptr
                                                      length:(NSUInteger)size
                                                    encoding:NSUTF8StringEncoding];
            return text;
        }
        case YZHCodeItemTypeBlob: {
            return [NSData dataWithBytes:ptr length:r.length];
//            return [NSData dataWithBytesNoCopy:ptr length:r.length freeWhenDone:NO];
        }
        case YZHCodeItemTypeArray: {
            NSMutableArray *array = [NSMutableArray array];
            while (size > 0) {
                int64_t offsetTmp = 0;
                id obj = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
                if (obj) {
                    [array addObject:obj];
                }
                ptr += offsetTmp;
                size -= offsetTmp;
            }
            
            return array;
        }
        case YZHCodeItemTypeDictionary: {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            while (size > 0) {
                int64_t offsetTmp = 0;
                id key = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
                ptr += offsetTmp;
                size -= offsetTmp;
                //这里key有可能为nil,但是offsetTmp不能为0
                if (size <= 0 || offsetTmp <= 0/*key == nil*/) {
                    break;
                }
                
                id obj = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
                ptr += offsetTmp;
                size -= offsetTmp;
                if (key && obj) {
                    [dict setObject:obj forKey:key];
                }
                if (offsetTmp <= 0) {
                    break;
                }
            }
            
            return dict;
        }
        case YZHCodeItemTypeObject: {
            int64_t offsetTmp = 0;
            NSString *clsName = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
            ptr += offsetTmp;
            size -= offsetTmp;
            if (size <= 0) {
                return nil;
            }
            Class cls = NSClassFromString(clsName);
            //这里的cls可能为nil,申请的object为nil时判断
            id object = [cls new];
            if (object == nil) {
                return object;
            }
            
            NSData *data = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:NULL];
            ptr = (uint8_t*)data.bytes;
            size = data.length;
            if ([object conformsToProtocol:@protocol(NSCoding)]) {
                object = [self _unarchiveObjectWithData:data withClass:cls];
            }
            else {
                while (size > 0) {
                    int64_t offsetTmp = 0;
                    id key = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
                    ptr += offsetTmp;
                    size -= offsetTmp;
                    //key可能为nil，但是offsetTmp必须大于0
                    if (size <= 0 || offsetTmp <= 0/*|| key == nil*/) {
                        break;
                    }
                    
                    id obj = [self decodeObjectFromBuffer:ptr length:(NSInteger)size offset:&offsetTmp];
                    ptr += offsetTmp;
                    size -= offsetTmp;
                    if (key) {
                        if ([object respondsToSelector:NSSelectorFromString(key)]) {
                            [object setValue:obj forKey:key];
                        }
                    }
                    if (offsetTmp <= 0) {
                        break;
                    }
                }
            }
            return object;
        }
        default:
            break;
    }
    return nil;
}

#pragma mark packet
+ (NSData*)packetData:(NSData*)data codeType:(YZHCodeItemType)codeType
{
    YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] init];
    [self packetData:data codeType:codeType intoCodeData:codeData];
    return [codeData copyData];
}

+ (void)packetData:(NSData*)data codeType:(YZHCodeItemType)codeType intoCodeData:(YZHMutableCodeData*)codeData
{
    [self packetCodeData:[[YZHCodeData alloc] initWithData:data] codeType:codeType intoCodeData:codeData];
}

+ (void)packetCodeData:(YZHCodeData*)data codeType:(YZHCodeItemType)codeType intoCodeData:(YZHMutableCodeData*)codeData
{
    if (codeData == nil) {
        return;
    }
    int64_t len = data.dataSize;
    [self _packetHeader:len codeType:codeType intoCodeData:codeData];
    if (data) {
        [codeData appendWriteBuffer:data.bytes size:len];
    }
}

+ (void)_packetHeader:(int64_t)payloadLength codeType:(YZHCodeItemType)codeType intoCodeData:(YZHMutableCodeData*)codeData
{
    uint8_t type = TYPE_LS(1, 7);
    int64_t len = payloadLength;
    uint8_t cnt = TYPEULL_BYTES_N(len);
    BOOL haveLoadLength = YES;
    if (codeType == YZHCodeItemTypeReal || codeType == YZHCodeItemTypeRealF || codeType == YZHCodeItemTypeInteger) {
        cnt = len;
        haveLoadLength = NO;
    }
    type |= TYPE_AND(cnt - 1, BYTE_CNT_FIELD_MASK);
    type |= TYPE_LS(TYPE_AND(codeType, TYPE_FIELD_MASK), TYPE_FIELD_OFFSET);
    
    [codeData appendWriteByte:type];
    
    if (haveLoadLength) {
        [codeData ensureRemSize:cnt];
        int64_t startOffset = [codeData dataSize];
        [self _encodeInt64:len toBuffer:codeData.bytes + startOffset];
        [codeData seekTo:startOffset + cnt];
    }
}

+ (NSData*)unpackData:(NSData*)data codeType:(YZHCodeItemType*)codeType size:(int64_t*)size offset:(int64_t*)offset
{
    return [self _unpackData:data codeType:codeType len:NULL size:size offset:offset];
}

+ (NSData*)_unpackData:(NSData*)data codeType:(YZHCodeItemType*)codeType len:(int8_t*)len size:(int64_t*)size offset:(int64_t*)offset
{
    NSRange r = [self unpackBuffer:(uint8_t*)data.bytes bufferSize:data.length codeType:codeType len:len size:size offset:offset];
    if (r.location == NSNotFound) {
        return nil;
    }
    return [data subdataWithRange:r];
}

+ (NSRange)unpackBuffer:(uint8_t*)buffer bufferSize:(int64_t)bufferSize codeType:(YZHCodeItemType*)codeType len:(int8_t*)len size:(int64_t*)size offset:(int64_t*)offset
{
    NSRange r = NSMakeRange(NSNotFound, 0);
    if (buffer == nullptr || bufferSize <= 0) {
        return r;
    }
    int64_t length = bufferSize;
    uint8_t *ptr = buffer;
    uint8_t type = ptr[0];
    if (type < TYPE_LS(1, 7)) {
        return r;
    }
    uint8_t lenTmp = TYPE_AND(type, BYTE_CNT_FIELD_MASK) + 1;
    if (len) {
        *len = lenTmp;
    }
    uint8_t codeTypeTmp = TYPE_AND(TYPE_RS(type, TYPE_FIELD_OFFSET), TYPE_FIELD_MASK);
    if (codeType) {
        *codeType = (YZHCodeItemType)codeTypeTmp;
    }
    
    if (length < 1 + lenTmp) {
        return r;
    }
    
    ++ptr;
    if (offset) {
        *offset = 1;
    }
    
    uint64_t sizeTmp = [self _decodeInt64:ptr len:lenTmp];
    ptr += lenTmp;
    if (offset) {
        *offset = 1 + lenTmp;
    }
    if (size) {
        *size = sizeTmp;
    }
    if (codeTypeTmp == YZHCodeItemTypeReal || codeTypeTmp == YZHCodeItemTypeRealF || codeTypeTmp == YZHCodeItemTypeInteger) {
        return NSMakeRange(1, lenTmp);
    }
    
    if (length < 1 + lenTmp + sizeTmp) {
        return r;
    }
    
    if (offset) {
        *offset = 1 + lenTmp + sizeTmp;
    }
    return NSMakeRange(NSUInteger(1 + lenTmp), (NSUInteger)sizeTmp);
}


+ (NSData*)encodeBool:(BOOL)val
{
    return [self encodeObject:[NSNumber numberWithBool:val]];
}

+ (NSData*)encodeInt8:(int8_t)val
{
    return [self encodeObject:[NSNumber numberWithChar:val]];
}

+ (NSData*)encodeUInt8:(uint8_t)val
{
    return [self encodeObject:[NSNumber numberWithUnsignedChar:val]];
}

+ (NSData*)encodeInt16:(int16_t)val
{
    return [self encodeObject:[NSNumber numberWithShort:val]];
}

+ (NSData*)encodeUInt16:(uint16_t)val
{
    return [self encodeObject:[NSNumber numberWithUnsignedShort:val]];
}

+ (NSData*)encodeInt32:(int32_t)val
{    
    return [self encodeObject:[NSNumber numberWithInt:val]];
}

+ (NSData*)encodeUInt32:(uint32_t)val
{
    return [self encodeObject:[NSNumber numberWithUnsignedInt:val]];

}

+ (NSData*)encodeInt64:(int64_t)val
{
    return [self encodeObject:[NSNumber numberWithLongLong:val]];
}

+ (NSData*)encodeUInt64:(uint64_t)val
{
    return [self encodeObject:[NSNumber numberWithUnsignedLongLong:val]];
}

+ (NSData*)encodeFloat:(float)val
{
    return [self encodeObject:[NSNumber numberWithFloat:val]];
}

+ (NSData*)encodeDouble:(double)val
{
    return [self encodeObject:[NSNumber numberWithDouble:val]];
}


+ (void)encodeFloat:(float)val intoCodeData:(YZHMutableCodeData*)codeData
{
    if (codeData == nil) {
        return;
    }
    
    uint8_t type = TYPE_LS(1, 7);
    uint8_t cnt = sizeof(val);
    YZHCodeItemType codeType = YZHCodeItemTypeRealF;
    
    type |= TYPE_AND(cnt - 1, BYTE_CNT_FIELD_MASK);
    type |= TYPE_LS(TYPE_AND(codeType, TYPE_FIELD_MASK), TYPE_FIELD_OFFSET);
    
    [codeData appendWriteByte:type];
    
    [codeData ensureRemSize:cnt];
    
    int64_t startOffset = [codeData dataSize];
    [self _encodeFloat:val toBuffer:codeData.bytes + startOffset];
    [codeData seekTo:startOffset + cnt];
}

+ (void)encodeDouble:(double)val intoCodeData:(YZHMutableCodeData*)codeData
{
    if (codeData == nil) {
        return;
    }
    uint8_t type = TYPE_LS(1, 7);
    uint8_t cnt = sizeof(val);
    YZHCodeItemType codeType = YZHCodeItemTypeReal;
    
    type |= TYPE_AND(cnt - 1, BYTE_CNT_FIELD_MASK);
    type |= TYPE_LS(TYPE_AND(codeType, TYPE_FIELD_MASK), TYPE_FIELD_OFFSET);
    
    [codeData appendWriteByte:type];
    
    [codeData ensureRemSize:cnt];
    
    int64_t startOffset = [codeData dataSize];
    [self _encodeDouble:val toBuffer:codeData.bytes + startOffset];
    [codeData seekTo:startOffset + cnt];
}

+ (void)encodeInteger:(int64_t)val intoCodeData:(YZHMutableCodeData*)codeData
{
    if (codeData == nil) {
        return;
    }
    val = integerToZigzag(val);
    uint8_t type = TYPE_LS(1, 7);
    uint8_t cnt = TYPEULL_BYTES_N(val);
    YZHCodeItemType codeType = YZHCodeItemTypeInteger;
    
    type |= TYPE_AND(cnt - 1, BYTE_CNT_FIELD_MASK);
    type |= TYPE_LS(TYPE_AND(codeType, TYPE_FIELD_MASK), TYPE_FIELD_OFFSET);
    
    [codeData appendWriteByte:type];
    
    [codeData ensureRemSize:cnt];
    
    int64_t startOffset = [codeData dataSize];
    [self _encodeInt64:val toBuffer:codeData.bytes + startOffset];
    [codeData seekTo:startOffset + cnt];
}

+ (void)encodeString:(NSString*)text intoCodeData:(YZHMutableCodeData*)codeData
{
    if (text == nil || codeData == nil) {
        return;
    }
    uint8_t type = TYPE_LS(1, 7);
    int64_t len = [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    uint8_t cnt = TYPEULL_BYTES_N(len);
    YZHCodeItemType codeType = YZHCodeItemTypeText;
    
    type |= TYPE_AND(cnt - 1, BYTE_CNT_FIELD_MASK);
    type |= TYPE_LS(TYPE_AND(codeType, TYPE_FIELD_MASK), TYPE_FIELD_OFFSET);
    
    [codeData appendWriteByte:type];
    
    [codeData ensureRemSize:cnt + len];
    
    int64_t startOffset = [codeData dataSize];
    [self _encodeInt64:len toBuffer:codeData.bytes + startOffset];
    [codeData seekTo:startOffset + cnt];
    
    [text getBytes:codeData.bytes + startOffset + cnt
         maxLength:(NSUInteger)len
        usedLength:0
          encoding:NSUTF8StringEncoding
           options:0
             range:NSMakeRange(0, text.length)
    remainingRange:NULL];
    
    [codeData seekTo:startOffset + cnt + len];
}


+ (BOOL)decodeBoolWithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] boolValue];
}

+ (int8_t)decodeInt8WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] charValue];
}

+ (uint8_t)decodeUInt8WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] unsignedCharValue];
}

+ (int16_t)decodeInt16WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] shortValue];
}

+ (uint16_t)decodeUInt16WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] unsignedShortValue];
}

+ (int32_t)decodeInt32WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] intValue];
}

+ (uint32_t)decodeUInt32WithData:(NSData*)data
{
     return [[self decodeObjectWithData:data] unsignedIntValue];
}

+ (int64_t)decodeInt64WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] longLongValue];
}

+ (uint64_t)decodeUInt64WithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] unsignedLongLongValue];
}

+ (float)decodeFloatWithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] floatValue];
}

+ (double)decodeDoubleWithData:(NSData*)data
{
    return [[self decodeObjectWithData:data] doubleValue];

}

@end
