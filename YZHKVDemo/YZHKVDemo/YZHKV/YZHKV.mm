//
//  YZHKV.m
//  YZHKVDemo
//
//  Created by yuan on 2019/6/30.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHKV.h"
#import "YZHCFKV.h"
#import "YZHCoder.h"
#import "YZHCFKVDelegate.h"
#import "YZHMachTimeUtils.h"

#define DEFAULT_YZHKV_NAME              @"yzh.kv.default"

NSString *const _YZHKVErrorDomain = @"YZHKVErrorDomain";

@interface YZHKV ()
{
    shared_ptr<YZHCFKV> _sharedPtrCFKV;
    shared_ptr<YZHCFKVDelegate> _sharedPtrDelegate;
}

@end

@implementation YZHKV
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
        name = name ? : DEFAULT_YZHKV_NAME;
        path = path ? : @"";
        
        YZHCodeData cryptKeyData(cryptKey);
        
//        [YZHMachTimeUtils recordPointWithText:@"创建CFKV"];
        _sharedPtrCFKV = make_shared<YZHCFKV>(name.UTF8String, path.UTF8String, &cryptKeyData);
//        [YZHMachTimeUtils recordPointWithText:@"创建CFKV"];
        
        _sharedPtrDelegate = make_shared<YZHCFKVDelegate>(self);
        
        _sharedPtrDelegate->_KVErrorDomain = _YZHKVErrorDomain;
        
        _sharedPtrCFKV->delegate = _sharedPtrDelegate.get();
    }
    return self;
}


- (BOOL)setObject:(id)object forKey:(id)key
{
    return _sharedPtrCFKV->setObjectForKey(object, key);
}

- (BOOL)setObject:(id)object topSuperClass:(Class)topSuperClass forKey:(id)key
{
    return _sharedPtrCFKV->setObjectForKey(object, topSuperClass, key);
}

- (BOOL)setFloat:(float)val forKey:(id)key
{
    return _sharedPtrCFKV->setFloatForKey(val, key);
}

- (BOOL)setDouble:(double)val forKey:(id)key
{
    return _sharedPtrCFKV->setDoubleForKey(val, key);
}

- (BOOL)setInteger:(int64_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setBool:(BOOL)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setInt8:(int8_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setUInt8:(uint8_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setInt16:(int16_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setUInt16:(uint16_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setInt32:(int32_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setUInt32:(uint32_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setInt64:(int64_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (BOOL)setUInt64:(uint64_t)val forKey:(id)key
{
    return _sharedPtrCFKV->setIntegerForKey(val, key);
}

- (id)getObjectForKey:(id)key
{
    return _sharedPtrCFKV->getObjectForKey(key);
}

- (BOOL)getBoolForKey:(id)key
{
    return _sharedPtrCFKV->getIntegerForKey(key);
}

- (int8_t)getInt8ForKey:(id)key
{
    int64_t val = _sharedPtrCFKV->getIntegerForKey(key);
    return TYPE_AND(val, 0XFF);
}

- (uint8_t)getUInt8ForKey:(id)key
{
    int64_t val = _sharedPtrCFKV->getIntegerForKey(key);
    return TYPE_AND(val, 0XFF);
}

- (int16_t)getInt16ForKey:(id)key
{
    int64_t val = _sharedPtrCFKV->getIntegerForKey(key);
    return TYPE_AND(val, 0XFFFF);
}

- (uint16_t)getUInt16ForKey:(id)key
{
    int64_t val = _sharedPtrCFKV->getIntegerForKey(key);
    return TYPE_AND(val, 0XFFFF);
}

- (int32_t)getInt32ForKey:(id)key
{
    int64_t val = _sharedPtrCFKV->getIntegerForKey(key);
    return TYPE_AND(val, 0XFFFFFFFF);
}

- (uint32_t)getUInt32ForKey:(id)key
{
    int64_t val = _sharedPtrCFKV->getIntegerForKey(key);
    return TYPE_AND(val, 0XFFFFFFFF);
}

- (int64_t)getInt64ForKey:(id)key
{
    return _sharedPtrCFKV->getIntegerForKey(key);
}

- (uint64_t)getUInt64ForKey:(id)key
{
    return _sharedPtrCFKV->getIntegerForKey(key);
}

- (float)getFloatForKey:(id)key
{
    return _sharedPtrCFKV->getFloatForKey(key);
}

- (double)getDoubleForKey:(id)key
{
    return _sharedPtrCFKV->getDoubleForKey(key);
}

- (int64_t)getIntegerForKey:(id)key
{
    return _sharedPtrCFKV->getIntegerForKey(key);
}

- (NSDictionary*)allEntries
{
    return _sharedPtrCFKV->getAllEntries();
}

- (void)removeObjectForKey:(id)key
{
    _sharedPtrCFKV->removeObjectForKey(key);
}

- (void)updateCryptKey:(NSData*)cryptKey
{
    YZHCodeData cryptKeyCodeData(cryptKey);
    _sharedPtrCFKV->updateCryptKey(&cryptKeyCodeData);
}

- (NSError*)lastError
{
    if (_sharedPtrCFKV.get()) {
        YZHCFKVError errorCode = _sharedPtrCFKV->getLastError();
        if (errorCode) {
            NSError *err = [NSError errorWithDomain:_YZHKVErrorDomain code:errorCode userInfo:NULL];
            return err;
        }
    }
    return nil;
}

- (void)clear:(BOOL)truncateFileSize
{
    _sharedPtrCFKV->clear(truncateFileSize);
}

- (void)close
{
    _sharedPtrCFKV->close();
}


- (void)dealloc
{
    _sharedPtrCFKV.reset();
    _sharedPtrDelegate.reset();
    
    NSLog(@"YZHKV---------dealloc");
}

//#if DEBUG
- (NSString*)filePath
{
    string filePath = _sharedPtrCFKV->getFilePath();
    return [[NSString alloc] initWithUTF8String:filePath.c_str()];
}
//#endif

@end
