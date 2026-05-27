//
//  WristBandCmd.h
//  OTAForiOS
//
//  Created by Micro BX on 2023/8/21.
//

#import <Foundation/Foundation.h>
#import "BXOtaLibrary.h"

@interface WristBandCmd_lrw : NSObject
+ (id)getShareInstance;

-(void)transferStartWithId:(UInt8)fileId fileSize:(UInt32) filesize crc32:(UInt32) crc32;

-(void)transferEnd;

-(void)checkRecoveryMode;

-(void)launchRecovery;

-(void)exitWithType:(exitType)exitType;

-(void)assetUpdateReqWithType:(UInt8)type fileSize:(UInt32) filesize crc32:(UInt32) crc32;

-(void)assetUpdateEnd;

@end
