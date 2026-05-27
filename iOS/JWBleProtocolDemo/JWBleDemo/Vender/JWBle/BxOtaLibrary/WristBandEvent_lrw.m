//
//  WristBandEvent_lrw.h
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
//  用于接受消息处理

#import "WristBandEvent_lrw.h"
#import "WristBandCmd_lrw.h"
#import "YFXBluetoothManager.h"
#import "BXOtaLibrary.h"
#define RSP_SIZE (3)
@interface WristBandEvent_lrw()
@property (nonatomic, strong) NSMutableData *nData;
@property (nonatomic) UInt16    nextRxDataBytes;
@property (nonatomic) UInt16    rxSequenceID;
@property (nonatomic, copy) NSString * verifyStr;

@property (strong, nonatomic) NSMutableArray *observers;

@end

@implementation WristBandEvent_lrw
+ (id)getShareInstance
{
    static WristBandEvent_lrw *sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        _nextRxDataBytes = 0;
        _nData = [[NSMutableData alloc]init];
        _observers = [[NSMutableArray alloc]init];
        _verifyStr = @"";
    }
    return self;
}

- (void)wbExceptionHandler
{
    _nextRxDataBytes = 0;
}

static bool isReadyForSuccess = NO;
-(void) wbProcessNotifyData:(NSData *)data
{
    Byte *notifyBytes = (Byte *)data.bytes;
    NSString *hexStr = @"";
    if (data.length < RSP_SIZE) {
        JWNSLog(@"CHECK RSP FAIL");
        return;
    }

    for(int i=0;i<data.length;i++)
    {
        NSString *newHexStr = [NSString stringWithFormat:@"%x",notifyBytes[i]&0xff];//16进制数
        if([newHexStr length]==1){
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        }else{
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
        }
    }
    //过滤3字节重复指令
    if (hexStr.length == 6 && [_verifyStr isEqualToString:hexStr]){
        JWNSLog(@"REPEAT INSTRUCTION");
        return;
    }
    _verifyStr = hexStr;
    
    JWNSLog(@"收到的信息：%@",hexStr);
    NSString * code = [hexStr substringToIndex:4];
    NSString * status = [hexStr substringFromIndex:4];
    
    [[YFXBluetoothManager shareBLEManager] stopTimer];

    if([code isEqualToString:@"0080"]){
        [self transferStartWithStatus:status];
    }else if ([code isEqualToString:@"0180"]){
        [self transferEndWithStatus:status];
    }else if ([code isEqualToString:@"0280"]){
        [self checkRecoveryWithStatus:status];
    }else if ([code isEqualToString:@"0380"]){
        [self launchRecoveryWithStatus:status];
    }else if ([code isEqualToString:@"0480"]){
        [self exitWithStatus:status];
    }else if ([code isEqualToString:@"0580"]){
        [self timeStampWithStatus:status];
    }else if ([code isEqualToString:@"0780"]){
        [self assetUpdateWithStatus:status];
    }else if ([code isEqualToString:@"0880"]){
        if(isReadyForSuccess){
            [self assetUpdateEndWithStatus:status];
        }
    }
    return;
}

-(void)checkRecoveryWithStatus:(NSString *) status{
    if ([status isEqualToString:@"00"]){
        //处于recovery模式
        JWNSLog(@"checkRecoverySuccess");
        switch ([[BXOtaLibrary shareBXOtaLibrary] getOtaType]) {
            case Firmware://继续升级
                [[BXOtaLibrary shareBXOtaLibrary] getFile];
                break;
            case Material://退出recovery模式
                [[WristBandCmd_lrw getShareInstance] launchRecovery];
                break;
            case wordBook://退出recovery模式
                [[WristBandCmd_lrw getShareInstance] launchRecovery];
                break;
            case customDial://退出recovery模式
                [[WristBandCmd_lrw getShareInstance] launchRecovery];
                break;
            default:
                break;
        }
       
    }else{
        switch ([[BXOtaLibrary shareBXOtaLibrary] getOtaType]) {
            case Firmware://未处于recovery模式，进入recovery模式
                [[YFXBluetoothManager shareBLEManager] setRepeatOTAModel:YES];
                [[WristBandCmd_lrw getShareInstance] launchRecovery];
                break;
            case Material://继续升级
                [[BXOtaLibrary shareBXOtaLibrary] getFile];
                break;
            case wordBook://继续升级
                [[BXOtaLibrary shareBXOtaLibrary] getFile];
                break;
            case customDial://继续升级
                [[BXOtaLibrary shareBXOtaLibrary] getFile];
                break;
            default:
                break;
        }
    }
}

-(void)launchRecoveryWithStatus:(NSString *)status{
    if ([status isEqualToString:@"00"]) {
        //进入recovery模式成功
        JWNSLog(@"launchRecoverySuccess");
        if ([[BXOtaLibrary shareBXOtaLibrary] getisAutomaticOTA]){
            [[YFXBluetoothManager shareBLEManager] repeatConnectDevice];
        }else{
            [[BXOtaLibrary shareBXOtaLibrary]nonautomaticOTALaunchRecoverySuccess];
        }
    }else{
        JWNSLog(@"launchRecoveryFail");
        //进入recovery模式失败
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"launchRecoveryFail"];
    }
}

-(void)transferStartWithStatus:(NSString *) status{
    if ([status isEqualToString:@"00"]){
        JWNSLog(@"transferStartSuccess");
        [[BXOtaLibrary shareBXOtaLibrary] startOtaWithBin];
    }else{
        JWNSLog(@"transferStartFail");
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"transferStartFail"];
    }
}

-(void)transferEndWithStatus:(NSString *) status{
    if ([status isEqualToString:@"00"]){
        JWNSLog(@"transferEndSuccess");
        [[BXOtaLibrary shareBXOtaLibrary] judgeCompleted];
    }else{
        JWNSLog(@"transferEndFail");
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"transferEndFail"];
    }
    
}

-(void)exitWithStatus:(NSString *) status{
    if ([status isEqualToString:@"00"]){
        JWNSLog(@"ExitSuccess");
        switch ([[BXOtaLibrary shareBXOtaLibrary] getOtaType]) {
            case Firmware://升级完成
//                [[BXOtaLibrary shareBXOtaLibrary] otaFinish];
                break;
            case Material://退出recovery模式
//                [[YFXBluetoothManager shareBLEManager] repeatConnectDevice];
                break;
            case wordBook://退出recovery模式
//                [[YFXBluetoothManager shareBLEManager] repeatConnectDevice];
                break;
            case customDial://退出recovery模式
//                [[YFXBluetoothManager shareBLEManager] repeatConnectDevice];
                break;
            default:
                break;
        }
    }else{
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"exitFail"];
    }
}
-(void)timeStampWithStatus:(NSString *) status{
    
    
}

-(void)assetUpdateWithStatus:(NSString *) status{
    if ([status isEqualToString:@"00"]){
        isReadyForSuccess = YES;
        [[BXOtaLibrary shareBXOtaLibrary] startOtaWithBin];
    }else if ([status isEqualToString:@"01"]){
        JWNSLog(@"The device does not support this type");
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"The device does not support this type"];
    }else if ([status isEqualToString:@"02"]){
        JWNSLog(@"Not enough space");
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"Not enough space"];
    }
    
}

-(void)assetUpdateEndWithStatus:(NSString *) status{
    if ([status isEqualToString:@"00"]){
        JWNSLog(@"ExitSuccess");
        [[BXOtaLibrary shareBXOtaLibrary] otaFinish];
        isReadyForSuccess = NO;
    }else{
        JWNSLog(@"ExitFail");
        [[BXOtaLibrary shareBXOtaLibrary]FailErrer:@"assetUpdateEndFail"];
    }
}





@end
