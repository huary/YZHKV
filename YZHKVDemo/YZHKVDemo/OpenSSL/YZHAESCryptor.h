//
//  YZHAESCryptor.h
//  YZHKVDemo
//
//  Created by yuan on 2019/7/28.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YZHCodeData.h"

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

class YZHAESCryptor;
typedef void(^YZHAESCryptDataPaddingBlock)(YZHAESCryptor *cryptor, YZHCodeData *cryptData, AESPaddingType paddingType, YZHCryptOperation cryptOperation);


class YZHAESCryptor {
private:
    void *ptrCryptorInfo;
    void setupDefault();
    BOOL setupCryptor(YZHCodeData *key, YZHAESKeyType keyType, YZHCodeData *vector, YZHCryptMode cryptMode);
public:
    //复制了Key中的数据
    YZHAESCryptor(YZHCodeData *AESKey, YZHAESKeyType keyType);
    
    //复制了Key和inVector中的数据
    YZHAESCryptor(YZHCodeData *AESKey, YZHAESKeyType keyType, YZHCodeData *inVector, YZHCryptMode cryptMode);
    
    virtual ~YZHAESCryptor();
  
    void reset();
    
    BOOL isValidCryptor();
    
    YZHAESKeyType getKeyType();
    
    YZHCryptMode getCryptMode();
    
    BOOL crypt(YZHCryptOperation cryptOperation, YZHCodeData *input, YZHCodeData *output);
    
    BOOL crypt(YZHCryptOperation cryptOperation, YZHCodeData *input, YZHCodeData *output, AESPaddingType paddingType, YZHAESCryptDataPaddingBlock paddingBlock);
};
