//
//  OpenShare+Alipay.h
//  openshare
//
//  Created by LiuLogan on 15/6/4.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare.h"

@interface OpenShare (Alipay)
+(void)connectAlipay;
+(void)AliPay:(NSString*)link Success:(paySuccess)success Fail:(payFail)fail;
@end
