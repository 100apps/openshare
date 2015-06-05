//
//  OpenShare+Renren.m
//  openshare
//
//  Created by LiuLogan on 15/5/19.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare+Renren.h"

@implementation OpenShare (Renren)
static NSString* schema=@"Renren";
+(void)connectRenrenWithAppId:(NSString *)appId AndAppKey:(NSString*)appKey{
    [self set:schema Keys:@{@"appid":appId,@"appkey":appKey}];
}
+(BOOL)isRenrenInstalled{
    return [self canOpen:@"renrenshare://share"];
}

+(void)shareToRenrenSession:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genRenrenShareUrl:msg to:0]];
    }
}
+(void)shareToRenrenTimeline:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self beginShare:schema Message:msg Success:success Fail:fail]) {
        [self openURL:[self genRenrenShareUrl:msg to:1]];
    }
}
+(NSString*)genRenrenShareUrl:(OSMessage*)msg to:(int)shareTo{
    NSString *msgType=@"Text";
    NSMutableDictionary *dic=[[NSMutableDictionary alloc] initWithDictionary:@{@"title":msg.title}];
    if(msg.multimediaType==OSMultimediaTypeAudio){
        dic[@"description"]=msg.desc?:msg.title;
        dic[@"thumbData"]=msg.thumbnail?:msg.image;
        dic[@"url"]=msg.link;
        msgType=@"Voice";
    }else if(msg.multimediaType==OSMultimediaTypeVideo){
        dic[@"description"]=msg.desc?:msg.title;
        dic[@"thumbData"]=msg.thumbnail?:msg.image;
        dic[@"url"]=msg.link;
        msgType=@"Video";
    }else{
        if ([msg isEmpty:nil AndNotEmpty:@[@"image",@"link"]]) {
            //图文
            dic[@"description"]=msg.desc?:msg.title;
            dic[@"thumbData"]=msg.thumbnail?:msg.image;
            dic[@"url"]=msg.link;
            msgType=@"ImgText";
        }else if ([msg isEmpty:@[@"link"] AndNotEmpty:@[@"image"]]) {
            //图片
            dic[@"imageData"]=msg.image;
            dic[@"thumbData"]=msg.thumbnail?:msg.image;
            msgType=@"ImgText";
        }else if ([msg isEmpty:@[@"link"] AndNotEmpty:@[@"image"]]) {
            //文本
            dic[@"text"]=msg.desc?:msg.title;
            if (msg.link) {
                dic[@"url"]=msg.link;
            }
            msgType=@"Text";
        }
    }
    [[UIPasteboard generalPasteboard] setData:[NSPropertyListSerialization dataWithPropertyList:dic format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil] forPasteboardType:@"renren_share"];
    return [NSString stringWithFormat:@"renrenshare://share?sdk_ver=1.0&app_id=%@&app_key=%@&callback=renrenshare%@&msgType=%@&target=%d&msgVer=1.0&msgData=renren_share",[self keyFor:schema][@"appid"],[self keyFor:schema][@"appkey"],[self keyFor:schema][@"appid"],msgType,shareTo];
}
/**
 *  人人网回调，人人网不传回分享结果。
 *
 *  @return 是否是人人网打开的
 */
+(BOOL)Renren_handleOpenURL{
    NSURL* url=[self returnedURL];
    if ([url.scheme hasPrefix:@"renrenshare"]) {
        if ([self shareSuccessCallback]) {
            [self shareSuccessCallback]([self message]);
        }
        return YES;
    }else{
        return NO;
    }
}

@end
