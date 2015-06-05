//
//  OpenShare+Renren.h
//  openshare
//
//  Created by LiuLogan on 15/5/19.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare.h"

@interface OpenShare (Renren)
+(void)connectRenrenWithAppId:(NSString *)appId AndAppKey:(NSString*)appKey;
+(BOOL)isRenrenInstalled;

+(void)shareToRenrenSession:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail;
+(void)shareToRenrenTimeline:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail;

@end
