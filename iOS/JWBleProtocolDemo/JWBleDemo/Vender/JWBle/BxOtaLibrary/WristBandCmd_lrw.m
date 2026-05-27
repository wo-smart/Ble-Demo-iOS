//
//  WristBandCmd.h
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
//  用于编辑命令

#import "WristBandCmd_lrw.h"
#import "YFXBluetoothManager.h"

@implementation WristBandCmd_lrw

+ (id)getShareInstance {
    static WristBandCmd_lrw *sharedInstance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {

        //  _txObj = [SerialDataTxObj shareInstance];
    }
    return self;
}

- (void)checkRecoveryMode {
    UInt8 l1Packet[2] = {0x02, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:l1Packet length:2];
    [[YFXBluetoothManager shareBLEManager] sendMsg:data];
}

-(void)transferStartWithId:(UInt8)fileId fileSize:(UInt32) filesize crc32:(UInt32) crc32 {
    NSMutableData *cmdData = [[NSMutableData alloc] init];
    [cmdData appendData:[self bytesFromUInt16:0]];
    [cmdData appendData:[self byteFromUInt8:fileId]];
    [cmdData appendData:[self bytesFromUInt32:filesize]];
    [cmdData appendData:[self bytesFromUInt32:crc32]];
    [[YFXBluetoothManager shareBLEManager] sendMsg:cmdData];
}

-(void)assetUpdateReqWithType:(UInt8)type fileSize:(UInt32) filesize crc32:(UInt32) crc32{
    NSMutableData *cmdData = [[NSMutableData alloc] init];
    [cmdData appendData:[self bytesFromUInt16:7]];
    [cmdData appendData:[self byteFromUInt8:type]];
    [cmdData appendData:[self bytesFromUInt32:filesize]];
    [cmdData appendData:[self bytesFromUInt32:crc32]];
    [[YFXBluetoothManager shareBLEManager] sendMsg:cmdData];
}

-(void)transferEnd{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UInt8 l1Packet[2] = {0x01, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:l1Packet length:2];
        [[YFXBluetoothManager shareBLEManager] sendMsg:data];
    });
    
}

-(void)launchRecovery{
    UInt8 l1Packet[8] = {0x03, 0x00};
    NSData *data = [[NSData alloc] initWithBytes:l1Packet length:2];
    [[YFXBluetoothManager shareBLEManager] sendMsg:data];
}

-(void)exitWithType:(exitType)exitType{
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        switch (exitType) {
            case Reset:
                {
                    UInt8 l1Packet[3] = {0x04, 0x00, 0x00};
                    NSData *data = [[NSData alloc] initWithBytes:l1Packet length:3];
                    [[YFXBluetoothManager shareBLEManager] sendMsg:data];
                }
                break;
            case Shutdown:
                {
                    UInt8 l1Packet[3] = {0x04, 0x00, 0x01};
                    NSData *data = [[NSData alloc] initWithBytes:l1Packet length:3];
                    [[YFXBluetoothManager shareBLEManager] sendMsg:data];
                }
                break;
            case ResetToApp:
                {
                    UInt8 l1Packet[3] = {0x04, 0x00, 0x02};
                    NSData *data = [[NSData alloc] initWithBytes:l1Packet length:3];
                    [[YFXBluetoothManager shareBLEManager] sendMsg:data];
                }
                break;
            default:
                break;
        }
    });
}



-(void)assetUpdateEnd{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        UInt8 l1Packet[3] = {0x08, 0x00};
        NSData *data = [[NSData alloc] initWithBytes:l1Packet length:2];
        [[YFXBluetoothManager shareBLEManager] sendMsg:data];
    });
}

- (NSData *)byteFromUInt8:(uint8_t)val
{
    NSMutableData *valData = [[NSMutableData alloc] init];
    unsigned char valChar[1];
    valChar[0] = 0xff & val;
    [valData appendBytes:valChar length:1];
    return [self dataWithReverse:valData];
}

- (NSData *)bytesFromUInt16:(uint16_t)val
{
    NSMutableData *valData = [[NSMutableData alloc] init];
    unsigned char valChar[2];
    valChar[1] = 0xff & val;
    valChar[0] = (0xff00 & val) >> 8;
    [valData appendBytes:valChar length:2];
    return [self dataWithReverse:valData];
}

-(NSData *)bytesFromUInt32:(uint32_t)val
{
    NSMutableData *valData = [[NSMutableData alloc] init];
    unsigned char valChar[4];
    valChar[3] = 0xff & val;
    valChar[2] = (0xff00 & val) >> 8;
    valChar[1] = (0xff0000 & val) >> 16;
    valChar[0] = (0xff000000 & val) >> 24;
    [valData appendBytes:valChar length:4];
    return [self dataWithReverse:valData];
}

- (NSData *)dataWithReverse:(NSData *)srcData
{
    NSUInteger byteCount = srcData.length;
    NSMutableData *dstData = [[NSMutableData alloc] initWithData:srcData];
    NSUInteger halfLength = byteCount / 2;
    for (NSUInteger i=0; i<halfLength; i++) {
        NSRange begin = NSMakeRange(i, 1);
        NSRange end = NSMakeRange(byteCount - i - 1, 1);
        NSData *beginData = [srcData subdataWithRange:begin];
        NSData *endData = [srcData subdataWithRange:end];
        [dstData replaceBytesInRange:begin withBytes:endData.bytes];
        [dstData replaceBytesInRange:end withBytes:beginData.bytes];
    }
    return dstData;
}


@end
