//
//  YZHCFKV.h
//  YZHKVDemo
//
//  Created by yuan on 2019/9/8.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YZHCoder.h"
#include <string>
using namespace std;

typedef NS_ENUM(int32_t, YZHCFKVError)
{
    YZHCFKVErrorNone              = 0,
    //密码错误
    YZHCFKVErrorCryptKeyError     = 1,
    //编码错误
    YZHCFKVErrorCoderError        = 2,
    //CRC不一样错误,这是一个warning
    YZHCFKVErrorCRCError          = 3,
};

class YZHCFKV;
class YZHCFKVDelegateInterface {
public:
    virtual void notifyError(YZHCFKV *CFKV, YZHCFKVError error) = 0;
    
    virtual BOOL notifyWarning(YZHCFKV *CFKV, YZHCFKVError error) = 0;
};



class YZHCFKV {
private:
    void *ptrCFKVContext;
    string name;
    
    string path;
    
    void setupCFKVDefault();
    
public:
    YZHCFKV();

    YZHCFKV(const string &name);

    YZHCFKV(const string &name, const string &path);
    
    YZHCFKV(const string &name, const string &path, YZHCodeData *cryptKey);
    
    virtual ~YZHCFKV();
    
    string getFilePath();
    
    BOOL updateCryptKey(YZHCodeData *cryptKey);
    
    
    /**
     设置以Key作为键，以Object作为值

     @param object 作为值，在object为nil是removeObjectForKey的操作
     @param key 作为键，不可为空
     @return 返回是否成功，YES-成功，NO-失败
     */
    BOOL setObjectForKey(id object, id key);
    
    
    /**
     设置以Key作为键，以Object作为值

     @param object 作为值，在object为nil是removeObjectForKey的操作
     @param topSuperClass object编码到父类的类名
     @param key key 作为键，不可为空
     @return 返回是否成功，YES-成功，NO-失败
     */
    BOOL setObjectForKey(id object, Class topSuperClass, id key);
    
    BOOL setFloatForKey(float val, id key);
    
    BOOL setDoubleForKey(double val, id key);
    
    BOOL setIntegerForKey(int64_t val, id key);
    
    id getObjectForKey(id key);
    
    float getFloatForKey(id key);
    
    double getDoubleForKey(id key);
    
    int64_t getIntegerForKey(id key);
    
    NSDictionary *getAllEntries();
    
    void removeObjectForKey(id key);
    
    YZHCFKVError getLastError();

    void clear(BOOL truncateFileSize);
    
    void close();
    
public:
//    weak_ptr<YZHCFKVDelegateInterface> delegate;
    YZHCFKVDelegateInterface *delegate;
};
