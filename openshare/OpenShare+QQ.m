//
//  OpenShare+QQ.m
//  openshare
//
//  Created by LiuLogan on 15/5/15.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare+QQ.h"

@implementation OpenShare (QQ)
static NSString* schema=@"QQ";
enum
{
    kQQAPICtrlFlagQZoneShareOnStart = 0x01,
    kQQAPICtrlFlagQZoneShareForbid = 0x02,
    kQQAPICtrlFlagQQShare = 0x04,
    kQQAPICtrlFlagQQShareFavorites = 0x08, //收藏
    kQQAPICtrlFlagQQShareDataline = 0x10,  //数据线
};

+(void)connectQQWithAppId:(NSString *)appId{
    [self set:schema Keys:@{@"appid":appId,@"callback_name":[NSString stringWithFormat:@"QQ%02llx",[appId longLongValue]]}];
}
+(BOOL)isQQInstalled{
    return [self canOpen:@"mqqapi://"];
}
+(void)shareToQQFriends:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genShareUrl:msg to:0]];
    }
}
+(void)shareToQQZone:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genShareUrl:msg to:kQQAPICtrlFlagQZoneShareOnStart]];
    }
}
+(void)shareToQQFavorites:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genShareUrl:msg to:kQQAPICtrlFlagQQShareFavorites]];
    }
}
+(void)shareToQQDataline:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genShareUrl:msg to:kQQAPICtrlFlagQQShareDataline]];
    }
}

+(void)QQAuth:(NSString*)scope Success:(authSuccess)success Fail:(authFail)fail{
    if ([self beginAuth:schema Success:success Fail:fail]) {
        NSDictionary *authData=@{@"app_id" : [self keyFor:schema][@"appid"],
                                 @"app_name" : [self CFBundleDisplayName],
                                 //@"bundleid":[self CFBundleIdentifier],//或者有，或者正确(和后台配置一致)，建议不填写。
                                 @"client_id" :[self keyFor:schema][@"appid"],
                                 @"response_type" : @"token",
                                 @"scope" : scope,//@"get_user_info,get_simple_userinfo,add_album,add_idol,add_one_blog,add_pic_t,add_share,add_topic,check_page_fans,del_idol,del_t,get_fanslist,get_idollist,get_info,get_other_info,get_repost_list,list_album,upload_pic,get_vip_info,get_vip_rich_info,get_intimate_friends_weibo,match_nick_tips_weibo",
                                 @"sdkp" :@"i",
                                 @"sdkv" : @"2.9",
                                 @"status_machine" : [[UIDevice currentDevice] model],
                                 @"status_os" : [[UIDevice currentDevice] systemVersion],
                                 @"status_version" : [[UIDevice currentDevice] systemVersion]
                                 };
        
        [self setGeneralPasteboard:[@"com.tencent.tencent" stringByAppendingString:[self keyFor:schema][@"appid"]] Value:authData encoding:OSPboardEncodingKeyedArchiver];
        [self openURL:[NSString stringWithFormat:@"mqqOpensdkSSoLogin://SSoLogin/tencent%@/com.tencent.tencent%@?generalpastboard=1",[self keyFor:schema][@"appid"],[self keyFor:schema][@"appid"]]];
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
+(NSString*)genShareUrl:(OSMessage*)msg to:(int)shareTo{
    NSMutableString *ret=[[NSMutableString alloc] initWithString:@"mqqapi://share/to_fri?thirdAppDisplayName="];
    [ret appendString:[self base64Encode:[self CFBundleDisplayName]]];
    [ret appendString:@"&version=1&cflag="];
    [ret appendFormat:@"%d",shareTo];
    [ret appendString:@"&callback_type=scheme&generalpastboard=1"];
    [ret appendString:@"&callback_name="];
    [ret appendString:[self keyFor:schema][@"callback_name"]];
    [ret appendString:@"&src_type=app&shareType=0&file_type="];
    //修正如果有link，则默认是news分享类型。
    if (msg.link&&!msg.multimediaType) {
        msg.multimediaType=OSMultimediaTypeNews;
    }
    if ([msg isEmpty:@[@"image",@"link" ] AndNotEmpty:@[@"title"]]) {
        //纯文本分享。
        [ret appendString:@"text&file_data="];
        [ret appendString:[self base64AndUrlEncode:msg.title]];
    }else if([msg isEmpty:@[@"link"] AndNotEmpty:@[@"title",@"image",@"desc"]]){
        //图片分享
        NSDictionary *data=@{@"file_data":[self dataWithImage:msg.image],
                             @"previewimagedata":msg.thumbnail?  [self dataWithImage:msg.thumbnail] :[self dataWithImage:msg.image scale:CGSizeMake(36, 36)]
                             };
        [self setGeneralPasteboard:@"com.tencent.mqq.api.apiLargeData" Value:data encoding: OSPboardEncodingKeyedArchiver];
        [ret appendString:@"img&title="];
        [ret appendString:[self base64Encode:msg.title]];
        [ret appendString:@"&objectlocation=pasteboard&description="];
        [ret appendString:[self base64Encode:msg.desc]];
    }else  if ([msg isEmpty:nil AndNotEmpty:@[@"title",@"desc",@"image",@"link",@"multimediaType"]]) {
        //新闻／多媒体分享（图片加链接）发送新闻消息 预览图像数据，最大1M字节 URL地址,必填，最长512个字符 via QQApiInterfaceObject.h
        NSDictionary *data=@{@"previewimagedata":[self dataWithImage:msg.image]};
        [self setGeneralPasteboard:@"com.tencent.mqq.api.apiLargeData" Value:data encoding: OSPboardEncodingKeyedArchiver];
        NSString *msgType=@"news";
        if (msg.multimediaType==OSMultimediaTypeAudio) {
            msgType=@"audio";
        }else if(msg.multimediaType==OSMultimediaTypeVideo){
            //QQ没有video类型。客户端会自动判断。
            //            msgType=@"video";
        }
        [ret appendFormat:@"%@&title=%@&url=%@&description=%@&objectlocation=pasteboard",msgType,[self base64AndUrlEncode:msg.title],[self base64AndUrlEncode:msg.link],[self base64AndUrlEncode:msg.desc]];
    }
    return ret;
}
+(BOOL)QQ_handleOpenURL{
    NSURL* url=[self returnedURL];
    if ([url.scheme hasPrefix:@"QQ"]) {
        //分享
        NSDictionary *dic=[self parseUrl:url];
        if (dic[@"error_description"]) {
            [dic setValue:[self base64Decode:dic[@"error_description"]] forKey:@"error_description"];
        }
        if ([dic[@"error"] intValue]!=0) {
            NSError *err=[NSError errorWithDomain:@"response_from_qq" code:[dic[@"error"] intValue] userInfo:dic];
            if ([self shareFailCallback]) {
                [self shareFailCallback]([self message],err);
            }
        }else{
            if ([self shareSuccessCallback]) {
                [self shareSuccessCallback]([self message]);
            }
        }
        return YES;
    }else if([url.scheme hasPrefix:@"tencent"]){
        //登陆auth
        NSDictionary *ret=[self generalPasteboardData:[@"com.tencent.tencent" stringByAppendingString:[self keyFor:schema][@"appid"]] encoding:OSPboardEncodingKeyedArchiver];
        if (ret[@"ret"]&&[ret[@"ret"] intValue]==0) {
            if ( [self authSuccessCallback]) {
                [self authSuccessCallback](ret);
            }
        }else{
            NSError *err=[NSError errorWithDomain:@"auth_from_QQ" code:-1 userInfo:ret];
            if ([self authFailCallback]) {
                [self authFailCallback](ret,err);
            }
        }
        return YES;
    }
    else{
        return NO;
    }
}
+(void)chatWithQQNumber:(NSString*)qqNumber{
    [self openURL:[NSString stringWithFormat:@"mqqwpa://im/chat?uin=%@&thirdAppDisplayName=%@&callback_name=%@&src_type=app&version=1&chat_type=wpa&callback_type=scheme",qqNumber,[self base64Encode:[self CFBundleDisplayName]],[self keyFor:schema][@"callback_name"]]];
}
+(void)chatInQQGroup:(NSString*)groupNumber{
    [self openURL:[NSString stringWithFormat:@"mqqwpa://im/chat?uin=%@&thirdAppDisplayName=%@&callback_name=%@&src_type=app&version=1&chat_type=group&callback_type=scheme",groupNumber,[self base64Encode:[self CFBundleDisplayName]],[self keyFor:schema][@"callback_name"]]];
}
@end
