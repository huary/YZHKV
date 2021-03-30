//
//  YZHCodeData.m
//  YZHKVDemo
//
//  Created by yuan on 2019/9/10.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "YZHCodeData.h"

static const int32_t expandBufferSize_s = 4096;

YZHCodeData::YZHCodeData(NSData *data) : _ptr((uint8_t*)data.bytes), _size(data.length)
{
    _length = _size;
    _position = 0;
}

YZHCodeData::YZHCodeData(uint8_t *ptr, int64_t size) : _ptr(ptr), _size(size)
{
    _length = 0;
    _position = 0;
}

YZHCodeData::~YZHCodeData()
{
//    NSLog(@"YZHCodeData destructor");
    _ptr = nullptr;
    _size = 0;
    _length = 0;
    _position = 0;
}

void YZHCodeData::writeData(NSData *data)
{
    if (data == nil || data.length == 0) {
        return;
    }
    this->writeBuffer((uint8_t *)data.bytes, (int64_t)data.length);
}

void YZHCodeData::writeCodeData(YZHCodeData *codeData)
{
    this->writeBuffer(codeData->_ptr, codeData->_length);
}

void YZHCodeData::writeBuffer(uint8_t *ptr, int64_t size)
{
    if (_ptr == NULL || ptr == NULL || size <= 0) {
        return;
    }
    if (_position + size > _size) {
        return;
    }
//    memcpy(_ptr + _position, ptr, size);
    memmove(_ptr + _position, ptr, (size_t)size);
    _position += size;
    _length = MAX(_length, _position);
}

void YZHCodeData::writeByte(uint8_t value)
{
    if (_ptr == NULL || _position + 1 > _size) {
        return;
    }
    _ptr[_position] = value;
    ++_position;
    _length = MAX(_length, _position);
}

void YZHCodeData::writeLittleEndian16(uint16_t value)
{
    writeByte(value & 0XFF);
    writeByte((value >> 8) & 0XFF);
}

void YZHCodeData::writeLittleEndian32(uint32_t value)
{
    writeByte(value & 0XFF);
    writeByte((value >> 8) & 0XFF);
    writeByte((value >> 16) & 0XFF);
    writeByte((value >> 24) & 0XFF);
}

void YZHCodeData::writeLittleEndian64(uint64_t value)
{
    writeByte(value & 0XFF);
    writeByte((value >> 8) & 0XFF);
    writeByte((value >> 16) & 0XFF);
    writeByte((value >> 24) & 0XFF);
    writeByte((value >> 32) & 0XFF);
    writeByte((value >> 40) & 0XFF);
    writeByte((value >> 48) & 0XFF);
    writeByte((value >> 56) & 0XFF);
}

uint8_t YZHCodeData::readByte()
{
    if (_ptr == NULL || _position == _size) {
        return 0;
    }
    uint8_t value = _ptr[_position];
    ++_position;
    return value;
}

uint16_t YZHCodeData::readLittleEndian16()
{
    uint16_t a = readByte();
    uint16_t b = readByte();
    uint16_t value = (a | (b << 8));
    return value;
}

uint32_t YZHCodeData::readLittleEndian32()
{
    uint32_t a = readByte();
    uint32_t b = readByte();
    uint32_t c = readByte();
    uint32_t d = readByte();
    uint32_t value = (a | (b << 8) | (c << 16) | ( d << 24));
    return value;
}

uint64_t YZHCodeData::readLittleEndian64()
{
    uint64_t a = readByte();
    uint64_t b = readByte();
    uint64_t c = readByte();
    uint64_t d = readByte();
    
    uint64_t e = readByte();
    uint64_t f = readByte();
    uint64_t g = readByte();
    uint64_t h = readByte();
    uint64_t value = (a | (b << 8) | (c << 16) | ( d << 24) | (e << 32) | (f << 40) | (g << 48) | (h << 56));
    return value;
}

NSData* YZHCodeData::readBuffer(int64_t size)
{
    if (_ptr == NULL || size <= 0) {
        return nil;
    }
    if (_position + size > _size) {
        return nil;
    }
    NSData *data = [NSMutableData dataWithLength:(NSUInteger)size];
    memcpy((uint8_t*)data.bytes, _ptr, (size_t)size);
    _position += size;
    return [data copy];
}

void YZHCodeData::read(uint8_t *ptr, int64_t size)
{
    if (_ptr == NULL || size <= 0 || ptr == NULL) {
        return;
    }
    if (_position + size > _size) {
        return;
    }
    memmove(ptr, _ptr + _position, (size_t)size);
    _position += size;
}

int64_t YZHCodeData::seek(YZHDataSeekType seekType)
{
    int64_t pos = _position;
    switch (seekType) {
        case YZHDataSeekTypeSET: {
            pos = 0;
            break;
        }
        case YZHDataSeekTypeCUR: {
            break;
        }
        case YZHDataSeekTypeEND: {
            pos = _length;
            break;
        }
        default:
            break;
    }
    return seekTo(pos);
}

int64_t YZHCodeData::seekTo(int64_t to)
{
    if (_ptr == NULL || to < 0 || to > _size) {
        return 0;
    }
    _position = to;
    if (to > _length) {
        _length = to;
    }
    return _position;
}

int64_t YZHCodeData::currentSeek()
{
    return _position;
}

int64_t YZHCodeData::bufferSize()
{
    return _size;
}

int64_t YZHCodeData::dataSize()
{
    return _length;
}

int64_t YZHCodeData::remSize()
{
    return _size - _length;
}

void YZHCodeData::bzero()
{
    if (_ptr == NULL) {
        return;
    }
    memset(_ptr, 0, (size_t)_size);
    _length = 0;
    _position = 0;
}

/*
 *truncate不把内容置零
 */
BOOL YZHCodeData::truncateTo(int64_t size)
{
    if (size > _size || size < 0) {
        return NO;
    }

    _length = size;
    _position = MIN(_position, _length);

    return YES;
}

BOOL YZHCodeData::truncateTo(int64_t size, uint8_t setval)
{
    if (size > _size || size < 0) {
        return NO;
    }
    
    int64_t differ = size - _length;
    
    _length = size;
    _position = MIN(_position, _length);
    
    if (differ) {
        if (differ > 0) {
            memset(_ptr + size - differ, setval, (size_t)differ);
        }
        else {
            differ = _size - size;//-differ;
            memset(_ptr + size, setval, (size_t)differ);
        }
    }
    
    return YES;
}

/*
 *truncate不把内容置零,并且最大seek到size,为YZHDataSeekTypeCUR时同truncateTo(int64_t size)
 */
BOOL YZHCodeData::truncateToWithSeek(int64_t size, YZHDataSeekType seekType)
{
    if (size > _size || size < 0) {
        return NO;
    }
    
    _length = size;
    switch (seekType) {
        case YZHDataSeekTypeSET: {
            _position = 0;
            break;
        }
        case YZHDataSeekTypeCUR: {
            _position = MIN(_position, _length);
        }
        case YZHDataSeekTypeEND: {
            _position = _length;
            break;
        }
        default:
            break;
    }
    return YES;
}

uint8_t* YZHCodeData::bytes()
{
    return _ptr;
}

NSData* YZHCodeData::data()
{
    if (_ptr == NULL) {
        return nil;
    }
    NSData *data = [NSData dataWithBytesNoCopy:_ptr length:(NSUInteger)_length freeWhenDone:NO];
    return data;
}

NSData* YZHCodeData::copyData()
{
    if (_ptr == NULL) {
        return nil;
    }
    NSData *data = [NSData dataWithBytes:_ptr length:(NSUInteger)_length];
    return data;
}

void YZHCodeData::print()
{
    NSLog(@"_size=%lld,_length=%lld,_pos=%lld",_size,_length,_position);
}



YZHMutableCodeData::YZHMutableCodeData() : YZHCodeData(nil)
{
    _size = expandBufferSize_s;
    _ptr = (uint8_t*)calloc((size_t)_size, sizeof(uint8_t));
}

YZHMutableCodeData::YZHMutableCodeData(int64_t size) : YZHCodeData(nil)
{
    _size = size > 0 ? size : expandBufferSize_s;
    _ptr = (uint8_t*)calloc((size_t)_size, sizeof(uint8_t));
}

YZHMutableCodeData::YZHMutableCodeData(NSData *data) : YZHCodeData(nil)
{
    _size = data.length;
    if (_size <= 0) {
        _size = expandBufferSize_s;
    }
    _ptr = (uint8_t*)calloc((size_t)_size, sizeof(uint8_t));
    if (_ptr && data.bytes) {
        memcpy(_ptr, (uint8_t*)data.bytes, (size_t)_size);
        seekTo(_size);
    }
}

YZHMutableCodeData::YZHMutableCodeData(YZHCodeData *codeData) : YZHCodeData(nil)
{
    int64_t dataSize = codeData->dataSize();
    _size = dataSize;
    if (_size <= 0) {
        _size = expandBufferSize_s;
    }
    _ptr = (uint8_t*)calloc((size_t)_size, sizeof(uint8_t));
    if (_ptr && codeData->bytes()) {
        memcpy(_ptr, (uint8_t*)codeData->bytes(), (size_t)dataSize);
        seekTo(_size);
    }
}

YZHMutableCodeData::~YZHMutableCodeData()
{
//    NSLog(@"YZHMutableCodeData destructor");
    if (_ptr) {
        free(_ptr);
        _ptr = NULL;
    }
    _size = 0;
}

BOOL YZHMutableCodeData::ensureRemSize(int64_t remSize)
{
    int64_t leftSize = YZHCodeData::remSize();
    if (leftSize > remSize) {
        return YES;
    }
    int64_t extra = MAX(remSize, expandBufferSize_s);
    return increaseBufferSizeBy(extra);
}

BOOL YZHMutableCodeData::increaseBufferSizeBy(int64_t increaseSize)
{
    int64_t total = _size + increaseSize;
    uint8_t *ptr = (uint8_t*)realloc(_ptr, (size_t)(total * sizeof(uint8_t)));
    if (ptr == NULL) {
        return NO;
    }
    _ptr = ptr;
    _size = total;
    return YES;
}

void YZHMutableCodeData::appendWriteData(NSData *data)
{
    appendWriteBuffer((uint8_t*)data.bytes, data.length);
}

void YZHMutableCodeData::appendWriteBuffer(uint8_t *ptr, int64_t size)
{
    int64_t rem = YZHCodeData::remSize();
    int64_t diff = rem - size;
    if (diff < 0) {
        int64_t s = (int64_t)MAX(_size, expandBufferSize_s);
        increaseBufferSizeBy(s);
    }
    writeBuffer(ptr,size);
}

void YZHMutableCodeData::appendWriteByte(uint8_t value)
{
    int64_t rem = YZHCodeData::remSize();
    int64_t diff = rem - 1;
    if (diff < 0) {
        int64_t s = (int64_t)MAX(_size, expandBufferSize_s);
        increaseBufferSizeBy(s);
    }
    writeByte(value);
}

NSMutableData* YZHMutableCodeData::mutableData()
{
    if (_ptr == NULL) {
        return nil;
    }
    return [NSMutableData dataWithBytesNoCopy:_ptr length:(NSUInteger)this->dataSize() freeWhenDone:NO];
}

NSMutableData* YZHMutableCodeData::mutableCopyData()
{
    if (_ptr == NULL) {
        return nil;
    }
    return [NSMutableData dataWithBytes:_ptr length:(NSUInteger)this->dataSize()];
}
