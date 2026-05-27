//
//  YFXBluetoothManager.h
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define kServiceUUID               @"0000EE00-D102-E111-9B23-00025B00A5C7" //设备服务的UUID
#define kCommandCharacteristicUUID  @"0000EE01-D102-E111-9B23-00025B00A5C7"
#define kDataCharacteristicUUID   @"0000EE02-D102-E111-9B23-00025B00A5C7"

//0-未知 1-重置中 2-不支持 3-非法 4-关闭 5-开启 6-连接失败 7-连接成功
typedef enum : NSUInteger {
    Unknown = 0,
    Resetting,
    Unsupported,
    Unauthorized,
    PoweredOff,
    PoweredOn,
    Fail,
    Connect
}blueToolState;//0-5跟系统蓝牙状态相同

@protocol YFXBluetoothManagerDelegate <NSObject>


@optional


- (void)updateDevices:(NSArray *)devices; //搜索到设备回调
- (void)revicedMessage:(NSData *)msg Characteristic:(CBCharacteristic *)characteristic;     //接受到数据回调
- (void)updateStatue:(blueToolState)state;//蓝牙状态改变回调
- (void)readyForBlue;//准备完毕
- (void)revicedMessageWithCBPeripheral:(CBPeripheral *)peripheral;//收到信息是从哪个设备获取的
@end

@interface YFXBluetoothManager : NSObject

@property (weak, nonatomic) id<YFXBluetoothManagerDelegate> delegate;

/*
 *  单例
 *
 *  @return YFXBluetoothManager
 */
+ (instancetype)shareBLEManager;
/*
 *  获取蓝牙状态
 */
- (blueToolState)getBLEStatue;

/**
 *  查找设备
 */
- (void)scanDevice;

- (CBPeripheral *)getTheDevice;
/**
 *  停止查找设备
 */
- (void)stopScanDevice;
/**
 *  连接设备
 */
- (void)connectDeviceWithCBPeripheral:(CBPeripheral *)peripheral;
/**
 *  断开连接
 */
- (void)disconnectDevice;

-(void)setRepeatOTAModel:(BOOL)isOta;

/**
 *  发送消息
 *
 *  @param msg  消息
 */
- (void)sendMsg:(NSData* )msg;

- (void)setMac:(NSString* )mac;

- (void)sendMsgWithoutResponse:(NSData* )msg;

- (void)repeatConnectDevice;

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral;

-(CBCharacteristic *) getCharFromPeripheral:(CBPeripheral *)peripheral serviceUuidString:(NSString *)serviceUuidString charUuidString:(NSString *)charUuidString;

- (NSArray *)bleGetPeripheralsWithIdentifiers:(NSArray *)uuids;
- (NSArray *)bleGetConnectedPeripheralsWithIdentifiers:(NSArray *)uuids;
-(CBCentralManager *) bleCentralManager;

- (void)stopTimer;
@end
