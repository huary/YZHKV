//
//  NSObject+YZHCodeToTopSuperClass.h
//  YZHKVDemo
//
//  Created by yuan on 2019/9/10.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YZHCodeObjectProtocol <NSObject>


+(NSArray<NSString*>*)hz_objectCodeKeyPaths;

+(Class)hz_objectCodeToTopSuperClass;

@end


@interface NSObject (YZHCodeToTopSuperClass)

-(Class)hz_codeToTopSuperClass;

@end

NS_ASSUME_NONNULL_END
