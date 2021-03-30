//
//  YZHCoder.h
//  PBDemo
//
//  Created by yuan on 2019/5/26.
//  Copyright © 2019年 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YZHCodeData.h"

//最多只能定义16中数字类型
typedef NS_ENUM(NSInteger, YZHCodeItemType)
{
    //是一个整数，可以是1-8个字节
    YZHCodeItemTypeInteger      = 0,
    //是一个浮点数，存储为 8 字节的浮点数字。
    YZHCodeItemTypeReal         = 1,
    //是一个浮点数，存储为 4 字节的浮点数字。
    YZHCodeItemTypeRealF        = 2,
    //是一个文本字段
    YZHCodeItemTypeText         = 3,
    //是一个二进制数据
    YZHCodeItemTypeBlob         = 4,
    //是一个数组[]
    YZHCodeItemTypeArray        = 5,
    //是一个字典{}
    YZHCodeItemTypeDictionary   = 6,
    //NSObject 或者其子类对象
    YZHCodeItemTypeObject       = 7,
    //最大只能到15
    YZHCodeItemTypeMax          = 15,
};


typedef NS_ENUM(NSInteger, YZHCoderError)
{
    //指针为空或者执行的内容长度为0
    YZHCoderErrorPtrNull        = 1,
    //没有找到编码的range
    YZHCoderErrorNotFound       = 2,
    //编码类型错误
    YZHCoderErrorTypeError      = 3,
};

@protocol YZHCoderObjectProtocol <NSObject>

+(NSArray<NSString*>*)hz_objectCodeKeyPaths;

+(Class)hz_objectCodeTopEdgeSuperClass;

@end


/**********************************************************************
 *NSObject (TopEdgeSuperClass)
 ***********************************************************************/
@interface NSObject (YZHCoderToTopEdgeSuperClass)

-(Class)hz_getObjectCodeTopEdgeSuperClass;

@end

/*
 *第1个字节：最高位为1，第4位到第7位为上面的值，第3位到1位为字节数(最大支持到8字节存储的数值：2^64的值)
 *第2-8个字节：存储后面数据长度的数值，(正真存储的字节数按第一字节的最后3比特位组成的数字+1来决定)
 *附后：数据
 *
 */

@interface YZHCoder : NSObject

+ (NSData*)encodeObject:(id)object;

+ (NSData*)encodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass;

+ (void)encodeObject:(id)object intoCodeData:(YZHMutableCodeData*)codeData;

+ (void)encodeObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass intoCodeData:(YZHMutableCodeData*)codeData;

+ (id)decodeObjectWithData:(NSData*)data;

+ (id)decodeObjectFromBuffer:(uint8_t*)buffer length:(NSInteger)length;

+ (id)decodeObjectFromBuffer:(uint8_t*)buffer length:(NSInteger)length offset:(int64_t*)offset;

+ (float)decodeFloatFromBuffer:(uint8_t*)buffer length:(NSInteger)length offset:(int64_t*)offset error:(NSError**)error;

+ (double)decodeDoubleFromBuffer:(uint8_t*)buffer length:(NSInteger)length offset:(int64_t*)offset error:(NSError**)error;

+ (int64_t)decodeIntegerFromBuffer:(uint8_t*)buffer length:(NSInteger)length offset:(int64_t*)offset error:(NSError**)error;

+ (NSData*)packetData:(NSData*)data codeType:(YZHCodeItemType)codeType;

+ (void)packetData:(NSData*)data codeType:(YZHCodeItemType)codeType intoCodeData:(YZHMutableCodeData*)codeData;

+ (void)packetCodeData:(YZHCodeData*)data codeType:(YZHCodeItemType)codeType intoCodeData:(YZHMutableCodeData*)codeData;

+ (NSData*)unpackData:(NSData*)data codeType:(YZHCodeItemType*)codeType size:(int64_t*)size offset:(int64_t*)offset;

+ (NSRange)unpackBuffer:(uint8_t*)buffer bufferSize:(int64_t)bufferSize codeType:(YZHCodeItemType*)codeType len:(int8_t*)len size:(int64_t*)size offset:(int64_t*)offset;

+ (NSData*)encodeBool:(BOOL)val;

+ (NSData*)encodeInt8:(int8_t)val;

+ (NSData*)encodeUInt8:(uint8_t)val;

+ (NSData*)encodeInt16:(int16_t)val;

+ (NSData*)encodeUInt16:(uint16_t)val;

+ (NSData*)encodeInt32:(int32_t)val;

+ (NSData*)encodeUInt32:(uint32_t)val;

+ (NSData*)encodeInt64:(int64_t)val;

+ (NSData*)encodeUInt64:(uint64_t)val;

+ (NSData*)encodeFloat:(float)val;

+ (NSData*)encodeDouble:(double)val;

//这三个可以加快编码速度
+ (void)encodeFloat:(float)val intoCodeData:(YZHMutableCodeData*)codeData;

+ (void)encodeDouble:(double)val intoCodeData:(YZHMutableCodeData*)codeData;

//可以8、U8,16,U16,32,U32,64,U64
+ (void)encodeInteger:(int64_t)val intoCodeData:(YZHMutableCodeData*)codeData;

+ (void)encodeString:(NSString*)text intoCodeData:(YZHMutableCodeData*)codeData;

+ (BOOL)decodeBoolWithData:(NSData*)data;

+ (int8_t)decodeInt8WithData:(NSData*)data;

+ (uint8_t)decodeUInt8WithData:(NSData*)data;

+ (int16_t)decodeInt16WithData:(NSData*)data;

+ (uint16_t)decodeUInt16WithData:(NSData*)data;

+ (int32_t)decodeInt32WithData:(NSData*)data;

+ (uint32_t)decodeUInt32WithData:(NSData*)data;

+ (int64_t)decodeInt64WithData:(NSData*)data;

+ (uint64_t)decodeUInt64WithData:(NSData*)data;

+ (float)decodeFloatWithData:(NSData*)data;

+ (double)decodeDoubleWithData:(NSData*)data;

//这些是同字节数（sizeof）的转换
+ (int32_t)convertInt32FromFloat:(float)val;

+ (float)convertFloatFromInt32:(int32_t)val;

+ (int64_t)convertInt64FromDouble:(double)val;

+ (double)convertDoubleFromInt64:(int64_t)val;



@end
