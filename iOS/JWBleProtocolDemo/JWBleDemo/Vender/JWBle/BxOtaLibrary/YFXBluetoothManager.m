//
//  YFXBluetoothManager.m
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
// 

#import "YFXBluetoothManager.h"
#import "AppDelegate.h"
#import "WristBandEvent_lrw.h"
#import "WristBandCmd_lrw.h"
#import "BXOtaLibrary.h"

@interface YFXBluetoothManager()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, assign) blueToolState bleStatue;
@property (nonatomic, strong) CBCentralManager * centralManager;//蓝牙管理
@property (nonatomic, strong) CBPeripheral     *peripheral;//连接的设备信息
@property (nonatomic, strong) NSMutableArray   *mPeripherals;//找到的设备
@property (nonatomic, strong) NSMutableArray   *mDevices;//找到的设备带rssi
@property (nonatomic, strong) NSMutableArray   *sendDatas;
@property (nonatomic, strong) NSString   * macAddress;
@property (nonatomic, strong) CBService *service;//当前服务
@property (nonatomic, strong) CBCharacteristic *commandChar;//
@property (nonatomic, strong) CBCharacteristic *dataChar;//
@property(strong,nonatomic) NSTimer *timer;
@property (nonatomic, assign) BOOL isRepeatOTA;//
@property (nonatomic, strong) NSTimer *mTimer;
@end

@implementation YFXBluetoothManager

static YFXBluetoothManager *_manager = nil;

+ (instancetype)shareBLEManager{

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
       
        _manager = [[YFXBluetoothManager alloc]init];
        _manager.bleStatue = Unknown;
        _manager.isRepeatOTA = NO;
        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],CBCentralManagerOptionShowPowerAlertKey,nil];
        _manager.centralManager = [[CBCentralManager alloc] initWithDelegate:_manager queue:dispatch_get_main_queue() options:options];
    });
    return _manager;
}
/**
 *  获取蓝牙状态
 */
- (blueToolState)getBLEStatue{
    return _manager.bleStatue;
}

- (void)setMac:(NSString* )mac{
    _macAddress = mac;
}
/**
 *  手机蓝牙状态
 */
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    [_manager updateBLEStatue:(int)central.state];
}
/**
 *  查找设备
 */
- (void)scanDevice{
    _manager.mPeripherals = [[NSMutableArray alloc] init];//搜索到的设备集合
    _manager.mDevices = [[NSMutableArray alloc] init];
    if(_manager.centralManager.state == CBManagerStatePoweredOn){
//        [_manager.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:SERVICE_WRISTBAND]] options:nil];
        [_manager.centralManager scanForPeripheralsWithServices:nil options:nil];
        [_manager updateBLEStatue:PoweredOn];
    }else{
        [_manager updateBLEStatue:(int)_manager.centralManager.state];
    }
}

/**
 *  找到设备
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    //数组containsObject 包含方法 判断一个元素是否在数组中
    NSData *data = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    NSString * facturer =  [self transformCharateristicValueFromData:data];
    
    if (_isRepeatOTA){
        if (facturer.length > 12){
//            JWNSLog(@"_macAddress: %@ \t facturer:%@ \t data:%@",_macAddress ,facturer, data);
            
            NSString * mac = [_macAddress stringByReplacingOccurrencesOfString:@":" withString:@""]; // 去掉空格
            if ([facturer.uppercaseString containsString:mac.uppercaseString]){
                JWNSLog(@"搜到设备，去连接：\n _macAddress: %@ \t facturer:%@ \t data:%@",_macAddress ,facturer, data);
                [self connectDeviceWithCBPeripheral:peripheral];
            }
        }
    }
}

/**
 *  停止查找设备
 */
- (void)stopScanDevice{
    JWNSLog(@"%s", __FUNCTION__);
    if (_manager.centralManager) {
        [_centralManager stopScan];
    }
}
/**
 *  连接设备
 */
- (void)connectDeviceWithCBPeripheral:(CBPeripheral *)peripheral{
    JWNSLog(@"%s", __FUNCTION__);
    _manager.peripheral = peripheral;
    _manager.peripheral.delegate = _manager;
    _manager.centralManager.delegate = _manager;
    [_manager.peripheral discoverServices:nil];
    [_manager updateBLEStatue:Connect];
    [_manager.centralManager connectPeripheral:peripheral options:nil];
    
}
/**
 *  接收断开连接状态
 */
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    JWNSLog(@"%s", __FUNCTION__);
    [_manager updateBLEStatue:(int)central.state];
}

-(void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error{
    if(!error) {
 
    }
}
/**
 * 连接成功
 */
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    JWNSLog(@"%s", __FUNCTION__);

    if (!_manager.centralManager) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],CBCentralManagerOptionShowPowerAlertKey,nil];
        _manager.centralManager = [[CBCentralManager alloc] initWithDelegate:_manager queue:dispatch_get_main_queue() options:options];
    }
    [_manager.centralManager stopScan];
    _manager.peripheral = peripheral;
    _manager.peripheral.delegate = _manager;
    _manager.centralManager.delegate = _manager;
    [_manager.peripheral discoverServices:nil];
    [_manager updateBLEStatue:Connect];
    CBService * otaService = [self findOtaServicesWithTarget:peripheral];
    if (otaService == nil){
        [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
    }else{
        [self findOtaCharacteristicsWithTarget:peripheral AndOtaService:otaService];
    }
    
}

/**
 * 失败
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    JWNSLog(@"%s", __FUNCTION__);
    [_manager updateBLEStatue:Fail];
}
/**
 * 发现服务
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error) {
        return;
    }
    for (CBService *service in peripheral.services) {
        _manager.service = service;
       [peripheral discoverCharacteristics:nil forService:service];
    }
}
/**
 * 发现特征
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
  
    if (error) {
        return;
    }
   
    for (CBCharacteristic *c in service.characteristics)
    {
        [peripheral setNotifyValue:YES forCharacteristic:c];
        [peripheral readValueForCharacteristic:c];
        if ([c.UUID.UUIDString isEqualToString:kDataCharacteristicUUID]){
            _dataChar = c;
        }
        if ([c.UUID.UUIDString isEqualToString:kCommandCharacteristicUUID]){
            _commandChar = c;
            [peripheral readValueForCharacteristic:c];
            if (_isRepeatOTA){
                [[WristBandCmd_lrw getShareInstance] checkRecoveryMode];
                _isRepeatOTA = NO;
            }
        }
    }
}

#pragma mark - 蓝牙断开

/**
 *  断开连接
 */
- (void)disconnectDevice{    
    JWNSLog(@"%s", __FUNCTION__);
    if (_manager.peripheral) {
        [_manager.centralManager cancelPeripheralConnection:_manager.peripheral];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self scanDevice];
        });
    }
}

- (void)discoverANCS:(CBPeripheral *)peripheral{
    [self centralManager:_centralManager didDiscoverPeripheral:peripheral advertisementData: [NSDictionary dictionary] RSSI:@(0)];
}

#pragma mark - 发送及接收消息
/**
 *  发送消息
 *
 *  @param msg  消息
 */
- (void)sendMsg:(NSData* )msg{
    if (msg) {
        if (self.bleStatue==Connect && _commandChar.properties) {
//            JWNSLog(@"发送数据：%@",msg);
            [_manager.peripheral writeValue:msg forCharacteristic:_commandChar type:CBCharacteristicWriteWithResponse];
            _mTimer = [NSTimer scheduledTimerWithTimeInterval:4
                                                           target:self
                                                     selector:@selector(sendError:)
                                                         userInfo:nil
                                                          repeats:YES];
        }
    }
}




- (void)sendError:(NSTimer *)timer
{
    [[BXOtaLibrary shareBXOtaLibrary] FailErrer:@"升级超时"];
    [self disconnectDevice];
    if ([_mTimer isValid]) {
        [_mTimer invalidate];
        _mTimer = nil;
    }
}
- (void)stopTimer{
    if ([_mTimer isValid]) {
        [_mTimer invalidate];
        _mTimer = nil;
    }
}

static float otaFileSize = 0.0;
- (void)sendMsgWithoutResponse:(NSData* )msg{
    if (msg) {
        if (self.bleStatue==Connect && _dataChar.properties) {
            int maxWithoutResponse = (int) [_manager.peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
            JWNSLog(@"maxWithoutResponse:%d",maxWithoutResponse);
            [[BXOtaLibrary shareBXOtaLibrary] setTotalFileSize:maxWithoutResponse];
//            [[BXOtaLibrary shareBXOtaLibrary]setMaxWithoutResponse:maxWithoutResponse];
            if (maxWithoutResponse >= [msg length]){
//                JWNSLog(@"发送数据：%@",msg);
//                JWNSLog(@"sendMsgWithoutResponse发送数据的uuid：%@",_dataChar.UUID.UUIDString);
                [_manager.peripheral writeValue:msg forCharacteristic:_dataChar type:CBCharacteristicWriteWithoutResponse];
                [[BXOtaLibrary shareBXOtaLibrary] transferEnd];
            }else{
                _manager.sendDatas = [[NSMutableArray alloc] init];
                for (int i = 0; i <= [msg length]; i+=maxWithoutResponse)
                {
                    if (i+maxWithoutResponse<[msg length]) {
                        NSString *rangeStr = [NSString stringWithFormat:@"%i,%i",i,maxWithoutResponse];
                        NSData *subData = [msg subdataWithRange:NSRangeFromString(rangeStr)];
                        [_manager.sendDatas addObject:subData];
                    }else{
                        int lastNumber = (int)fmod([msg length],maxWithoutResponse);
                        if (lastNumber != 0){
                            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i",i,lastNumber];
                            NSData *subData = [msg subdataWithRange:NSRangeFromString(rangeStr)];
                            [_manager.sendDatas addObject:subData];
                        }else{
                            NSString *rangeStr = [NSString stringWithFormat:@"%i,%i",i,maxWithoutResponse];
                            NSData *subData = [msg subdataWithRange:NSRangeFromString(rangeStr)];
                            [_manager.sendDatas addObject:subData];
                        }
                        otaFileSize = (float)_manager.sendDatas.count;
                        [self transferSegment];
                        return;

                    }
                }
            }
        }
    }
}

- (void)transferSegment{
    if (_manager.sendDatas.count > 0){
        NSData * data =  _manager.sendDatas.firstObject;
        [_manager.sendDatas removeObjectAtIndex:0];
      
        if (self.bleStatue==Connect && _dataChar.properties) {
            [[BXOtaLibrary shareBXOtaLibrary]otaWithFileSize:otaFileSize AndRate:otaFileSize-(float)_manager.sendDatas.count];
//           JWNSLog(@"发送数据：%@",data);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                [_manager.peripheral writeValue:data forCharacteristic:self->_dataChar type:CBCharacteristicWriteWithoutResponse];
            });
        }
        if (_manager.sendDatas.count == 0 ){
            [[BXOtaLibrary shareBXOtaLibrary] transferEnd];
        }
    }
}

-(void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral{
    [self transferSegment];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
  
}

-(NSString *)hexStringWithData:(NSData *)data
{
    const unsigned char* dataBuffer = (const unsigned char*)[data bytes];
    if(!dataBuffer){
        return nil;
    }
    NSUInteger dataLength = [data length];
    NSMutableString* hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for(int i = 0; i < dataLength; i++){
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    NSString* result = [NSString stringWithString:hexString];
    return result;
}
/*
 * 接收数据
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (_manager.delegate && [_manager.delegate respondsToSelector:@selector(revicedMessageWithCBPeripheral:)]) {
        [_manager.delegate revicedMessageWithCBPeripheral:peripheral];
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:kCommandCharacteristicUUID]]) {
        [[WristBandEvent_lrw getShareInstance] wbProcessNotifyData:[characteristic.value copy]];
        if (_manager.delegate && [_manager.delegate respondsToSelector:@selector(revicedMessage:Characteristic:)]) {
            
            [_manager.delegate revicedMessage:characteristic.value Characteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
    if (error) {
        return;
    }
    if ([characteristic.UUID.UUIDString isEqualToString:kCommandCharacteristicUUID]) {
        [peripheral readValueForCharacteristic:characteristic];
    }

}

#pragma mark - helper
- (void)updateBLEStatue:(blueToolState)statue{
    _manager.bleStatue = statue;
    if (_manager.delegate && [_manager.delegate respondsToSelector:@selector(updateStatue:)]) {
        [_manager.delegate updateStatue:_manager.bleStatue];
    }
}

- (CBPeripheral *)getTheDevice{
    return  self.peripheral;
}

-(BOOL)isBackground
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    BOOL result = (state == UIApplicationStateBackground);
    return result;
}

- (void)repeatConnectDevice{
    _isRepeatOTA = YES;
    JWNSLog(@"%s", __FUNCTION__);
    [self disconnectDevice];
}

-(void)setRepeatOTAModel:(BOOL)isOta{
    _isRepeatOTA = isOta;
}

- (CBCharacteristic *)getCharFromPeripheral:(CBPeripheral *)peripheral serviceUuidString:(NSString *)serviceUuidString charUuidString:(NSString *)charUuidString {
    if (peripheral.services) {
        for (CBService *service in peripheral.services) {
            if ([service.UUID isEqual:[CBUUID UUIDWithString:serviceUuidString]]) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:charUuidString]]) {
                        return characteristic;
                    }
                }
            }
        }
    }
    return nil;
}

- (NSArray *)bleGetPeripheralsWithIdentifiers:(NSArray *)uuids {
    return [_manager.centralManager retrievePeripheralsWithIdentifiers:uuids];
}

- (NSArray *)bleGetConnectedPeripheralsWithIdentifiers:(NSArray *)uuids {
    return [_manager.centralManager retrieveConnectedPeripheralsWithServices:uuids];
}

-(CBService *)findOtaServicesWithTarget:(CBPeripheral *)target{
    NSArray * services = target.services;
    CBService * otaService = nil;
    for (CBService *service in services) {
        if ([service.UUID.UUIDString isEqualToString:kServiceUUID]){
            otaService = service;
            break;
        }
    }
    return otaService;
}

-(void)findOtaCharacteristicsWithTarget:(CBPeripheral *)target AndOtaService:(CBService *) otaService{
    NSArray * characteristics = otaService.characteristics;
    for (CBCharacteristic * characteristic in characteristics) {
        if([characteristic.UUID.UUIDString isEqualToString:kCommandCharacteristicUUID]){
            _commandChar = characteristic;
            [_manager.peripheral readValueForCharacteristic:characteristic];
        }else if([characteristic.UUID.UUIDString isEqualToString: kDataCharacteristicUUID]){
            _dataChar = characteristic;
        }
    }
    if (_commandChar == nil ||_dataChar == nil){
        [target discoverCharacteristics:@[_commandChar.UUID , _dataChar.UUID] forService:otaService];
    }else{
        NSArray * arr = _commandChar.descriptors;
        if(arr.count == 0 ){
            [target discoverDescriptorsForCharacteristic:_commandChar];
        }else{
            [target setNotifyValue:YES forCharacteristic:_commandChar];
        }
    }
}


-(CBCentralManager *) bleCentralManager {
    
    if (!_manager.centralManager) {
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],CBCentralManagerOptionShowPowerAlertKey,nil];
        _manager.centralManager = [[CBCentralManager alloc] initWithDelegate:_manager queue:dispatch_get_main_queue() options:options];
        return _manager.centralManager;
    }
    return _manager.centralManager;
}


-(NSString *)transformCharateristicValueFromData:(NSData *)dataValue{
    if (!dataValue || [dataValue length] == 0) {
        return @"";
    }
    NSMutableString *destStr = [[NSMutableString alloc]initWithCapacity:[dataValue length]];

    [dataValue enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
        unsigned char *dataBytes = (unsigned char *)bytes;
        for (int i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x",(dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [destStr appendString:hexStr];
            }else{
                [destStr appendFormat:@"0%@",hexStr];
            }
        }
    }];
    return destStr;
}

- (NSString *)dealWithString:(NSString *)text
{
    NSString *doneTitle = @"";

    int count = 0;

    for (int i = 0; i < text.length; i++) {

        count++;

        doneTitle = [doneTitle stringByAppendingString:[text substringWithRange:NSMakeRange(i, 1)]];

        if (count == 2) {
            doneTitle = [NSString stringWithFormat:@"%@:", doneTitle];//这个位置%@后面需要加一个空格哦
            count = 0;
        }
    }
    
    if (doneTitle.length > 1){
        doneTitle = [doneTitle substringToIndex:doneTitle.length - 1];
    }
    return doneTitle;
}

@end
 
