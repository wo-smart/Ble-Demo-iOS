//
//  JWBleHeatStressReminderModel.h
//  JWBle
//
//  Created by Bo 黄 on 2020/9/2.
//  Copyright © 2020 wosmart. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JWBleHeatStressReminderModel : NSObject

/**
 * 是否打开
 * Whether to open
 */
@property(nonatomic, assign) BOOL open;

/**
 * 开始小时 0~23
 * Start hour 0~23
 */
@property(nonatomic, assign) int startHour;

/**
 * 开始分钟 0~59
 * Start minute 0~59
 */
@property(nonatomic, assign) int startMinute;

/**
 * 结束小时 0~23
 * End hour 0~23
 */
@property(nonatomic, assign) int endHour;

/**
 * 结束分钟 0~59
 * End minute 0~59
 */
@property(nonatomic, assign) int endMinute;

@end

NS_ASSUME_NONNULL_END
