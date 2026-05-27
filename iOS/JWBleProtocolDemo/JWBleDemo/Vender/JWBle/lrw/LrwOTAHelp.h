//
//  LrwOTAHelp.h
//  JWBleDemo
//
//  Created by bobobo on 2024/1/2.
//  Copyright © 2024 wosmart. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LrwOTAHelp : NSObject

- (void)startOTAWithData:(NSData *)data callBack:(nonnull JWBleDFUCallBack)callBack;

@end

