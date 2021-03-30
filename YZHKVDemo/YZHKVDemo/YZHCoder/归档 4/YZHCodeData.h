//
//  YZHCodeData.h
//  YZHKVDemo
//
//  Created by yuan on 2019/9/6.
//  Copyright © 2019 yuan. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus

typedef NS_ENUM(NSInteger, YZHDataSeekType)
{
    YZHDataSeekTypeSET  = 0,
    YZHDataSeekTypeCUR  = 1,
    YZHDataSeekTypeEND  = 2,
};

class YZHCodeData {
    
protected:
    uint8_t *_ptr;
    //空间大小
    int64_t _size;
private:
    //写入数据的长度或者是seekTo的位置（有条件）
    int64_t _length;
    //写入数据的位置
    int64_t _position;

public:
    YZHCodeData(NSData *data);
    
//    YZHCodeData(YZHCodeData *data);
    
    YZHCodeData(uint8_t *ptr, int64_t size);
    
    virtual ~YZHCodeData();
    
    void writeData(NSData *data);
    
    void writeCodeData(YZHCodeData *codeData);
    
    void writeBuffer(uint8_t *ptr, int64_t size);
    
    void writeByte(uint8_t value);
    
    void writeLittleEndian16(uint16_t value);
    
    void writeLittleEndian32(uint32_t value);
    
    void writeLittleEndian64(uint64_t value);
    
    uint8_t readByte();
    
    uint16_t readLittleEndian16();
    
    uint32_t readLittleEndian32();
    
    uint64_t readLittleEndian64();
    
    NSData* readBuffer(int64_t size);
    
    void read(uint8_t *ptr, int64_t size);
    
    int64_t seek(YZHDataSeekType seekType);
    
    int64_t seekTo(int64_t to);
    
    int64_t currentSeek();
    
    int64_t bufferSize();

    int64_t dataSize();
    
    int64_t remSize();
    
    
    void bzero();
    
    /*
     *truncate不把内容置零
     */
    BOOL truncateTo(int64_t size);
    /*
     *truncate把内容置setval
     */
    BOOL truncateTo(int64_t size, uint8_t setval);
    
    uint8_t* bytes();
    
    NSData* data();
    
    NSData* copyData();
};



class YZHMutableCodeData : public YZHCodeData {
public:
    YZHMutableCodeData();
    
    YZHMutableCodeData(int64_t size);
    
    YZHMutableCodeData(NSData *data);
    //复制构造函数
    YZHMutableCodeData(YZHCodeData *codeData);
    
    virtual ~YZHMutableCodeData();
    
    BOOL ensureRemSize(int64_t remSize);
    
    BOOL increaseLengthBy(int64_t extraLength);
    
    //下面在长度不足时会进行increase
    void appendWriteData(NSData *data);
    
    void appendWriteBuffer(uint8_t *ptr, int64_t size);
    
    void appendWriteByte(uint8_t value);
    
    NSMutableData* mutableData();
    
    NSMutableData* mutableCopyData();
};
#endif
