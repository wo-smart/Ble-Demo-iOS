//
//  JWBleOTAAction.h
//  JWBle
//
//  Created by Bo 黄 on 2019/11/1.
//  Copyright © 2019 wosmart. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JWBlePublicDefine.h"

@interface JWBleOTAAction : NSObject

+ (JWBleOTAAction *)shareInstance;

- (void)startOTAV2ForWithData:(NSData*)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel andPeripheral:(CBPeripheral*)per callBack:(nonnull JWBleDFUCallBack)callBack;

- (void)startOTAV2ForWithData:(NSData*)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel callBack:(nonnull JWBleDFUCallBack)callBack;

/**
 Starts an OTA upgrade and optionally skips an FSBL upgrade when the installed
 Secure Boot Loader version is already consistent with versionString.

 @param data Upgrade package data.
 @param OTAModel Whether OTA mode is preferred.
 @param fsblMode Whether to check the BBpro Secure Boot Loader version.
 @param versionString Target FSBL version. An empty value does not skip upgrade.
 @param callBack Upgrade status callback. Version consistency is reported with
 JWBleDeviceDFUStatus_VersionConsistent.
 */
- (void)startOTAV2ForWithData:(NSData *)data
   prefersUpgradeUsingOTAMode:(BOOL)OTAModel
                     fsblMode:(BOOL)fsblMode
                versionString:(nullable NSString *)versionString
                     callBack:(nonnull JWBleDFUCallBack)callBack;

- (void)cancelAllPeripheralConnections;

/**
 最近一次升级失败的错误码（成功、跳过或尚未开始升级时为 JWBleErrorCodeNone）
 配合 JWBleErrorMessageForCode() 可得到英文描述。
 
 The error code of the most recent OTA failure
 (JWBleErrorCodeNone when the upgrade succeeded, was skipped or has not started).
 */
@property(nonatomic, assign, readonly) JWBleErrorCode lastErrorCode;

/**
 最近一次失败的描述（失败时非空；包含底层错误信息）
 English description of the most recent failure (non-nil only when a failure occurred).
 */
@property(nonatomic, copy, readonly, nullable) NSString *lastErrorMessage;

/**
 最近一次失败的底层错误（OTA 场景通常为 RTKOTAErrorDomain）
 The underlying error of the most recent failure (usually from RTKOTAErrorDomain in OTA).
 */
@property(nonatomic, strong, readonly, nullable) NSError *lastUnderlyingError;

/**
 最近一次失败组合成的 NSError（无失败时返回 nil）
 The most recent failure as an NSError (nil when there is no failure).
 */
- (nullable NSError *)lastError;

@end
