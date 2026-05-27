//
//  BXOtaLibrary.h
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "YFXBluetoothManager.h"
NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    Firmware = 0, //硬件升级
    Material,//表盘升级
    wordBook,//单词本升级
    customDial//自定义表盘
}otaType;

typedef enum : NSUInteger {
    Reset = 0, //重启
    Shutdown,//关机
    ResetToApp//重启并进入APP
}exitType;


@protocol OTADelegate <NSObject>

- (void)onFinishWithTime:(int)second;
- (void)onInitialError:(NSString *)error;
- (void)otaWithIndex:(int)index AndFileSize:(float) filesize AndRate:(float)rate;
- (void)otaWithTotalFileSize:(float) filesize AndRate:(float)rate;
- (void)launchRecoverySuccess;
@end


@interface BXOtaLibrary : NSObject

@property (strong, nonatomic) NSDictionary * jsonDic;
@property (strong, nonatomic) NSDictionary * customDialDic;
@property(nonatomic,strong)id<OTADelegate>delegate;


+ (instancetype)shareBXOtaLibrary;

-(void)setAutoOTA:(BOOL)isAuto;
-(BOOL)getisAutomaticOTA;
-(void)setMaxWithoutResponse:(int)maxNumber;
-(void)getData:(NSData *)data;
//设置自定义表盘文字位置
-(void)setCustomDialDigitalClockPosition:(CGPoint)point;
//开始升级
-(void)startOtaWithPeripheral:(CBPeripheral *) cp AndOtaType:(otaType)type AndMac:(NSString *) mac;

-(void)OtaStart;
//获取缓存内的升级文件
-(void)getFile;
//传输bin文件
-(void)startOtaWithBin;
//判断是否是最后一个bin文件，如果是则exit，如果不是则发送下一个bin文件
-(void)judgeCompleted;

//完成升级
-(void)otaFinish;
//失败原因
-(void)FailErrer:(NSString *) err;

//当前文件进度
- (void)otaWithFileSize:(float)filesize AndRate:(float)rate;

//获取当前升级类型
-(otaType)getOtaType;


//非自动模式进入OTA，launchRecoverySuccess需要用户自己断开连接。
-(void)nonautomaticOTALaunchRecoverySuccess;
//bin文件或者表盘、单词本升级数据传输完毕调用
-(void)transferEnd;

//获取自定义表盘的image
-(void)getImage:(UIImage *) image AndParams:(NSDictionary *) params;
//重启 、关机 、重启并进入APP。
-(void)exitWithType:(exitType)exitType;
-(void)setTotalFileSize:(int)totalSize;
@end

NS_ASSUME_NONNULL_END
