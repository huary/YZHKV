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
#import "YZHAESCryptor.h"

#import "X.h"
#import "TestObj.h"
#import "Account.h"

#import "YZHMachTimeUtils.h"

#import "YZHKVUtils.h"
#import "YZHUIExcelView.h"
#import "UIReuseCell.h"
#import <MMKV/MMKV.h>


#import "YZHCFKV.h"
#import "YZHKV.h"

#include <string>

//#import "YZHCFKV.h"

typedef NS_ENUM(NSInteger, NSExcelRowTag)
{
    NSExcelRowTagYZHKV          = 1,
    NSExcelRowTagMMKV           = 2,
    NSExcelRowTagUserDefault    = 3,
};

typedef NS_ENUM(NSInteger, NSExcelColumnTag)
{
    NSExcelColumnTagFirstInit   = 1,
    NSExcelColumnTagLoadInit    = 2,
    NSExcelColumnTagWrite       = 3,
    NSExcelColumnTagRead        = 4,
    NSExcelColumnTagDelete      = 5,
    NSExcelColumnTagClear       = 6,
    NSExcelColumnTagUpdateCryptKey  = 7,
};

typedef NS_ENUM(NSInteger, NSTestOption)
{
    NSTestOptionInt     = 0,
    NSTestOptionDouble  = 1,
    NSTestOptionString  = 2,
};

class TestSharedPtr {
public:
    TestSharedPtr(int32_t val) {
        _val = val;
        NSLog(@"constructor======.val=%d",val);
    }
    ~TestSharedPtr() {
        NSLog(@"destructor======val=%d",_val);
    }
    int32_t _val;
};




@interface ViewController ()<YZHUIExcelViewDelegate>
{
    shared_ptr<YZHAESCryptor> _cryptor;
}

/** <#注释#> */
@property (nonatomic, copy) NSString *basePath;

@property (nonatomic, copy) NSString *kvName;

@property (nonatomic, strong) YZHKV *kv;

@property (nonatomic, copy) NSString *mmkvName;

@property (nonatomic, strong) MMKV *mmkv;

@property (nonatomic, copy) NSString *cryptKeyString;

@property (nonatomic, assign) int32_t loopCnt;

@property (nonatomic, strong) NSMutableArray *intKeys;

@property (nonatomic, strong) NSMutableArray *doubleKeys;

@property (nonatomic, strong) NSMutableArray *strKeys;

@property (nonatomic, strong) NSMutableArray *numbers;

@property (nonatomic, strong) NSMutableArray *strings;

@property (nonatomic, strong) YZHUIExcelView *excelView;

@property (weak, nonatomic) IBOutlet UITextField *cryptKeyTextField;

@property (weak, nonatomic) IBOutlet UITextField *loopCntTextField;
@property (weak, nonatomic) IBOutlet UISegmentedControl *TestOptionSegment;
@property (weak, nonatomic) IBOutlet UIView *containerView;

@property (weak, nonatomic) IBOutlet UITextView *otherInfoView;

@property (nonatomic, strong) NSMutableArray<NSMutableArray*> *excelData;

@property (nonatomic, assign) NSTestOption testOption;

@end



@implementation ViewController
{
    CGFloat *_ptr_double;
    int64_t *_ptr_integer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self _testClass];
    
//    [self _testSharedPtr];
//    return;
    
//    [self _testCoder];
    
    [self _setupDefaultData];
    
//    [self _testAccount];
    
    
//    [self kvBaselineTest:10000];
    
//    [self _testCryptor];
    
    [self _setupChildView];
    
    [self _startTest:self.loopCnt testOption:self.testOption];
}

- (NSMutableArray*)intKeys
{
    if (_intKeys == nil) {
        _intKeys = [NSMutableArray arrayWithCapacity:self.loopCnt];
    }
    return _intKeys;
}

- (NSMutableArray*)doubleKeys
{
    if (_doubleKeys == nil) {
        _doubleKeys = [NSMutableArray arrayWithCapacity:self.loopCnt];
    }
    return _doubleKeys;
}

- (NSMutableArray*)strKeys {
    if (_strKeys == nil) {
        _strKeys = [NSMutableArray arrayWithCapacity:self.loopCnt];
    }
    return _strKeys;
}

- (NSMutableArray*)numbers
{
    if (_numbers == nil) {
        _numbers = [NSMutableArray arrayWithCapacity:self.loopCnt];
    }
    return _numbers;
}

- (NSMutableArray*)strings
{
    if (_strings == nil) {
        _strings = [NSMutableArray arrayWithCapacity:self.loopCnt];
    }
    return _strings;
}

- (NSMutableArray<NSMutableArray*>*)excelData
{
    if (_excelData == nil) {
        _excelData = [NSMutableArray array];
    }
    return _excelData;
}

- (NSString*)cryptKeyString{
//    if (_cryptKeyString == nil) {
//        _cryptKeyString = self.cryptKeyTextField.text;
//    }
    _cryptKeyString = self.cryptKeyTextField.text;
    return _cryptKeyString;
}

static inline BOOL objectIsKindOfClass(id object, Class cls)
{
    Class objCls = [object class];
    while (objCls) {
        objCls = class_getSuperclass(objCls);
        if (objCls == cls) {
            return YES;
        }
    }
    return NO;
}

- (void)_testClass
{
    NSNumber *val = @(2);
    int cnt = 1;
    
//    Class vcls = [val class];
    NSLog(@"class=");
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
//        [val class];
        for (int i = 0; i < cnt; ++i) {
            [val isKindOfClass:[NSString class]];
        }
        
//        [vcls superclass];
    }];
    NSLog(@"object_getClass=");
    NSString *text = @"object_getClass";
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
//        [val class] == [NSNumber class];
        for (int i = 0; i < cnt; ++i) {
            
            objectIsKindOfClass(val, [NSString class]);
            
            
//            NSLog(@"size=%ld",class_getInstanceSize(object_getClass(text)));
            
//            Class vcls = [val class];
//            Class ncls = [NSString class];
//
//
//
//            while (vcls && vcls != ncls) {
//                vcls = class_getSuperclass(vcls);
//                //            vcls = [vcls superclass];
//                NSLog(@"vcls=%@",vcls);
//            }
        }
//        class_getSuperclass(vcls);
    }];
    
    
    NSLog(@"val.class=%@,cls=%@,number.cls=%@,isSame=%@",[val class],object_getClass(val),[NSNumber class],@([val class] == [NSNumber class]));
    
}

- (void)_testSharedPtr
{
//    shared_ptr<TestSharedPtr> share1 = make_shared<TestSharedPtr>(10);
//    NSLog(@"share1.cnt=%ld,ptr=%p",share1.use_count(),share1.get());
////    share1.reset();
////    NSLog(@"share1.cnt=%d,ptr=%p",share1.use_count(),share1.get());
////    shared_ptr<TestSharedPtr> share2 = share1;
////    NSLog(@"share1.cnt=%d,ptr=%p",share1.use_count(),share1.get());
////    NSLog(@"share2.cnt=%d,ptr=%p",share2.use_count(),share2.get());
////    share1.reset();
////    NSLog(@"share1.cnt=%d,ptr=%p",share1.use_count(),share1.get());
////    NSLog(@"share2.cnt=%d,ptr=%p",share2.use_count(),share2.get());
//
//    shared_ptr<TestSharedPtr> share3;
//    NSLog(@"share3.cnt=%ld,ptr=%p",share3.use_count(),share3.get());
//    share1.swap(share3);
//    NSLog(@"share1.cnt=%ld,ptr=%p",share1.use_count(),share1.get());
//    NSLog(@"share3.cnt=%ld,ptr=%p",share3.use_count(),share3.get());
    
    YZHMutableCodeData *codeData = new YZHMutableCodeData();
    
//    shared_ptr<YZHCodeData> share = shared_ptr<YZHCodeData>(codeData);
    shared_ptr<YZHCodeData> share = make_shared<YZHMutableCodeData>(codeData);

    
    NSLog(@"%s.finish",__FUNCTION__);
}

- (void)_setupDefaultData
{
    NSMutableArray *firstRow = [NSMutableArray array];
    [firstRow addObject:@"测试Kit/结果"];
    [firstRow addObject:@"空加载(ms)"];
    [firstRow addObject:@"数据加载(ms)"];
    [firstRow addObject:@"写(ms)"];
    [firstRow addObject:@"读(ms)"];
    [firstRow addObject:@"删除(ms)"];
    [firstRow addObject:@"清除(ms)"];
    [firstRow addObject:@"更新密钥(ms)"];
    [self.excelData addObject:firstRow];
    NSMutableArray *kvRow = [NSMutableArray array];
    [kvRow addObject:@"KV"];
    [kvRow addObject:@""];
    [kvRow addObject:@""];
    [kvRow addObject:@""];
    [kvRow addObject:@""];
    [kvRow addObject:@""];
    [kvRow addObject:@""];
    [kvRow addObject:@""];
    [self.excelData addObject:kvRow];
    
    NSMutableArray *mmkvRow = [NSMutableArray array];
    [mmkvRow addObject:@"MMKV"];
    [mmkvRow addObject:@""];
    [mmkvRow addObject:@""];
    [mmkvRow addObject:@""];
    [mmkvRow addObject:@""];
    [mmkvRow addObject:@""];
    [mmkvRow addObject:@""];
    [mmkvRow addObject:@""];
    [self.excelData addObject:mmkvRow];
    
    NSMutableArray *defaultRow = [NSMutableArray array];
    [defaultRow addObject:@"NSUserDefaults"];
    [defaultRow addObject:@""];
    [defaultRow addObject:@""];
    [defaultRow addObject:@""];
    [defaultRow addObject:@""];
    [defaultRow addObject:@""];
    [defaultRow addObject:@""];
    [defaultRow addObject:@""];
    [self.excelData addObject:defaultRow];
    
    self.loopCnt = 10000;
    self.testOption = NSTestOptionInt;
    self.kvName = @"com.kv";
    self.mmkvName = @"com.wx.mmkv";
    self.basePath = [YZHKVUtils applicationDocumentsDirectory:@"KV"];
}

- (void)_setupChildView
{
    self.loopCntTextField.text = NEW_STRING_WITH_FORMAT(@"%d",self.loopCnt);
    self.TestOptionSegment.selectedSegmentIndex = self.testOption;
    
    CGRect frame = self.containerView.frame;
    frame.size.width = self.view.width - 2 * frame.origin.x;
    self.excelView = [[YZHUIExcelView alloc] initWithFrame:frame];
    self.excelView.delegate = self;
    self.excelView.lockIndexPath = [NSIndexPath indexPathForExcelRow:1 excelColumn:1];
    self.excelView.backgroundColor = self.containerView.backgroundColor;
    [self.view addSubview:self.excelView];
}

- (NSString*)_textFromTime:(CGFloat)time
{
    return NEW_STRING_WITH_FORMAT(@"%.5f",time);
}

-(YZHKV*)kv{
    if (_kv == nil) {
        CGFloat t = 0;
        NSString *fileName = self.kvName;
        NSString *filePath = [self.basePath stringByAppendingPathComponent:fileName];
        
        NSLog(@"filePath=%@",filePath);
        self.otherInfoView.text = filePath;
        NSExcelColumnTag tag = [YZHKVUtils checkFileExistsAtPath:filePath] ? NSExcelColumnTagLoadInit : NSExcelColumnTagFirstInit;
        NSLog(@"initKV");
        NSData *cryptKey = [self.cryptKeyString dataUsingEncoding:NSUTF8StringEncoding];
        [YZHMachTimeUtils recordPointWithText:@"start"];
        if (self.cryptKeyString.length > 0) {
            t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
                _kv = [[YZHKV alloc] initWithName:fileName path:self.basePath cryptKey:cryptKey];
            }];
        }
        else {
            t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
                _kv = [[YZHKV alloc] initWithName:fileName path:self.basePath cryptKey:nil];
            }];
        }
        [YZHMachTimeUtils recordPointWithText:@"end"];
        
        NSLog(@"error=%@",[_kv lastError]);
        
        NSLog(@"text=%f",t);

        NSLog(@"KV.cnt=%@",@(_kv.allEntries.count));
        
        NSString *text = [self _textFromTime:t];
        NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
        [row setObject:text atIndexedSubscript:tag];
        [self.excelView reloadData];
    }
    return _kv;
}

- (MMKV*)mmkv
{
    if (_mmkv == nil) {
        CGFloat t = 0;
        NSString *fileName = self.mmkvName;
        [MMKV setMMKVBasePath:self.basePath];
        NSString *filePath = [[MMKV mmkvBasePath] stringByAppendingPathComponent:fileName];
        NSLog(@"filePath=%@",filePath);
        NSExcelColumnTag tag = [YZHKVUtils checkFileExistsAtPath:filePath] ? NSExcelColumnTagLoadInit : NSExcelColumnTagFirstInit;

        if (self.cryptKeyString.length == 0) {
            t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
                _mmkv = [MMKV mmkvWithID:fileName];
            }];
        }
        else {
            NSData *cryptKey = [self.cryptKeyString dataUsingEncoding:NSUTF8StringEncoding];
            t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
                _mmkv = [MMKV mmkvWithID:fileName cryptKey:cryptKey];
            }];
        }
        
        NSLog(@"MMKV.cnt=%@",@(_mmkv.allKeys.count));


        NSString *text = [self _textFromTime:t];
        NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
        [row setObject:text atIndexedSubscript:tag];
        [self.excelView reloadData];
    }
    return _mmkv;
}


- (void)_testCoder
{
    NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
    NSLog(@"dict=%@",dict);
    
    NSInteger cnt = 10000;

    NSLog(@"json cost:");
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (NSInteger i = 0; i < cnt; ++i) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:NULL];
            id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:NULL];
        }
    }];
    
    
    YZHMutableCodeData *codeData = new YZHMutableCodeData();
    
    __block NSDictionary *decodeDict = nil;
    
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (NSInteger i = 0; i < cnt; ++i) {
            codeData->truncateTo(0);
            encodeObjectToTopSuperClassIntoCodeData(dict, NULL, codeData, NULL);
//            NSLog(@"data=%@",codeData->copyData());
//            NSLog(@"dtlen=%lld",codeData->dataSize());
            decodeDict = decodeObjectFromBuffer(codeData->bytes(), codeData->currentSeek(), NULL, NULL, NULL);
//            NSLog(@"decodeDict=%@",decodeDict);
        }
    }];
    
    NSData *data = [@"data" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary *mDict = [NSMutableDictionary dictionary];
    [mDict setObject:data forKey:@"data"];
    NSLog(@"data=%@",data);
    codeData->truncateTo(0);
    encodeObjectToTopSuperClassIntoCodeData(mDict, NULL, codeData, NULL);
    NSDictionary *t = decodeObjectFromBuffer(codeData->bytes(), codeData->currentSeek(), NULL, NULL, NULL);
    NSLog(@"t=%@",t);
    
    
    if (codeData) {
        delete codeData;
    }
}

-(void)_testAccount
{
    YZHMutableCodeData codeData;
    
    int64_t uin = 5050023337659471103;
    encodeIntegerIntoCodeData(uin, &codeData);

    int64_t tmp = decodeIntegerFromBuffer(codeData.bytes(), codeData.dataSize(), nullptr, NULL);
    NSLog(@"tmp=%@",@(tmp));
    return;
    
#if 1
    //Account
    Account *accout = [Account new];
    accout.uin = 5050023337659471103;
    accout.accid = @"accid";
    accout.token = @"token";
    accout.session = @"session";
    accout.cookie = nil;//[@"cookie" dataUsingEncoding:NSUTF8StringEncoding];
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
    test.a = (NSInteger)156561289410101;
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
//    [result addObject:accout];
    [result addObjectsFromArray:list];
    
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
    __block id x = nil;
    __block id testObj = nil;
    self.kv;
    NSLog(@"get account");
    [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        acc = [self.kv getObjectForKey:@"Account"];
        x = [self.kv getObjectForKey:@"X"];
        testObj = [self.kv getObjectForKey:@"TestObj"];
    }];
    NSLog(@"acc=%@",acc);
    NSLog(@"x=%@",x);
    NSLog(@"testObj=%@",testObj);
    
    float f = 156568.88;
    int32_t int32f = Int32FromFloat(f);
    int64_t int64f = Int64FromFloat(f);
    float fc = FloatFromInt32(int32f);
    NSLog(@"float=%.5f,int32f=%d,fc=%.5f,fn=%@,int64f=%lld",f,int32f, fc,@(f),int64f);
    NSLog(@"end");
//    NSData *cryptKey = [@"yuanzhen" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *cryptKey = nil;
    [self.kv updateCryptKey:cryptKey];
#endif
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
    
    YZHCodeData codeKeyData(keyData);
    _cryptor = make_shared<YZHAESCryptor>(&codeKeyData, YZHAESKeyType128, nullptr, YZHCryptModeECB);
    
    NSString *text = @"12345";//@"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    YZHMutableCodeData inputCodeData(4096);
    inputCodeData.writeData(input);

    shared_ptr<YZHMutableCodeData> output = make_shared<YZHMutableCodeData>();
    
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), output.get());
    NSString *plainText = [[NSString alloc] initWithBytes:output->bytes() length:(NSUInteger)output->dataSize() encoding:NSUTF8StringEncoding];
    NSLog(@"ECB.plainText.1=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    text = @"1234567890123456";//@"12345678901234561234567890123456";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    

    inputCodeData.truncateTo(0);
    inputCodeData.writeData(input);
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), output.get());
    plainText = [[NSString alloc] initWithBytes:output->bytes() length:(NSUInteger)output->dataSize() encoding:NSUTF8StringEncoding];
    NSLog(@"ECB.plainText.2=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
    text = @"12345678901234561234567890123456789";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    inputCodeData.truncateTo(0);
    inputCodeData.writeData(input);
    
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), output.get());
    
    plainText = [[NSString alloc] initWithBytes:output->bytes() length:(NSUInteger)output->dataSize() encoding:NSUTF8StringEncoding];
    NSLog(@"ECB.plainText.3=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
}

- (void)_testCBC
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    YZHCodeData codeKeyData(keyData);
    _cryptor = make_shared<YZHAESCryptor>(&codeKeyData, YZHAESKeyType128, &codeKeyData, YZHCryptModeCBC);


    NSString *text = @"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    YZHMutableCodeData inputCodeData(4096);
    inputCodeData.writeData(input);
    shared_ptr<YZHMutableCodeData> output = make_shared<YZHMutableCodeData>();
    
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), output.get());
    NSString *plainText = [[NSString alloc] initWithBytes:output->bytes() length:(NSUInteger)output->dataSize() encoding:NSUTF8StringEncoding];
    
    NSLog(@"CBC.plainText.1=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
    text = @"1234567890123456";//@"12345678901234561234567890123456";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    inputCodeData.truncateTo(0);
    inputCodeData.writeData(input);
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), output.get());
    plainText = [[NSString alloc] initWithBytes:output->bytes() length:(NSUInteger)output->dataSize() encoding:NSUTF8StringEncoding];
    NSLog(@"CBC.plainText.2=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
    
    text = @"12345678901234561234567890123456789";
    input = [text dataUsingEncoding:NSUTF8StringEncoding];

    inputCodeData.truncateTo(0);
    inputCodeData.writeData(input);
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), output.get());
    plainText = [[NSString alloc] initWithBytes:output->bytes() length:(NSUInteger)output->dataSize() encoding:NSUTF8StringEncoding];
    NSLog(@"CBC.plainText.3=%@,same=%@",plainText,@([plainText isEqualToString:text]));
    
}

- (void)_testOFB
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    NSLog(@"OFB:");
    
    YZHCodeData codeKeyData(keyData);
    _cryptor = make_shared<YZHAESCryptor>(&codeKeyData, YZHAESKeyType128, &codeKeyData, YZHCryptModeOFB);

    
    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testCFB
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"CFB:");
    YZHCodeData codeKeyData(keyData);
    _cryptor = make_shared<YZHAESCryptor>(&codeKeyData, YZHAESKeyType128, &codeKeyData, YZHCryptModeCFB);

    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testCFB1
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"CFB1:");
    YZHCodeData codeKeyData(keyData);
    _cryptor = make_shared<YZHAESCryptor>(&codeKeyData, YZHAESKeyType128, &codeKeyData, YZHCryptModeCFB1);
    
    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testCFB8
{
    NSString *key = @"1234567890123456";
    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"CFB8:");
    YZHCodeData codeKeyData(keyData);
    _cryptor = make_shared<YZHAESCryptor>(&codeKeyData, YZHAESKeyType128, &codeKeyData, YZHCryptModeCFB8);
    
    [self _testFlowCrypt1];
    [self _testFlowCrypt2];
}

- (void)_testFlowCrypt1
{
    NSString *text = @"12345678901234561234567890123456";
    NSMutableString *allInputText = [[NSMutableString alloc] initWithString:text];
    
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    YZHMutableCodeData inputCodeData(1024);
    inputCodeData.writeData(input);
    
    shared_ptr<YZHMutableCodeData> output = make_shared<YZHMutableCodeData>();
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    
    NSData *cipherData = output->copyData();
    
    self->_cryptor->reset();
    
    int64_t outSize = output.get()->dataSize();
    YZHMutableCodeData plainData(outSize);
    self->_cryptor->crypt(YZHCryptOperationDecrypt, output.get(), &plainData);
    NSString *plainText = [[NSString alloc] initWithBytes:plainData.bytes() length:(NSUInteger)plainData.dataSize() encoding:NSUTF8StringEncoding];
    NSLog(@"plainText.1=%@,isSame=%@",plainText,@([plainText isEqualToString:allInputText]));

    
    output->truncateTo(0);
    //在解密的基础上进行加密
    text = @"123456789012345689";
    [allInputText appendString:text];
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    inputCodeData.truncateTo(0);
    inputCodeData.appendWriteData(input);
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    NSData *cipherData2 = output->copyData();
    
    NSMutableData *all = [NSMutableData dataWithData:cipherData];
    [all appendData:cipherData2];
    
    //重新解密全部
    self->_cryptor->reset();
    
    output->truncateTo(0);
    inputCodeData.truncateTo(0);
    inputCodeData.appendWriteData(all);
    
    self->_cryptor->crypt(YZHCryptOperationDecrypt, &inputCodeData, output.get());
    NSData *p = output->copyData();
    plainText = [[NSString alloc] initWithData:p encoding:NSUTF8StringEncoding];
    NSLog(@"plainText.2=%@,isSame=%@",plainText,@([plainText isEqualToString:allInputText]));

}

-(void)_testFlowCrypt2
{
    self->_cryptor->reset();
    
    NSMutableData *all = [NSMutableData data];
    NSString *text = @"12345";//@"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    NSMutableString *allInputText = [[NSMutableString alloc] initWithString:text];
    NSData *input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    YZHMutableCodeData inputCodeData(1024);
    inputCodeData.writeData(input);
    
    shared_ptr<YZHMutableCodeData> output = make_shared<YZHMutableCodeData>();
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    
    NSData *cipherData = output->copyData();
    [all appendData:cipherData];
    
    text = @"01389";//@"12345";//@"1234567890123456";//@"12345678901234561234567890123456";
    [allInputText appendString:text];
    input = [text dataUsingEncoding:NSUTF8StringEncoding];
    
    output->truncateTo(0);
    inputCodeData.truncateTo(0);
    inputCodeData.appendWriteData(input);
    self->_cryptor->crypt(YZHCryptOperationEncrypt, &inputCodeData, output.get());
    cipherData = output->copyData();
    
    [all appendData:cipherData];
    
    self->_cryptor->reset();
    
    output->truncateTo(0);
    inputCodeData.truncateTo(0);
    inputCodeData.appendWriteData(all);
    
    self->_cryptor->crypt(YZHCryptOperationDecrypt, &inputCodeData, output.get());
    NSData *plainData = output->copyData();
    
    NSString *plainText = [[NSString alloc] initWithData:plainData encoding:NSUTF8StringEncoding];
    NSLog(@"all=%@,isSame=%@",plainText,@([plainText isEqualToString:allInputText]));
}






#pragma mark YZHUIExcelViewDelegate
-(NSInteger)numberOfRowsInExcelView:(YZHUIExcelView *)excelView
{
    return self.excelData.count;
}
-(NSInteger)numberOfColumnsInExcelView:(YZHUIExcelView *)excelView
{
    return [[self.excelData objectAtIndex:0] count];
}

-(CGFloat)excelView:(YZHUIExcelView *)excelView heightForRowAtIndex:(NSInteger)rowIndex
{
    return 50;
}

-(CGFloat)excelView:(YZHUIExcelView *)excelView widthForColumnAtIndex:(NSInteger)columnIndex
{
    return 90;
}

-(UIView*)excelView:(YZHUIExcelView *)excelView excelCellForItemAtIndexPath:(NSIndexPath*)indexPath withReusableExcelCellView:(UIView *)reusableExcelCellView
{
    UIReuseCell *cell = (UIReuseCell*)reusableExcelCellView;
    if (cell == nil) {
        cell = [[UIReuseCell alloc] init];
    }
    cell.backgroundColor = excelView.backgroundColor;
    
    NSMutableArray *r = [self.excelData objectAtIndex:indexPath.excelRow];
    NSString *text = [r objectAtIndex:indexPath.excelColumn];
    cell.textLabel.text = text;
    cell.textLabel.numberOfLines = 0;
    // NEW_STRING_WITH_FORMAT(@"(%ld,%ld)",indexPath.excelRow,indexPath.excelColumn);
    return cell;
}






- (IBAction)_optionChangedAction:(UISegmentedControl *)sender {
    [self.view endEditing:YES];
    NSLog(@"selectedIdx=%ld",sender.selectedSegmentIndex);
}


- (IBAction)_resetAction:(UIButton *)sender {
    [self.view endEditing:YES];
    if (_kv) {
        [_kv close];
        [YZHKVUtils removeFileItemAtPath:[_kv filePath]];
        _kv = nil;
    }
    
    if (_mmkv) {
        [_mmkv close];
//        NSString *filePath = [[MMKV mmkvBasePath] stringByAppendingPathComponent:self.mmkvName];
        [YZHKVUtils removeFileItemAtPath:[MMKV mmkvBasePath]];
        _mmkv = nil;
    }
}

- (IBAction)_rebootAction:(UIButton *)sender {
    [self.view endEditing:YES];

    if (_kv) {
        [_kv close];
        _kv = nil;        
    }
    if (_mmkv) {
        [_mmkv close];
        _mmkv = nil;
    }
    
    [self mmkv];

    [NSThread sleepForTimeInterval:1];
    [self kv];
    NSString *filePath = [self.kv filePath];
    NSString *mmkvPath = [[MMKV mmkvBasePath] stringByAppendingPathComponent:self.mmkvName];
    self.otherInfoView.text = [filePath stringByAppendingFormat:@"\n%@",mmkvPath];
}

- (IBAction)_readDataAction:(UIButton *)sender {
    [self.view endEditing:YES];
    
    if (self.testOption == NSTestOptionInt) {
        [self _mmkvBatchReadIntTest:self.loopCnt];
        
        [self _kvBatchReadIntTest:self.loopCnt];
        
        [self _defaultBatchReadIntTest:self.loopCnt];
    }
    else if (self.testOption == NSTestOptionDouble) {
        [self _mmkvBatchReadDoubleTest:self.loopCnt];
        
        [self _kvBatchReadDoubleTest:self.loopCnt];
        
        [self _defaultBatchReadDoubleTest:self.loopCnt];
    }
    else if (self.testOption == NSTestOptionString) {
        [self _mmkvBatchReadStringTest:self.loopCnt];
        
        [self _kvBatchReadStringTest:self.loopCnt];
        
        [self _defaultBatchReadStringTest:self.loopCnt];
    }
    
}

- (IBAction)_writeData:(UIButton *)sender {
    [self.view endEditing:YES];
    
    int32_t loopCnt = [self.loopCntTextField.text intValue];
    int32_t idx = (int32_t)self.TestOptionSegment.selectedSegmentIndex;
    if (loopCnt != self.loopCnt || idx != self.testOption) {
        self.loopCnt = loopCnt;
        self.testOption = (NSTestOption)idx;
        [self _startTest:loopCnt testOption:(NSTestOption)idx];
    }
    
    if (self.testOption == NSTestOptionInt) {
        
        [NSThread sleepForTimeInterval:0.1];
        [self _mmkvBatchWriteIntTest:self.loopCnt];
        
        [NSThread sleepForTimeInterval:0.1];
        [self _kvBatchWriteIntTest:self.loopCnt];
        
        [NSThread sleepForTimeInterval:0.1];
        [self _defaultBatchWriteIntTest:self.loopCnt];
    }
    else if (self.testOption == NSTestOptionDouble) {
        [NSThread sleepForTimeInterval:0.1];
        [self _mmkvBatchWriteDoubleTest:self.loopCnt];
        
        [NSThread sleepForTimeInterval:0.1];
        [self _kvBatchWriteDoubleTest:self.loopCnt];
        
        [NSThread sleepForTimeInterval:0.1];
        [self _defaultBatchWriteDoubleTest:self.loopCnt];
    }
    else if (self.testOption == NSTestOptionString) {
        [NSThread sleepForTimeInterval:0.1];
        [self _mmkvBatchWriteStringTest:self.loopCnt];
        
        [NSThread sleepForTimeInterval:0.1];
        [self _kvBatchWriteStringTest:self.loopCnt];
        
        [NSThread sleepForTimeInterval:0.1];
        [self _defaultBatchWriteStringTest:self.loopCnt];
    }
    
    NSLog(@"KV.cnt=%@,MMKV.cnt=%@",@(_kv.allEntries.count),@(_mmkv.allKeys.count));
}

- (void)_startTest:(int)loops testOption:(NSTestOption)testOption
{
    [self.strings removeAllObjects];
    [self.strKeys removeAllObjects];
    [self.intKeys removeAllObjects];
    
    
    if (testOption == NSTestOptionInt) {
        if (_ptr_integer) {
            int64_t *ptrTmp = (int64_t*)realloc(_ptr_integer, loops * sizeof(int64_t));
            if (ptrTmp == NULL) {
                free(_ptr_integer);
                _ptr_integer = NULL;
                return;
            }
            else {
                self->_ptr_integer = ptrTmp;
            }
        }
        
        if (_ptr_integer == NULL) {
            _ptr_integer = (int64_t*)calloc(loops, sizeof(int64_t));
            if (_ptr_integer == NULL) {
                return;
            }
        }
        
        
        for (int32_t index = 0; index < loops; index++) {
            NSString *intKey = [NSString stringWithFormat:@"%d", index];
            [self.intKeys addObject:intKey];
            
            _ptr_integer[index] = arc4random() * arc4random();
        }
    }
    else if (testOption == NSTestOptionDouble) {
        if (_ptr_double) {
            CGFloat *ptrTmp = (CGFloat*)realloc(self->_ptr_double, loops * sizeof(CGFloat));
            if (ptrTmp == NULL) {
                free(_ptr_double);
                _ptr_double = NULL;
                return;
            }
            else {
                self->_ptr_double = ptrTmp;
            }
        }
        
        if (_ptr_double == NULL) {
            _ptr_double = (CGFloat*)calloc(loops, sizeof(CGFloat));
            if (_ptr_double == NULL) {
                return;
            }
        }
        
        for (int32_t index = 0; index < loops; index++) {
            NSString *doubleKeys = [NSString stringWithFormat:@"double-%d", index];
            [self.doubleKeys addObject:doubleKeys];
            
            _ptr_double[index] = drand48() * arc4random() * arc4random();
        }
    }
    else if (testOption == NSTestOptionString) {
        for (int32_t index = 0; index < loops; index++) {
            NSString *str = [NSString stringWithFormat:@"%s-%d", __FILE__, index];
            [self.strings addObject:str];
            
            NSString *strKey = [NSString stringWithFormat:@"str-%d", index];
            [self.strKeys addObject:strKey];
        }
    }
}

- (void)_kvBatchWriteIntTest:(int32_t)loops
{
    NSLog(@"kv write int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            int64_t tmp = self->_ptr_integer[index];
            NSString *intKey = self.intKeys[index];
            [self.kv setInteger:tmp forKey:intKey];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}

- (void)_mmkvBatchWriteIntTest:(int32_t)loops
{
    NSLog(@"mmkv write int %d times, cost:", loops);
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            int64_t tmp = self->_ptr_integer[index];
            NSString *intKey = self.intKeys[index];
            [self.mmkv setInt64:tmp forKey:intKey];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}


- (void)_defaultBatchWriteIntTest:(int32_t)loops
{
    NSLog(@"default write int %d times, cost:", loops);
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            int64_t tmp = self->_ptr_integer[index];
            NSString *intKey = self.intKeys[index];
            [[NSUserDefaults standardUserDefaults] setInteger:tmp forKey:intKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagUserDefault];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}

- (void)_kvBatchReadIntTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"kv read int %d times, cost:", loops);

    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        
        for (int index = 0; index < loops; index++) {
            @autoreleasepool {
                NSString *intKey = self.intKeys[index];
//                int64_t OKVal = _ptr_integer[index];
                int64_t val = [self.kv getIntegerForKey:intKey];
//                if (val != OKVal) {
//                    self.otherInfoView.text = NEW_STRING_WITH_FORMAT(@"出现读取错误idx:%d val:%@,readVal=%@,", index,@(OKVal),@(val));
//                    break;
//                }
            }
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (void)_mmkvBatchReadIntTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"mmkv read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        
        for (int index = 0; index < loops; index++) {
            @autoreleasepool {
                NSString *intKey = self.intKeys[index];
//                int64_t OKVal = _ptr_integer[index];
                int64_t val = [self.mmkv getInt64ForKey:intKey];
//                if (val != OKVal) {
//                    self.otherInfoView.text = NEW_STRING_WITH_FORMAT(@"出现读取错误idx:%d val:%@,readVal=%@,", index,@(OKVal),@(val));
//                    break;
//                }
            }
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (void)_defaultBatchReadIntTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"default read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *intKey = self.intKeys[index];
            int64_t val = (int64_t)[[NSUserDefaults standardUserDefaults] integerForKey:intKey];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagUserDefault];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}


//double
- (void)_kvBatchWriteDoubleTest:(int32_t)loops
{
    NSLog(@"kv write int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            double tmp = self->_ptr_double[index];
            NSString *doubleKey = self.doubleKeys[index];
            [self.kv setDouble:tmp forKey:doubleKey];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}

- (void)_mmkvBatchWriteDoubleTest:(int32_t)loops
{
    NSLog(@"mmkv write int %d times, cost:", loops);
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            double tmp = self->_ptr_double[index];
            NSString *doubleKey = self.doubleKeys[index];
            [self.mmkv setDouble:tmp forKey:doubleKey];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}


- (void)_defaultBatchWriteDoubleTest:(int32_t)loops
{
    NSLog(@"default write int %d times, cost:", loops);
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            double tmp = self->_ptr_double[index];
            NSString *doubleKey = self.doubleKeys[index];
            [[NSUserDefaults standardUserDefaults] setDouble:tmp forKey:doubleKey];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagUserDefault];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}

- (void)_kvBatchReadDoubleTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"kv read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        
        for (int index = 0; index < loops; index++) {
            @autoreleasepool {
                NSString *key = self.doubleKeys[index];
                double val = [self.kv getDoubleForKey:key];
            }
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (void)_mmkvBatchReadDoubleTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"mmkv read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        
        for (int index = 0; index < loops; index++) {
            @autoreleasepool {
                NSString *key = self.doubleKeys[index];
                double val = [self.mmkv getDoubleForKey:key];
            }
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (void)_defaultBatchReadDoubleTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"default read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *key = self.doubleKeys[index];
            int64_t val = (int64_t)[[NSUserDefaults standardUserDefaults] doubleForKey:key];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagUserDefault];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}


//string
- (void)_kvBatchWriteStringTest:(int32_t)loops
{
    NSLog(@"kv write int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *tmp = self.strings[index];
            NSString *key = self.strKeys[index];
            [self.kv setObject:tmp forKey:key];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}

- (void)_mmkvBatchWriteStringTest:(int32_t)loops
{
    NSLog(@"mmkv write int %d times, cost:", loops);
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *tmp = self.strings[index];
            NSString *key = self.strKeys[index];
            [self.mmkv setObject:tmp forKey:key];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}


- (void)_defaultBatchWriteStringTest:(int32_t)loops
{
    NSLog(@"default write int %d times, cost:", loops);
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *tmp = self.strings[index];
            NSString *key = self.strKeys[index];
            [[NSUserDefaults standardUserDefaults] setObject:tmp forKey:key];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagUserDefault];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagWrite];
    [self.excelView reloadData];
}

- (void)_kvBatchReadStringTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"kv read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *key = self.strKeys[index];
            NSString *val = [self.kv getObjectForKey:key];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (void)_mmkvBatchReadStringTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"mmkv read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        
        for (int index = 0; index < loops; index++) {
            NSString *key = self.strKeys[index];
            [self.mmkv getObjectOfClass:[NSString class] forKey:key];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (void)_defaultBatchReadStringTest:(int32_t)loops
{
    if (_ptr_integer == NULL) {
        return;
    }
    NSLog(@"default read int %d times, cost:", loops);
    
    CGFloat t = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        for (int index = 0; index < loops; index++) {
            NSString *key = self.strKeys[index];
            int64_t val = (int64_t)[[NSUserDefaults standardUserDefaults] objectForKey:key];
        }
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagUserDefault];
    [row setObject:[self _textFromTime:t] atIndexedSubscript:NSExcelColumnTagRead];
    [self.excelView reloadData];
}

- (IBAction)_clearAction:(UIButton *)sender {
    
    CGFloat t1 = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        [self.kv clear:YES];
    }];
    
    [NSThread sleepForTimeInterval:1];
    
    CGFloat t2 = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        [self.mmkv clearAll];
    }];
    
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t1] atIndexedSubscript:NSExcelColumnTagClear];
    
    row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t2] atIndexedSubscript:NSExcelColumnTagClear];

    
    [self.excelView reloadData];
    
}

- (IBAction)_deleteAction:(UIButton *)sender {
    NSArray *mmkvKeys = [self.mmkv allKeys];
    
    NSArray *kvKeys = [[self.kv allEntries] allKeys];
    
    CGFloat t1 = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        [kvKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.kv removeObjectForKey:obj];
        }];
    }];
    
    [NSThread sleepForTimeInterval:1];
    
    CGFloat t2 = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        [mmkvKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.mmkv removeValueForKey:obj];
        }];
    }];
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t1] atIndexedSubscript:NSExcelColumnTagDelete];
    
    row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t2] atIndexedSubscript:NSExcelColumnTagDelete];
    
    
    [self.excelView reloadData];
    
    
}

- (IBAction)_updateCryptKeyAction:(UIButton *)sender {
    
    NSData *cryptKey = [self.cryptKeyString dataUsingEncoding:NSUTF8StringEncoding];
    
    __block BOOL OK = YES;
    CGFloat t1 = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        OK = [self.mmkv reKey:cryptKey];
    }];
    NSLog(@"OK=%@",@(OK));
    
    [NSThread sleepForTimeInterval:1];
    CGFloat t2 = [YZHMachTimeUtils elapsedMSTimeInBlock:^{
        [self.kv updateCryptKey:cryptKey];
    }];
    
    
    NSMutableArray *row = [self.excelData objectAtIndex:NSExcelRowTagMMKV];
    [row setObject:[self _textFromTime:t1] atIndexedSubscript:NSExcelColumnTagUpdateCryptKey];
    
    row = [self.excelData objectAtIndex:NSExcelRowTagYZHKV];
    [row setObject:[self _textFromTime:t2] atIndexedSubscript:NSExcelColumnTagUpdateCryptKey];
    
    
    [self.excelView reloadData];

}




































- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}


- (void)dealloc
{
    self->_cryptor.reset();
    if (_ptr_double) {
        free(_ptr_double);
        _ptr_double = NULL;
    }
    if (_ptr_integer) {
        free(_ptr_integer);
        _ptr_integer = NULL;
    }
}


@end
