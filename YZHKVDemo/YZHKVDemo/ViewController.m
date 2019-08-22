//
//  ViewController.m
//  YZHKVDemo
//
//  Created by yuan on 2019/6/30.
//  Copyright © 2019 yuan. All rights reserved.
//

#import "ViewController.h"
#import <objc/runTime.h>
#import <mach/mach_time.h>
#import "YZHCoder.h"
#import "YZHKV.h"
#import "YZHAESCryptor.h"

#import "X.h"
#import "TestObj.h"
#import "Account.h"

#import "YZHMachTimeUtils.h"

#import "YZHKVUtils.h"

@interface ViewController ()

@property (nonatomic, strong) YZHKV *kv;

@property (nonatomic, strong) YZHAESCryptor *cryptor;

@end



@implementation ViewController
{
    NSMutableArray *m_arrStrings;
    NSMutableArray *m_arrStrKeys;
    NSMutableArray *m_arrIntKeys;
    
    int m_loops;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self _testCoder];
    
//    [self _testAccount];
    
    [self kvBaselineTest:10000];
    
//    [self _testCryptor];
    
}


-(YZHKV*)kv{
    if (_kv == nil) {
        NSData *cryptKey = [@"yuanzhen" dataUsingEncoding:NSUTF8StringEncoding];
//        NSData *cryptKey = nil;
        [YZHMachTimeUtils recordPointWithText:@"开始"];
        _kv = [[YZHKV alloc] initWithName:@"db/test/1/2/3/kv" path:nil cryptKey:cryptKey];
        [YZHMachTimeUtils recordPointWithText:@"结束"];
    }
    return _kv;
}

- (void)_testCoder
{

//    NSNumber *numf = [NSNumber numberWithFloat:1.0];
//    NSNumber *numd = [NSNumber numberWithDouble:123.02];
//    NSNumber *numb = [NSNumber numberWithBool:YES];
//    NSNumber *numI = [NSNumber numberWithInt:12345];
//    NSNumber *numIT = [NSNumber numberWithUnsignedInteger:12373834];
//    NSLog(@"f.type=%s,d.type=%s,b.type=%s,i.type=%s,ite.type=%s",numf.objCType,numd.objCType,numb.objCType,numI.objCType,numIT.objCType);
    
//    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test.json" ofType:nil];
//    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    
    NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
//    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
//                                                         options:0 error:NULL];
//    NSLog(@"dict=%@",dict);
    
    NSInteger cnt = 1;

    NSLog(@"json cost:");
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (NSInteger i = 0; i < cnt; ++i) {
            @autoreleasepool {
                NSError *error = nil;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
//                NSLog(@"dtlen=%ld",jsonData.length);
//                NSLog(@"json=%@,desc=%@",[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding],dict);
                id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&error];
            }
        }
    }];
    
    YZHMutableCodeData *codeData = [[YZHMutableCodeData alloc] init];
    
    __block NSDictionary *decodeDict = nil;
    
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (NSInteger i = 0; i < cnt; ++i) {
            @autoreleasepool {
                [codeData truncateTo:0];
                [YZHCoder encodeObject:dict intoCodeData:codeData];
//                NSLog(@"dtlen=%ld",codeData.dataSize);
                decodeDict = [YZHCoder decodeObjectFromBuffer:codeData.bytes length:codeData.dataSize];
//                NSLog(@"dic=%@",dic);
            }
        }
    }];
    
    
    NSString *input = [YZHKVUtils applicationTmpDirectory:@"in.json"];
    NSLog(@"input=%@",input);
    [dict writeToFile:input atomically:YES];
    
    NSString *tmp = [YZHKVUtils applicationTmpDirectory:@"out.json"];
    NSLog(@"tmp=%@",tmp);
    [decodeDict writeToFile:tmp atomically:YES];
}

-(void)_testAccount
{
#if 1
    //Account
    Account *accout = [Account new];
    accout.uin = 1234567899;
    accout.accid = @"accid";
    accout.token = @"token";
    accout.session = @"session";
    accout.cookie = [@"cookie" dataUsingEncoding:NSUTF8StringEncoding];
    accout.autoAuthKey = [@"autoAuthKey" dataUsingEncoding:NSUTF8StringEncoding];
    accout.appKey = @"appKey";
    accout.rangeStart = 1234;
    accout.watershed = 56789;
    accout.height = 180.5;
    accout.weight = 65.8;
    
    accout.ext = 430822188812180923;
    accout.name = @"name";
    
    //X
    X *x = [X new];
    x.x = @"201907291824202ccbd1ce844a4279483f097d78fd2e7a01a09d71b45d0d93";
    x.xx = @"hAqDtdVguWqL0EES8GIEEKaG8E0NN46CIqpNxtRap5g|82073FF2-3A72-4D6D-8613-202DF4820BB2|201907291824202ccbd1ce844a4279483f097d78fd2e7a01a09d71b45d0d93";
    x.x_y = [NSString stringWithFormat:@"%@-%@",x.x,x.xx];

    //TestObj
    TestObj *test = [TestObj new];
    test.a = 156561289410101;
    test.b = 15656128.9410101;
    test.c = 156568.88;
    test.d = @"中华民族有着悠久的历史";
    test.e = [@"从遥远的古代起，中华各民族人民的祖先就劳动、生息、繁衍在我们祖国的土地上，共同为中华文明和建立统一的多民族国家贡献着自己的才智" dataUsingEncoding:NSUTF8StringEncoding];
    
    test.f = @[@"1",@(2),@{@"key":@"value"}];
    
    test.g = @{@"k1":@"v1", @"k2":@"v2", @(1):@(2), @"1":@"2"};
    test.x = [X new];
    test.x.x = @"花容月貌";
    test.x.xx = @"古来圣贤皆寂寞，惟有饮者留其名";
    test.x.x_y = @"人生得意须尽欢，莫使金樽空对月";
    
    [[self.kv allEntries] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSLog(@"key=%@,obj=%@",key,obj);
    }];
    
    
    NSArray *list = @[accout,x,test];
    NSMutableArray *result = [NSMutableArray array];
    
//    NSInteger cnt = 10000;
//
//    for (NSInteger i = 0; i < cnt; ++i) {
//
//        NSInteger idx = arc4random()%3;
//        id obj = [list objectAtIndex:idx];
//
//        [result addObject:obj];
//    }
    [result addObject:accout];
    
    NSLog(@"start KV storage:cnt=%ld",result.count);
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (id obj in result) {
            NSString *key = NSStringFromClass([obj class]);
            [self.kv setObject:obj forKey:key];
        }
    }];
    NSLog(@"end KV storage");
#else
    __block id acc = nil;
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
//        self.kv;
        acc = [self.kv getObjectForKey:@"Account"];
    }];
    NSLog(@"acc=%@",acc);
    return;
//    NSData *cryptKey = [@"yuanzhen" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *cryptKey = nil;
    [self.kv updateCryptKey:cryptKey];
#endif
}



- (void)kvBaselineTest:(int)loops {
    [self _startTest:loops];
    [self kvBatchWriteInt:loops];
//    [self kvBatchReadInt:loops];
//    [self kvBatchWriteString:loops];
//    [self kvBatchReadString:loops];
    
    //[self mmkvBatchDeleteString:loops];
    //[[MMKV defaultMMKV] trim];
}

- (void)_startTest:(int)loops
{
    m_loops = loops;
    m_arrStrings = [NSMutableArray arrayWithCapacity:m_loops];
    m_arrStrKeys = [NSMutableArray arrayWithCapacity:m_loops];
    m_arrIntKeys = [NSMutableArray arrayWithCapacity:m_loops];
    for (size_t index = 0; index < m_loops; index++) {
        NSString *str = [NSString stringWithFormat:@"%s-%d", __FILE__, rand()];
        [m_arrStrings addObject:str];
        
        NSString *strKey = [NSString stringWithFormat:@"str-%zu", index];
        [m_arrStrKeys addObject:strKey];
        
        NSString *intKey = [NSString stringWithFormat:@"int-%zu", index];
        [m_arrIntKeys addObject:intKey];
    }
}

- (void)kvBatchWriteInt:(int)loops {
    @autoreleasepool {
        NSLog(@"initKV,cost:");
        [YZHMachTimeUtils elapsedMSTimeInBlock:^{
            self.kv;
        }];
        return;
        NSLog(@"kv write int %d times, cost:", loops);
        [YZHMachTimeUtils elapsedMSTimeInBlock:^{
            for (int index = 0; index < loops; index++) {
                int32_t tmp = rand();
                NSString *intKey = self->m_arrIntKeys[index];
                [self.kv setInteger:tmp forKey:intKey];
            }
        }];
        NSLog(@"finish");
    }
}

- (void)kvBatchReadInt:(int)loops {
    @autoreleasepool {
        NSLog(@"kv read int %d times, cost:", loops);
        
        [YZHMachTimeUtils elapsedMSTimeInBlock:^{

            for (int index = 0; index < loops; index++) {
                NSString *intKey = self->m_arrIntKeys[index];
                [self.kv getInt32ForKey:intKey];
            }
        }];
    }
}

- (void)kvBatchWriteString:(int)loops {
    @autoreleasepool {
        NSLog(@"kv write string %d times, cost:", loops);
        [YZHMachTimeUtils elapsedMSTimeInBlock:^{
            
            for (int index = 0; index < loops; index++) {
                NSString *str = self->m_arrStrings[index];
                NSString *strKey = self->m_arrStrKeys[index];
                [self.kv setObject:str forKey:strKey];
            }
        }];
    }
}

- (void)kvBatchReadString:(int)loops {
    @autoreleasepool {

        NSLog(@"mmkv read string %d times, cost:", loops);
        [YZHMachTimeUtils elapsedMSTimeInBlock:^{
            for (int index = 0; index < loops; index++) {
                NSString *strKey = self->m_arrStrKeys[index];
//                [self getObjectOfClass:NSString.class forKey:strKey];
                [self.kv getObjectForKey:strKey];
            }
        }];
    }
}

- (void)kvBatchDeleteString:(int)loops {
    @autoreleasepool {
        
        NSLog(@"mmkv delete string %d times, cost:", loops);
        [YZHMachTimeUtils elapsedMSTimeInBlock:^{
            for (int index = 0; index < loops; index++) {
                NSString *strKey = self->m_arrStrKeys[index];
//                [self.kv removeValueForKey:strKey];
                [self.kv removeObjectForKey:strKey];
            }
        }];
    }
}









































-(void)_testCryptor
{
    [self _testECB];
    [self _testCBC];
    [self _testOFB];
    [self _testCFB];
    [self _testCFB1];
    [self _testCFB8];
}

- (void)_testECB
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    self.cryptor = [[YZHAESCryptor alloc] initWithAESKey:keyData keyType:YZHAESKeyType128 inVector:nil cryptMode:YZHCryptModeECB];
    
    NSString *text = @"12345";//@"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    NSData *plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:cipherData];
    NSString *plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"ECB.plainText.1=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    text = @"1234567890123456";//@"12345678901234561234567890123456";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:cipherData];
    plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"ECB.plainText.2=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
    text = @"12345678901234561234567890123456789";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:cipherData];
    plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"ECB.plainText.3=%@,same=%@",plainText,@([plainText isEqualToString:text]));
}

- (void)_testCBC
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    self.cryptor = [[YZHAESCryptor alloc] initWithAESKey:keyData keyType:YZHAESKeyType128 inVector:keyData cryptMode:YZHCryptModeCBC];

    NSString *text = @"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    NSData *plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:cipherData];
    NSString *plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"CBC.plainText.1=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
    text = @"1234567890123456";//@"12345678901234561234567890123456";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:cipherData];
    plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"CBC.plainText.2=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
    text = @"12345678901234561234567890123456789";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:cipherData];
    plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"CBC.plainText.3=%@,same=%@",plainText,@([plainText isEqualToString:text]));
}

- (void)_testOFB
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    NSLog(@"OFB:");
    
    self.cryptor = [[YZHAESCryptor alloc] initWithAESKey:keyData keyType:YZHAESKeyType128 inVector:keyData cryptMode:YZHCryptModeOFB];
    
    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testCFB
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"CFB:");
    self.cryptor = [[YZHAESCryptor alloc] initWithAESKey:keyData keyType:YZHAESKeyType128 inVector:keyData cryptMode:YZHCryptModeCFB];

    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testCFB1
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"CFB1:");
    self.cryptor = [[YZHAESCryptor alloc] initWithAESKey:keyData keyType:YZHAESKeyType128 inVector:keyData cryptMode:YZHCryptModeCFB1];
    
    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testCFB8
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"CFB8:");
    self.cryptor = [[YZHAESCryptor alloc] initWithAESKey:keyData keyType:YZHAESKeyType128 inVector:keyData cryptMode:YZHCryptModeCFB8];
    
    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testFlowCrypt1
{
    NSString *text = @"12345678901234561234567890123456";
    NSMutableString *allInputText = [[NSMutableString alloc] initWithString:text];
    
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    
    [self.cryptor reset];
    int64_t outSize = cipherData.length;
    NSMutableData *plainData = [NSMutableData dataWithLength:cipherData.length];
    [self.cryptor crypt:YZHCryptOperationDecrypt input:(uint8_t*)cipherData.bytes inSize:outSize output:(uint8_t*)plainData.mutableBytes outSize:&outSize];
    NSString *plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"plainText.1=%@,isSame=%@",plainText,@([plainText isEqualToString:allInputText]));

    
    //在解密的基础上进行加密
    text = @"123456789012345689";
    [allInputText appendString:text];
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSData *cipherData2 = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    
    NSMutableData *all = [NSMutableData dataWithData:cipherData];
    [all appendData:cipherData2];
    
    //重新解密全部
    [self.cryptor reset];
    NSData *p = [self.cryptor crypt:YZHCryptOperationDecrypt input:all];
    plainText = [[NSString alloc] initWithData:p encoding:NSUTF8StringEncoding];
    NSLog(@"plainText.2=%@,isSame=%@",plainText,@([plainText isEqualToString:allInputText]));

}

-(void)_testFlowCrypt2
{
    [self.cryptor reset];
    
    NSMutableData *all = [NSMutableData data];
    NSString *text = @"12345";//@"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    NSMutableString *allInputText = [[NSMutableString alloc] initWithString:text];
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    NSData *cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    [all appendData:cipherData];
    
    text = @"01389";//@"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    [allInputText appendString:text];
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    cipherData = [self.cryptor crypt:YZHCryptOperationEncrypt input:input];
    [all appendData:cipherData];
    
    [self.cryptor reset];
    NSData *plainData = [self.cryptor crypt:YZHCryptOperationDecrypt input:all];
    NSString *plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"all=%@,isSame=%@",plainText,@([plainText isEqualToString:allInputText]));
    
    if ([self.cryptor respondsToSelector:NSSelectorFromString(@"key")]) {
        NSData *key = [self.cryptor valueForKey:@"key"];
        NSData *vector = [self.cryptor valueForKey:@"inVector"];
        NSLog(@"key=%@,vector=%@",key,vector);
    }
}


@end
