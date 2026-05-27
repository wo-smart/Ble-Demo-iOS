//
//  LrwOTAHelp.m
//  JWBleDemo
//
//  Created by bobobo on 2024/1/2.
//  Copyright © 2024 wosmart. All rights reserved.
//

#import "LrwOTAHelp.h"
#import <SSZipArchive.h>
#import "BXOtaLibrary.h"

@interface LrwOTAHelp ()
<
    SSZipArchiveDelegate,
    OTADelegate
>

@property (nonatomic, strong) NSDictionary *jsonDic;
@property (nonatomic, strong) NSData *fileData;
@property (nonatomic, copy) JWBleDFUCallBack callBack;

@end

@implementation LrwOTAHelp

- (void)startOTAWithData:(NSData *)data callBack:(nonnull JWBleDFUCallBack)callBack {
    
    self.fileData = data;
    self.callBack = callBack;
    
    [LrwOTAHelp deleteTempData];
    
    NSString *path = [self saveData2File:data];
    [self unzipFileWithUrl:path];
    
    [self startOtaWithPeripheral];
    
}

- (NSString *)saveData2File:(NSData *)data {
    // 获取要保存为ZIP的数据
    NSData *dataToZip = data;

    // 获取文件路径
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *zipFilePath = [documentsDirectory stringByAppendingPathComponent:@"test4.zip"];

    // 将数据写入文件
    BOOL success = [dataToZip writeToFile:zipFilePath atomically:YES];
    if (!success) {
        JWNSLog(@"Failed to write data to file");
    }

    // 创建ZIP文件
//    BOOL zipSuccess = [SSZipArchive createZipFileAtPath:zipFilePath withFilesAtPaths:@[zipFilePath]];
    
    return zipFilePath;
}

-(void)unzipFileWithUrl:(NSString *)path {
    NSString *temp = NSTemporaryDirectory();
    JWNSLog(@"解压到地址：%@",temp);
        //把 sourceFilePath 这个路径下的zip包，解压到这个 destinationPath 路径下
    
    if ([SSZipArchive unzipFileAtPath:path toDestination:temp delegate:self]){
        JWNSLog(@"解压成功");
        NSString *jsonFilePath = [self findListJSONFileRecursivelyInDirectory:temp];
//        [self analysisForListJson:jsonFilePath];
    }else {
        JWNSLog(@"解压失败");
    }
}

- (NSString *)findListJSONFileRecursivelyInDirectory:(NSString *)directoryPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // 获取目录内容
    NSError *error = nil;
    NSArray *contents = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        JWNSLog(@"Error reading directory: %@", error.localizedDescription);
        return nil;
    }
    
    // 遍历目录内容
    for (NSString *item in contents) {
        NSString *itemPath = [directoryPath stringByAppendingPathComponent:item];
        
        // 检查是否是目录
        BOOL isDirectory;
        if ([fileManager fileExistsAtPath:itemPath isDirectory:&isDirectory]) {
            if (isDirectory) {
                // 递归查找子目录
                NSString *result = [self findListJSONFileRecursivelyInDirectory:itemPath];
                if (result) {
                    return result;
                }
            } else if ([item isEqualToString:@"list.json"]) {
                // 找到目标文件
                return itemPath;
            }
        }
    }
    
    // 未找到目标文件
    return nil;
}

-(void)analysisForListJson:(NSString *)url {
    NSData *jsonData = [NSData dataWithContentsOfFile:url];
    //解析json数据
    NSError *error;
    if (jsonData){
        self.jsonDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    }else{
        
    }
}

#pragma mark - SSZipArchiveDelegate
- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo {
//    JWNSLog(@"将要解压。");
}
 
- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPat uniqueId:(NSString *)uniqueId {
//    JWNSLog(@"解压完成！");
}

#pragma mark - ota 流程
-(void)startOtaWithPeripheral {
    JWBleManager.shareInstance.connectionModel.otaIng = true;
    
//    [[BXOtaLibrary shareBXOtaLibrary] getData:self.fileData];
    [BXOtaLibrary shareBXOtaLibrary].delegate = self; //设置代理
    JWBleDeviceModel *connectionModel = JWBleManager.shareInstance.connectionModel;
    [[BXOtaLibrary shareBXOtaLibrary] startOtaWithPeripheral:JWBleManager.shareInstance.connectionModel.per AndOtaType:Firmware AndMac:JWBleManager.shareInstance.connectionModel.macAddress];
    
    self.callBack(0, 0, JWBleDeviceDFUStatus_Start);
}

#pragma mark - help
//清除temp下文件
+(void)deleteTempData {
    NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
    for (NSString *file in tmpDirectory) {
        BOOL isDelete = [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
        if(isDelete){
            JWNSLog(@"删除：%@ 成功", [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file]);
        }
    }
}

#pragma mark - OTADelegate
//ota升级完成 //second 单位秒 。升级完成的时间。升级完成后，选择重启，关机，或者重启并进入APP。
- (void)onFinishWithTime:(int)second {
    
    JWNSLog(@"onFinish");
//    [[BXOtaLibrary shareBXOtaLibrary]exitWithType:Reset];
    
    self.callBack(0, 0, JWBleDeviceDFUStatus_Success);
    
    [[BXOtaLibrary shareBXOtaLibrary]exitWithType:ResetToApp];
}

//ota升级时的报错
- (void)onInitialError:(nonnull NSString *)error {
    JWNSLog(@"error：%@",error);
    self.callBack(0, 0, JWBleDeviceDFUStatus_Failure);
}

/*
    index - 当前升级的第几个文件
    filesize - 命令总个数
    rate - 已发送个数
*/
- (void)otaWithIndex:(int)index AndFileSize:(float)filesize AndRate:(float)rate {
    
//    JWNSLog(@"index:%d \t filesize:%f \t rate:%f",index, filesize, rate);
//    JWNSLog(@"index:%d",index);
//    JWNSLog(@"filesize:%f",filesize);
//    JWNSLog(@"rate:%f",rate);
//    self.callBack(rate, filesize, JWBleDeviceDFUStatus_Updating);
}

//总进度
    /*
    filesize - 总个数
    rate - 总发送个数
    */
-(void)otaWithTotalFileSize:(float)filesize AndRate:(float)rate{
//    JWNSLog(@"totalFilesize:%f \t totalRate:%f",filesize, rate);
//    JWNSLog(@"",rate);
    self.callBack(rate, filesize, JWBleDeviceDFUStatus_Updating);
}


-(void)launchRecoverySuccess{

    /*
 //当进入launchRecoverySuccess后，需要手动写入断开连接的用户在此处写入。
 //断开后重连再次进入OTA。
 //sdk断开连接方法  [[YFXBluetoothManager shareBLEManager] repeatConnectDevice];
 //重新进入OTA方法。
 [BXOtaLibrary shareBXOtaLibrary].delegate = self;
 [[BXOtaLibrary shareBXOtaLibrary] startOtaWithPeripheral:_devicePeripheral AndOtaType:Firmware];
 
 */

}


@end
