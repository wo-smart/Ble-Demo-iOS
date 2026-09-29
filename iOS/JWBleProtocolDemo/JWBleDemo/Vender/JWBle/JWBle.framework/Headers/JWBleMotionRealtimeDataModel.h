#import <Foundation/Foundation.h>
#import "JWBlePublicDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface JWBleMotionRealtimeDataModel : NSObject

@property (nonatomic, assign) JWBleDeviceMotionState state;
@property (nonatomic, assign) JWBleDeviceMotionEnum motionType;
@property (nonatomic, assign) NSInteger rawMotionType;
/// Unit: seconds.
@property (nonatomic, assign) uint32_t duration;
@property (nonatomic, assign) uint8_t heartRate;
@property (nonatomic, assign) uint32_t steps;
/// Same unit as the protocol's 0x16 Exercise distance field.
@property (nonatomic, assign) uint32_t distance;
/// Same unit as the protocol's 0x16 Exercise calories field.
@property (nonatomic, assign) uint32_t calories;

@end

NS_ASSUME_NONNULL_END
