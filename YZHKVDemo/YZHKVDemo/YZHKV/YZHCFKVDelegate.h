//
//  YZHCFKVDelegate.h
//  YZHKVDemo
//
//  Created by yuan on 2019/9/11.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YZHCFKV.h"
#import "YZHKV.h"


class YZHCFKVDelegate : public YZHCFKVDelegateInterface {
private:
    __weak YZHKV *_KVTarget;
public:
    YZHCFKVDelegate(YZHKV *KVTarget);
    
    virtual ~YZHCFKVDelegate();
    
    void notifyError(YZHCFKV *CFKV, YZHCFKVError error);
    
    BOOL notifyWarning(YZHCFKV *CFKV, YZHCFKVError error);

    NSString *_KVErrorDomain;
};
