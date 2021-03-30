//
//  YZHAESCryptor.h
//  YZHKVDemo
//
//  Created by yuan on 2019/7/28.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>

#define AES_KEYSIZE_FROM_KEYTYPE(KEYTYPE)   ((KEYTYPE == YZHAESKeyType192) ? YZHAESKeySize192 : ((KEYTYPE == YZHAESKeyType128) ? YZHAESKeySize128 : YZHAESKeySize256))

typedef NS_ENUM(uint8_t, YZHCryptMode)
{
    YZHCryptModeCFB     = 0,
    YZHCryptModeCFB1    = 1,
    YZHCryptModeCFB8    = 2,
    YZHCryptModeOFB     = 3,
    YZHCryptModeCBC     = 4,
    YZHCryptModeECB     = 5,
};

//按字节算，SizeXXX，XXX按bit位算，枚举值按字节算
typedef NS_ENUM(uint8_t, YZHAESKeySize)
{
    YZHAESKeySize128    = 16,
    YZHAESKeySize192    = 24,
    YZHAESKeySize256    = 32,
};

typedef NS_ENUM(uint8_t, YZHAESKeyType)
{
    YZHAESKeyType128    = 0,
    YZHAESKeyType192    = 1,
    YZHAESKeyType256    = 2,
};

typedef NS_ENUM(uint8_t, YZHCryptOperation)
{
    YZHCryptOperationEncrypt    = 0,
    YZHCryptOperationDecrypt    = 1,
};

typedef NS_ENUM(uint8_t, AESPaddingType)
{
    AESPaddingTypeZero     = 0,
    AESPaddingTypePKCS7    = 1,
};

@class YZHAESCryptor;
typedef NSData*_Nonnull(^YZHAESCryptDataPaddingBlock)(YZHAESCryptor * _Nonnull cryptor, NSData * _Nonnull cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation);

NS_ASSUME_NONNULL_BEGIN

//不对外提供key和对比方法
@interface YZHAESCryptor : NSObject

@property (nonatomic, assign, readonly) YZHAESKeyType keyType;

@property (nonatomic, assign, readonly) YZHCryptMode cryptMode;

//以这种方式初始化，默认为YZHCryptModeECB的加密模式
- (instancetype)initWithAESKey:(NSData*)AESKey keyType:(YZHAESKeyType)keyType;

//输入加密模式及输入向量，如果为YZHCryptModeECB，输入向量不起作用
- (instancetype)initWithAESKey:(NSData *)AESKey keyType:(YZHAESKeyType)keyType inVector:(nullable NSData*)inVector cryptMode:(YZHCryptMode)cryptMode;

- (void)reset;

- (BOOL)isValidCryptor;

//如果指定的是YZHCryptModeECB,CBC加密模式，填充的默认是AESPaddingTypePKCS7
- (NSData*)crypt:(YZHCryptOperation)operation input:(NSData*)input;

- (NSData*)crypt:(YZHCryptOperation)operation input:(NSData*)input paddingType:(AESPaddingType)paddingType paddingBlock:(YZHAESCryptDataPaddingBlock)paddingBlock;

- (void)crypt:(YZHCryptOperation)operation input:(uint8_t*)input inSize:(int64_t)inSize output:(uint8_t*)output outSize:(int64_t*)outSize;

- (void)crypt:(YZHCryptOperation)operation input:(uint8_t*)input inSize:(int64_t)inSize output:(uint8_t*)output outSize:(int64_t*)outSize paddingType:(AESPaddingType)paddingType paddingBlock:(YZHAESCryptDataPaddingBlock)paddingBlock;


@end

NS_ASSUME_NONNULL_END
