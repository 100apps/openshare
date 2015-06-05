//
//  OpenShare+Weixin.h
//  openshare
//
//  Created by LiuLogan on 15/5/18.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare.h"

@interface OpenShare (Weixin)
/**
 *  https://open.weixin.qq.com 在这里申请
 *
 *  @param appId AppID
 */
+(void)connectWeixinWithAppId:(NSString *)appId;
+(BOOL)isWeixinInstalled;

+(void)shareToWeixinSession:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail;
+(void)shareToWeixinTimeline:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail;
+(void)shareToWeixinFavorite:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail;
+(void)WeixinAuth:(NSString*)scope Success:(authSuccess)success Fail:(authFail)fail;
+(void)WeixinPay:(NSString*)link Success:(paySuccess)success Fail:(payFail)fail;
@end
