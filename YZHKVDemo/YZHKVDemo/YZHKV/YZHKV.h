//
//  YZHKV.h
//  YZHKVDemo
//
//  Created by yuan on 2019/6/30.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YZHAESCryptor.h"

typedef void(^YZHKVGetBoolBlock)(BOOL value);
typedef void(^YZHKVGetInt8Block)(int8_t value);
typedef void(^YZHKVGetUInt8Block)(uint8_t value);
typedef void(^YZHKVGetInt16Block)(int16_t value);
typedef void(^YZHKVGetUInt16Block)(uint16_t value);
typedef void(^YZHKVGetInt32Block)(int32_t value);
typedef void(^YZHKVGetUInt32Block)(uint32_t value);
typedef void(^YZHKVGetInt64Block)(int64_t value);
typedef void(^YZHKVGetUInt64Block)(uint64_t value);
typedef void(^YZHKVGetFloatBlock)(float value);
typedef void(^YZHKVGetDoubleBlock)(double value);
typedef void(^YZHKVGetObjectBlock)(id object);

typedef NS_ENUM(NSInteger, YZHKVError)
{
    //密码错误
    YZHKVErrorCryptKeyError     = 1,
    //编码错误
    YZHKVErrorCoderError        = 2,
    //CRC不一样错误
    YZHKVErrorCRCError          = 3,
    
};


@class YZHKV;
@protocol YZHKVDelegate <NSObject>

//报告严重错误，一般是直接
- (void)kv:(YZHKV*)kv reportError:(NSError*)error;
- (BOOL)kv:(YZHKV*)kv reportCheckFailedError:(NSError*)error;

@end



@interface YZHKV : NSObject


@property (nonatomic, copy, readonly) NSString *name;

/** <#注释#> */
@property (nonatomic, weak) id<YZHKVDelegate> delegate;

//提供了一个全局单利，也可以自己申请
+ (instancetype)defaultKV;

- (instancetype)initWithName:(NSString*)name path:(NSString*)path;

- (instancetype)initWithName:(NSString *)name path:(NSString *)path cryptKey:(NSData *)cryptKey;

- (BOOL)setObject:(id)object forKey:(id)key;

- (BOOL)setObject:(id)object topEdgeSuperClass:(Class)topEdgeSuperClass forKey:(id)key;

- (BOOL)setFloat:(float)val forKey:(id)key;

- (BOOL)setDouble:(double)val forKey:(id)key;

- (BOOL)setInteger:(int64_t)val forKey:(id)key;

- (BOOL)setBool:(BOOL)val forKey:(id)key;

- (BOOL)setInt8:(int8_t)val forKey:(id)key;

- (BOOL)setUInt8:(uint8_t)val forKey:(id)key;

- (BOOL)setInt16:(int16_t)val forKey:(id)key;

- (BOOL)setUInt16:(uint16_t)val forKey:(id)key;

- (BOOL)setInt32:(int32_t)val forKey:(id)key;

- (BOOL)setUInt32:(uint32_t)val forKey:(id)key;

- (BOOL)setInt64:(int64_t)val forKey:(id)key;

- (BOOL)setUInt64:(uint64_t)val forKey:(id)key;

- (id)getObjectForKey:(id)key;

- (BOOL)getBoolForKey:(id)key;

- (int8_t)getInt8ForKey:(id)key;

- (uint8_t)getUInt8ForKey:(id)key;

- (int16_t)getInt16ForKey:(id)key;

- (uint16_t)getUInt16ForKey:(id)key;

- (int32_t)getInt32ForKey:(id)key;

- (uint32_t)getUInt32ForKey:(id)key;

- (int64_t)getInt64ForKey:(id)key;

- (uint64_t)getUInt64ForKey:(id)key;

- (float)getFloatForKey:(id)key;

- (double)getDoubleForKey:(id)key;

- (NSDictionary*)allEntries;

- (void)removeObjectForKey:(id)key;

- (void)clear;

- (void)close;

- (NSError*)lastError;

- (void)updateCryptKey:(NSData*)cryptKey;



@end


