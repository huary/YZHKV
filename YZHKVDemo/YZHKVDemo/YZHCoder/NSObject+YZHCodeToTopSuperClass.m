//
//  NSObject+YZHCodeToTopSuperClass.m
//  YZHKVDemo
//
//  Created by yuan on 2019/9/10.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "NSObject+YZHCodeToTopSuperClass.h"
#import <objc/runTime.h>

@implementation NSObject (YZHCodeToTopSuperClass)

-(Class)hz_codeToTopSuperClass
{
    Class objCls = object_getClass(self);
    if ([objCls respondsToSelector:@selector(hz_objectCodeToTopSuperClass)]) {
        return [objCls hz_objectCodeToTopSuperClass];
    }
    return nil;
}

@end
