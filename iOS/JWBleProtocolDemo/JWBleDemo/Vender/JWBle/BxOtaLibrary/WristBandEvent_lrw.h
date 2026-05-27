//
//  WristBandEvent_lrw.h
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
//   
#pragma once
#import <Foundation/Foundation.h>
//#import "WristBand.h"

@interface WristBandEvent_lrw : NSObject

+ (id)getShareInstance;
//- (void)wbProcessNotifyData:(Byte *)respData andLength:(NSInteger)length;
- (void)wbProcessNotifyData:(NSData *)data;
- (void)wbExceptionHandler;
@end
