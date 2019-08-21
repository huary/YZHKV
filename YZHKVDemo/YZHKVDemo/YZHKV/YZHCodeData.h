//
//  YZHCodeData.h
//  YZHMMKVDemo
//
//  Created by yuan on 2019/6/30.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YZHDataSeekType)
{
    YZHDataSeekTypeSET  = 0,
    YZHDataSeekTypeCUR  = 1,
    YZHDataSeekTypeEND  = 2,
};

@interface YZHCodeData : NSObject

-(instancetype)initWithData:(NSData*)data;

-(instancetype)initWithBuffer:(uint8_t*)ptr size:(int64_t)size;

-(void)writeData:(NSData*)data;

-(void)writeCodeData:(YZHCodeData*)codeData;

-(void)writeBuffer:(uint8_t*)ptr size:(int64_t)size;

-(void)writeByte:(uint8_t)value;

-(void)writeLittleEndian16:(uint16_t)value;

-(void)writeLittleEndian32:(uint32_t)value;

-(void)writeLittleEndian64:(uint64_t)value;

-(uint8_t)readByte;

-(uint16_t)readLittleEndian16;

-(uint32_t)readLittleEndian32;

-(uint64_t)readLittleEndian64;

-(NSData*)readBuffer:(int64_t)size;

-(void)read:(uint8_t*)buffer size:(int64_t)size;

-(int64_t)seek:(YZHDataSeekType)seekType;

-(int64_t)seekTo:(int64_t)to;

-(int64_t)currentSeek;

-(int64_t)dataSize;

-(int64_t)remSize;

-(void)bzero;

//truncate不把内容置零
-(BOOL)truncateTo:(int64_t)size;

- (uint8_t*)bytes;

//- (uint8_t*)offset:(YZHDataSeekType)seekType;
//
//- (uint8_t*)offsetTo:(int64_t)offset;

- (NSData*)data;

- (NSData*)copyData;

- (NSData *)subCopyDataFromOffset:(int64_t)offset;

//-(BOOL)isSame:(YZHCodeData*)codeData;

@end




/**********************************************************************
 *YZHMutableCodeData
 ***********************************************************************/
@interface YZHMutableCodeData : YZHCodeData

- (instancetype)initWithSize:(int64_t)size;

- (instancetype)initWithData:(NSData *)data;

- (BOOL)ensureRemSize:(int64_t)remSize;

- (BOOL)increaseLengthBy:(int64_t)extraLength;

//下面在长度不足时会进行increase
- (void)appendWriteData:(NSData *)data;

- (void)appendWriteBuffer:(uint8_t*)ptr size:(int64_t)size;

- (void)appendWriteByte:(uint8_t)value;

- (NSMutableData*)mutableData;

- (NSMutableData*)mutableCopyData;

@end


NS_ASSUME_NONNULL_END
