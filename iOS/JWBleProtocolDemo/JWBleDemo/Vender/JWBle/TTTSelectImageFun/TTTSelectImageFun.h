//
//  TTTSelectImageFun.h
//  TianTianTui
//
//  Created by 黄博 on 2017/2/27.
//  Copyright © 2017年 TianTianTui. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^SelectImageSuccessBlock)(NSArray * images);

@interface TTTSelectImageFun : NSObject

- (void)showSelectImageAction:(long)selectCount successBlock:(SelectImageSuccessBlock)successBlock;

@end
