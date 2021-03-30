//
//  YZHCFKVDelegate.m
//  YZHKVDemo
//
//  Created by yuan on 2019/9/11.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHCFKVDelegate.h"


YZHCFKVDelegate::YZHCFKVDelegate(YZHKV *KVTarget)
{
    _KVTarget = KVTarget;
}

YZHCFKVDelegate::~YZHCFKVDelegate()
{
    
}

void YZHCFKVDelegate::notifyError(YZHCFKV *CFKV, YZHCFKVError error)
{
    if ([_KVTarget.delegate respondsToSelector:@selector(kv:reportError:)]) {
        NSError *err = [NSError errorWithDomain:_KVErrorDomain code:error userInfo:NULL];
        [_KVTarget.delegate kv:_KVTarget reportError:err];
    }
}

BOOL YZHCFKVDelegate::notifyWarning(YZHCFKV *CFKV, YZHCFKVError error)
{
    if ([_KVTarget.delegate respondsToSelector:@selector(kv:reportWarning:)]) {
        NSError *err = [NSError errorWithDomain:_KVErrorDomain code:error userInfo:NULL];
        return [_KVTarget.delegate kv:_KVTarget reportWarning:err];
    }
    return YES;
}
