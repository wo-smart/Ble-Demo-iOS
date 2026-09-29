#import <Foundation/Foundation.h>
#import "JWBlePublicDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface JWBleMotionStatusModel : NSObject

@property (nonatomic, assign) JWBleDeviceMotionResult result;
@property (nonatomic, assign) JWBleDeviceMotionState state;
@property (nonatomic, assign) JWBleDeviceMotionEnum motionType;
@property (nonatomic, assign) NSInteger rawMotionType;

@end

NS_ASSUME_NONNULL_END
