//
//  JWBleOTAAction.h
//  JWBle
//
//  Created by Bo 黄 on 2019/11/1.
//  Copyright © 2019 wosmart. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JWBleOTAAction : NSObject

+ (JWBleOTAAction *)shareInstance;

- (void)startOTAV2ForWithData:(NSData*)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel andPeripheral:(CBPeripheral*)per callBack:(nonnull JWBleDFUCallBack)callBack;

- (void)startOTAV2ForWithData:(NSData*)data prefersUpgradeUsingOTAMode:(BOOL)OTAModel callBack:(nonnull JWBleDFUCallBack)callBack;

- (void)cancelAllPeripheralConnections;

@end
