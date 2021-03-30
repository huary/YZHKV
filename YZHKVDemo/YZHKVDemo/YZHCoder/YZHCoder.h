//
//  YZHCoderC.h
//  YZHKVDemo
//
//  Created by yuan on 2019/9/6.
//  Copyright © 2019 yuan. All rights reserved.
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
    //数据错误
    YZHCoderErrorDataError      = 4,
    //编码的class错误
    YZHCoderErrorClassError     = 5,
};

/*
 *第1个字节：最高位为1，第4位到第7位为上面的值，第3位到1位为字节数(最大支持到8字节存储的数值：2^64的值)
 *第2-8个字节：存储后面数据长度的数值，(正真存储的字节数按第一字节的最后3比特位组成的数字+1来决定)
 *附后：数据
 *
 */

//encode
NSData *encodeObject(id object);

NSData *encodeObjectToTopSuperClass(id object, Class topSuperClass, NSError **error);

void encodeObjectIntoCodeData(id object, YZHMutableCodeData *codeData, NSError **error);

void encodeObjectToTopSuperClassIntoCodeData(id object, Class topSuperClass, YZHMutableCodeData *codeData, NSError **error);

void encodeFloatIntoCodeData(float val, YZHMutableCodeData *codeData);

void encodeDoubleIntoCodeData(double val, YZHMutableCodeData *codeData);

//可以8、U8,16,U16,32,U32,64,U64
void encodeIntegerIntoCodeData(int64_t val, YZHMutableCodeData *codeData);

void encodeStringIntoCodeData(NSString *text, YZHMutableCodeData *codeData);

void encodeDataIntoCodeData(NSData *data, YZHMutableCodeData *codeData);

//decode
id decodeObjectFromData(NSData *data);

id decodeObjectFromBuffer(uint8_t *buffer ,int64_t length, int64_t *offset, YZHCodeItemType *codeType, NSError **error);

float decodeFloatFromBuffer(uint8_t *buffer, int64_t length, int64_t *offset ,NSError **error);

double decodeDoubleFromBuffer(uint8_t *buffer, int64_t length, int64_t *offset, NSError **error);

int64_t decodeIntegerFromBuffer(uint8_t *buffer, int64_t length, int64_t *offset,NSError **error);

NSString *decodeStringFromBuffer(uint8_t *buffer, int64_t length, int64_t *offset,NSError **error);

NSData *decodeDataFromBuffer(uint8_t *buffer, int64_t length, int64_t *offset,NSError **error);


//这些是同字节数（sizeof）的转换
int32_t Int32FromFloat(float val);

float FloatFromInt32(int32_t val);

int64_t Int64FromDouble(double val);

double DoubleFromInt64(int64_t val);

//将float和Int32进行转换，Int32存在Int64上
int64_t Int64FromFloat(float val);

float FloatFromInt64(int64_t val);


//packet
NSData *packetData(NSData *data,YZHCodeItemType codeType);

void packetDataIntoCodeData(NSData *data,YZHCodeItemType codeType, YZHMutableCodeData *codeData);

void packetCodeData(YZHCodeData *data, YZHCodeItemType codeType, YZHMutableCodeData *codeData);

NSData *unpackData(NSData *data, YZHCodeItemType *codeType, int64_t *size, int64_t *offset);

NSRange unpackBuffer(uint8_t *buffer, int64_t bufferSize, YZHCodeItemType *codeType, int8_t *len, int64_t *size, int64_t *offset);
