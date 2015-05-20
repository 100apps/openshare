//
//  UIControl+Blocks.h
//
//  Created by AvdLee on 05/08/14.
//  Copyright (c) 2014 A.Lee. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef void (^ActionBlock)(id sender);

@interface UIControl (Blocks)

- (void)addEventHandler:(ActionBlock)handler forControlEvents:(UIControlEvents)controlEvents;

@end
