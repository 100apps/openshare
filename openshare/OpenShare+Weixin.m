//
//  OpenShare+Weixin.m
//  openshare
//
//  Created by LiuLogan on 15/5/18.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare+Weixin.h"

@implementation OpenShare (Weixin)
static NSString *schema=@"Weixin";
+(void)connectWeixinWithAppId:(NSString *)appId miniAppId:(NSString *)miniAppId{
    [self set:schema Keys:@{@"appid":appId,
                            @"miniappid":miniAppId}];

}
+(BOOL)isWeixinInstalled{
    return [self canOpen:@"weixin://"];
}

+(void)shareToWeixinSession:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genWeixinShareUrl:msg to:0]];
    }
}
+(void)shareToWeixinTimeline:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genWeixinShareUrl:msg to:1]];
    }
}
+(void)shareToWeixinFavorite:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genWeixinShareUrl:msg to:2]];
    }
}


/**
 *  把msg分享到shareTO
 *
 *  @param msg     OSmessage
 *  @param shareTo 0是好友／1是QQ空间。
 *
 *  @return 需要打开的url
 */
+(NSString*)genWeixinShareUrl:(OSMessage*)msg to:(int)shareTo{

    NSMutableDictionary *dic = [NSMutableDictionary dictionary];

    dic[@"result"] = @"1";
    dic[@"returnFromApp"] = @"1";
    dic[@"scene"] = [NSString stringWithFormat:@"%d",shareTo];
    dic[@"sdkver"] = @"1.5";
    dic[@"command"] = @"1010";

    switch (msg.multimediaType) {
        case OSMultimediaTypeAudio:
            dic[@"description"] = msg.desc?:msg.title;
            dic[@"mediaUrl"] = msg.link;
            dic[@"mediaDataUrl"] = msg.mediaDataUrl;
            dic[@"objectType"] = @"3";
            dic[@"thumbData"] = msg.thumbnail? [self dataWithImage:msg.thumbnail]:[self dataWithImage:msg.image scale:CGSizeMake(100, 100)];;
            dic[@"title"] = msg.title;
            break;

        case OSMultimediaTypeVideo:
            dic[@"description"] = msg.desc?:msg.title;
            dic[@"mediaUrl"] = msg.link;
            dic[@"objectType"] = @"4";
            dic[@"thumbData"] = msg.thumbnail? [self dataWithImage:msg.thumbnail]:[self dataWithImage:msg.image scale:CGSizeMake(100, 100)];;
            dic[@"title"] = msg.title;
            break;
        case OSMultimediaTypeApp:
            dic[@"description"] = msg.desc?:msg.title;
            if(msg.extInfo) {
                dic[@"extInfo"] = msg.extInfo;
            }
            dic[@"fileData"] = [self dataWithImage:msg.image];
            dic[@"mediaUrl"] = msg.link;
            dic[@"objectType"] = @"7";
            dic[@"thumbData"] = msg.thumbnail? [self dataWithImage:msg.thumbnail]:[self dataWithImage:msg.image scale:CGSizeMake(100, 100)];;
            dic[@"title"] = msg.title;
            break;
        case OSMultimediaTypeFile:

            dic[@"description"] = msg.desc?:msg.title;
            dic[@"fileData"] = msg.file;
            dic[@"objectType"] = @"6";
            dic[@"fileExt"] = msg.fileExt?:@"";
            dic[@"thumbData"] = msg.thumbnail? [self dataWithImage:msg.thumbnail]:[self dataWithImage:msg.image scale:CGSizeMake(100, 100)];;
            dic[@"title"] = msg.title;
            break;
        case OSMultimediaTypeMiniApp:
            dic[@"objectType"] = @"36";
            dic[@"title"] = msg.title;
            dic[@"thumbData"] = msg.thumbnail? [self dataWithImage:msg.thumbnail] : [self dataWithImage:msg.image scale:CGSizeMake(100, 100)];
            dic[@"hdThumbData"] = [self dataWithImage:msg.image];
            dic[@"appBrandPath"] = msg.path;
            dic[@"mediaUrl"] = msg.link;
            dic[@"withShareTicket"] = @(msg.withShareTicket);
            dic[@"miniprogramType"] = @(msg.miniAppType);
            dic[@"appBrandUserName"] = [self keyFor:schema][@"miniappid"];
            break;
        default:
            //不指定类型
            if ([msg isEmpty:@[@"image",@"link", @"file"] AndNotEmpty:@[@"title"]]) {
                //文本
                dic[@"command"] = @"1020";
                dic[@"title"] = msg.title;
            }else if([msg isEmpty:@[@"link"] AndNotEmpty:@[@"image"]]){
                //图片
                dic[@"title"] = msg.title?:@"";
                dic[@"fileData"] = [self dataWithImage:msg.image];
                dic[@"thumbData"] = msg.thumbnail ? [self dataWithImage:msg.thumbnail] : [self dataWithImage:msg.image scale:CGSizeMake(100, 100)];
                dic[@"objectType"] = @"2";
            }else if([msg isEmpty:nil AndNotEmpty:@[@"link",@"title",@"image"]]){
                //有链接。
                dic[@"description"] = msg.desc?:msg.title;
                dic[@"mediaUrl"] = msg.link;
                dic[@"objectType"] = @"5";
                dic[@"thumbData"] = msg.thumbnail? [self dataWithImage:msg.thumbnail]:[self dataWithImage:msg.image scale:CGSizeMake(100, 100)];
                dic[@"title"] =msg.title;
            } else if ([msg isEmpty:@[@"link"] AndNotEmpty:@[@"file"]]) {
                //gif
                dic[@"fileData"]= msg.file ? msg.file : [self dataWithImage:msg.image];
                dic[@"thumbData"]=msg.thumbnail ? [self dataWithImage:msg.thumbnail] : [self dataWithImage:msg.image scale:CGSizeMake(100, 100)];
                dic[@"objectType"]=@"8";
            }
            break;
    }

    NSData *output = [NSPropertyListSerialization dataWithPropertyList:@{[self keyFor:schema][@"appid"]: dic}
                                                                format:NSPropertyListBinaryFormat_v1_0
                                                               options:0
                                                                 error:nil];

    [[UIPasteboard generalPasteboard] setData:output forPasteboardType:@"content"];

    return [NSString stringWithFormat:@"weixin://app/%@/sendreq/?",[self keyFor:schema][@"appid"]];
}


/**
 *  注意：微信登录权限仅限已获得认证的开发者申请，请先进行开发者认证
 *
 *  @param scope   scope
 *  @param success 登录成功回调
 *  @param fail    登录失败回调
 */
+(void)WeixinAuth:(NSString*)scope Success:(authSuccess)success Fail:(authFail)fail{
    if ([self beginAuth:schema Success:success Fail:fail]) {
        [self openURL:[NSString stringWithFormat:@"weixin://app/%@/auth/?scope=%@&state=Weixinauth",[self keyFor:schema][@"appid"],scope]];
    }
}
/**
 *  微信支付,不同于分享和登录，由于参数是服务器生成的，所以不需要connect。
 *
 *  @param link    服务器返回的link，以供直接打开
 *  @param success 微信支付成功的回调
 *  @param fail    微信支付失败的回调
 */
+(void)WeixinPay:(NSString*)link Success:(paySuccess)success Fail:(payFail)fail{
    [self setPaySuccessCallback:success];
    [self setPayFailCallback:fail];
    [self openURL:link];
}

+(BOOL)Weixin_handleOpenURL{
    NSURL* url=[self returnedURL];
    if ([url.scheme hasPrefix:@"wx"]) {
        NSDictionary *retDic=[NSPropertyListSerialization propertyListWithData:[[UIPasteboard generalPasteboard] dataForPasteboardType:@"content"]?:[[NSData alloc] init] options:0 format:0 error:nil][[self keyFor:schema][@"appid"]];
        NSLog(@"retDic\n%@",retDic);
        if ([url.absoluteString rangeOfString:@"://oauth"].location != NSNotFound) {
            //login succcess
            if ([self authSuccessCallback]) {
                [self authSuccessCallback]([self parseUrl:url]);
            }
        }else if([url.absoluteString rangeOfString:@"://pay/"].location != NSNotFound){
            NSDictionary *urlMap=[self parseUrl:url];
            if ([urlMap[@"ret"] intValue]==0) {
                if ([self paySuccessCallback]) {
                    [self paySuccessCallback](urlMap);
                }
            }else{
                if ([self payFailCallback]) {
                    [self payFailCallback](urlMap,[NSError errorWithDomain:@"weixin_pay" code:[urlMap[@"ret"] intValue] userInfo:retDic]);
                }
            }
        }else{
            if (retDic[@"state"]&&[retDic[@"state"] isEqualToString:@"Weixinauth"]&&[retDic[@"result"] intValue]!=0) {
                //登录失败
                if ([self authFailCallback]) {
                    [self authFailCallback](retDic,[NSError errorWithDomain:@"weixin_auth" code:[retDic[@"result"] intValue] userInfo:retDic]);
                }
            }else if([retDic[@"result"] intValue]==0){
                //分享成功
                if ([self shareSuccessCallback]) {
                    [self shareSuccessCallback]([self message]);
                }
            }else{
                //分享失败
                if ([self shareFailCallback]) {
                    [self shareFailCallback]([self message],[NSError errorWithDomain:@"weixin_share" code:[retDic[@"result"] intValue] userInfo:retDic]);
                }
            }
            
        }
        return YES;
    }else{
        return NO;
    }
}
@end
