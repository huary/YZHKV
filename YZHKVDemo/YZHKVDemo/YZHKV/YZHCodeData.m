//
//  YZHCodeData.m
//  YZHMMKVDemo
//
//  Created by yuan on 2019/6/30.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHCodeData.h"
#import <string.h>

static const int32_t expandBufferSize_s = 4096;

@interface YZHCodeData ()
{
@public
    uint8_t *_ptr;
    //空间大小
    int64_t _size;
    //写入数据的长度或者是seekTo的位置（有条件）
    int64_t _length;
    //写入数据的位置
    int64_t _position;
}

@end

@implementation YZHCodeData

-(instancetype)init
{
    self = [super init];
    if (self) {
        [self _setupDefault];
    }
    return self;
}

-(void)_setupDefault
{
    self->_ptr = NULL;
    self->_size = 0;
    self->_length = 0;
    self->_position = 0;
}

-(instancetype)initWithData:(NSData*)data
{
    self = [self init];
    if (self) {
        self->_ptr = (uint8_t*)data.bytes;
        self->_size = data.length;
        self->_length = self->_size;
    }
    return self;
}

-(instancetype)initWithBuffer:(uint8_t*)ptr size:(int64_t)size
{
    self = [self init];
    if (self) {
        self->_ptr = ptr;
        self->_size = size;
    }
    return self;
}

-(void)writeData:(NSData*)data
{
    if (data == nil || data.length == 0) {
        return;
    }
    [self writeBuffer:(uint8_t*)data.bytes size:data.length];
}

-(void)writeCodeData:(YZHCodeData*)codeData
{
    [self writeBuffer:codeData->_ptr size:codeData->_length];
}

-(void)writeBuffer:(uint8_t*)ptr size:(int64_t)size
{
    if (_ptr == NULL || ptr == NULL || size <= 0) {
        return;
    }
    if (_position + size > _size) {
        return;
    }
    memcpy(_ptr + _position, ptr, size);
//    memmove(_ptr + _position, ptr, size);
    _position += size;
    _length = _position;
}

-(void)writeByte:(uint8_t)value
{
    if (self->_ptr == NULL || self->_position + 1 > self->_size) {
        return;
    }
    self->_ptr[self->_position++] = value;
    self->_length = self->_position;
}

-(void)writeLittleEndian16:(uint16_t)value
{
    [self writeByte:value & 0XFF];
    [self writeByte:(value >> 8) & 0XFF];
}

-(void)writeLittleEndian32:(uint32_t)value
{
    [self writeByte:value & 0XFF];
    [self writeByte:(value >> 8) & 0XFF];
    [self writeByte:(value >> 16) & 0XFF];
    [self writeByte:(value >> 24) & 0XFF];
}

-(void)writeLittleEndian64:(uint64_t)value
{
    [self writeByte:value & 0XFF];
    [self writeByte:(value >> 8) & 0XFF];
    [self writeByte:(value >> 16) & 0XFF];
    [self writeByte:(value >> 24) & 0XFF];
    [self writeByte:(value >> 32) & 0XFF];
    [self writeByte:(value >> 40) & 0XFF];
    [self writeByte:(value >> 48) & 0XFF];
    [self writeByte:(value >> 56) & 0XFF];
}

-(uint8_t)readByte
{
    if (self->_ptr == NULL || self->_position == self->_size) {
        return 0;
    }
    uint8_t value = self->_ptr[self->_position++];
    return value;
}

-(uint16_t)readLittleEndian16
{
    uint16_t a = [self readByte];
    uint16_t b = [self readByte];
    uint16_t value = (a | (b << 8));
    return value;
}

-(uint32_t)readLittleEndian32
{
    uint32_t a = [self readByte];
    uint32_t b = [self readByte];
    uint32_t c = [self readByte];
    uint32_t d = [self readByte];
    uint32_t value = (a | (b << 8) | (c << 16) | ( d << 24));
    return value;
}

-(uint64_t)readLittleEndian64
{
    uint64_t a = [self readByte];
    uint64_t b = [self readByte];
    uint64_t c = [self readByte];
    uint64_t d = [self readByte];
    
    uint64_t e = [self readByte];
    uint64_t f = [self readByte];
    uint64_t g = [self readByte];
    uint64_t h = [self readByte];
    uint64_t value = (a | (b << 8) | (c << 16) | ( d << 24) | (e << 32) | (f << 40) | (g << 48) | (h << 56));
    return value;
}

-(NSData*)readBuffer:(int64_t)size
{
    if (self->_ptr == NULL || size <= 0) {
        return nil;
    }
    if (self->_position + size > self->_size) {
        return nil;
    }
    NSData *data = [NSMutableData dataWithLength:(NSUInteger)size];
    memcpy((uint8_t*)data.bytes, self->_ptr, size);
    self->_position += size;
    return [data copy];
}

-(void)read:(uint8_t*)buffer size:(int64_t)size
{
    if (self->_ptr == NULL || size <= 0 || buffer == NULL) {
        return;
    }
    if (self->_position + size > self->_size) {
        return;
    }
    memcpy(buffer, self->_ptr + self->_position, size);
    self->_position += size;
}

-(int64_t)seek:(YZHDataSeekType)seekType
{
    int64_t pos = self->_position;
    switch (seekType) {
        case YZHDataSeekTypeSET: {
            pos = 0;
            break;
        }
        case YZHDataSeekTypeCUR: {
            break;
        }
        case YZHDataSeekTypeEND: {
            pos = self->_length;
            break;
        }
        default:
            break;
    }
    return [self seekTo:pos];
}

-(int64_t)seekTo:(int64_t)to
{
    if (self->_ptr == NULL || to < 0 || to > self->_size) {
        return 0;
    }
    self->_position = to;
    if (to > self->_length) {
        self->_length = to;
    }
    return self->_position;
}

-(int64_t)currentSeek
{
    return self->_position;
}

-(int64_t)dataSize
{
    return self->_length;
}

-(int64_t)remSize
{
    return self->_size - self->_length;
}

-(void)bzero
{
    if (self->_ptr == NULL) {
        return;
    }
    memset(self->_ptr, 0, self->_size);
    self->_length = 0;
    self->_position = 0;
}

-(BOOL)truncateTo:(int64_t)size
{
    if (size > _size || size < 0) {
        return NO;
    }
    self->_position = size;
    self->_length = size;
    return YES;
}

- (uint8_t*)bytes
{
    return self->_ptr;
}

//- (uint8_t*)offset:(YZHDataSeekType)seekType
//{
//    int64_t pos = self->_position;
//    switch (seekType) {
//        case YZHDataSeekTypeSET: {
//            pos = 0;
//            break;
//        }
//        case YZHDataSeekTypeCUR: {
//            break;
//        }
//        case YZHDataSeekTypeEND: {
//            pos = self->_length;
//            break;
//        }
//        default:
//            break;
//    }
//    return [self offsetTo:pos];
//}
//
//- (uint8_t*)offsetTo:(int64_t)offset
//{
//    return self->_ptr + offset;
//}

- (NSData*)data
{
    if (self->_ptr == NULL) {
        return nil;
    }
    NSData *data = [NSData dataWithBytesNoCopy:self->_ptr length:(NSUInteger)self->_length freeWhenDone:NO];
    return data;
}

- (NSData*)copyData
{
    if (self->_ptr == NULL) {
        return nil;
    }
    NSData *data = [NSData dataWithBytes:self->_ptr length:(NSUInteger)self->_length];
    return data;
}

//- (NSData *)subCopyDataFromOffset:(int64_t)offset
//{
//    if (self->_ptr == NULL || offset < 0 || offset >= self->_length) {
//        return nil;
//    }
//    int64_t length = self->_length - offset;
//    NSData *data = [NSData dataWithBytes:self->_ptr + offset length:(NSUInteger)length];
//    return data;
//}

//-(BOOL)isSame:(YZHCodeData*)codeData
//{
//    if (self->_ptr == NULL || codeData->_ptr == NULL) {
//        return NO;
//    }
//    if (self->_size != codeData->_size) {
//        return NO;
//    }
//    
//    return (memcmp(self->_ptr, codeData->_ptr, self->_size) == 0);
//}

@end





/**********************************************************************
 *<#desc#>
 ***********************************************************************/
@interface YZHMutableCodeData ()


@end

@implementation YZHMutableCodeData

- (instancetype)init
{
    self = [super init];
    if (self) {
        self->_size = expandBufferSize_s;
        self->_ptr = calloc((size_t)self->_size, sizeof(uint8_t));
    }
    return self;
}

- (instancetype)initWithSize:(int64_t)size
{
    self = [super init];
    if (self) {
//        if (self->_ptr) {
//            free(self->_ptr);
//            self->_ptr = NULL;
//        }
        self->_size = size > 0 ? size : expandBufferSize_s;
        self->_ptr = calloc((size_t)self->_size, sizeof(uint8_t));
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
//        if (self->_ptr) {
//            free(self->_ptr);
//            self->_ptr = NULL;
//        }
        self->_size = data.length;
        self->_ptr = calloc((size_t)self->_size, sizeof(uint8_t));
        memcpy(self->_ptr, (uint8_t*)data.bytes, self->_size);
    }
    return self;
}

- (BOOL)ensureRemSize:(int64_t)remSize
{
    int64_t leftSize = [self remSize];
    if (leftSize > remSize) {
        return YES;
    }
    int64_t extra = MAX(remSize, expandBufferSize_s);
    return [self increaseLengthBy:extra];
}

- (BOOL)increaseLengthBy:(int64_t)extraLength
{
    int64_t total = self->_size + extraLength;
    uint8_t *ptr = (uint8_t*)realloc(self->_ptr, (size_t)(total * sizeof(uint8_t)));
    if (ptr == NULL) {
        return NO;
    }
    self->_ptr = ptr;
    self->_size = total;
    return YES;
}

- (void)appendWriteData:(NSData *)data
{
    [self appendWriteBuffer:(uint8_t*)data.bytes size:data.length];
}

- (void)appendWriteBuffer:(uint8_t*)ptr size:(int64_t)size
{
    int64_t rem = [self remSize];
    int64_t diff = rem - size;
    if (diff < 0) {
        int64_t s = MAX(self->_size, expandBufferSize_s);
        [self increaseLengthBy:s];
    }
    [self writeBuffer:ptr size:size];
}

- (void)appendWriteByte:(uint8_t)value
{
    int64_t rem = [self remSize];
    int64_t diff = rem - 1;
    if (diff < 0) {
        int64_t s = MAX(self->_size, expandBufferSize_s);
        [self increaseLengthBy:s];
    }
    [self writeByte:value];
}

- (NSMutableData*)mutableData
{
    if (self->_ptr == NULL) {
        return nil;
    }
    return [NSMutableData dataWithBytesNoCopy:self->_ptr length:self->_length freeWhenDone:NO];
}

- (NSMutableData*)mutableCopyData
{
    if (self->_ptr == NULL) {
        return nil;
    }
    return [NSMutableData dataWithBytes:self->_ptr length:(NSUInteger)self->_length];
}

- (void)dealloc
{
    if (self->_ptr) {
        free(self->_ptr);
        self->_ptr = NULL;
    }
    self->_size = 0;
    self->_length = 0;
    self->_position = 0;
}
@end
