//
//  OpenShare+Weibo.m
//  openshare
//
//  Created by LiuLogan on 15/5/18.
//  Copyright (c) 2015年 OpenShare <http://openshare.gfzj.us/>. All rights reserved.
//

#import "OpenShare+Weibo.h"

@implementation OpenShare (Weibo)
static NSString *schema=@"Weibo";
+(void)connectWeiboWithAppKey:(NSString *)appKey{
    [self set:schema Keys:@{@"appKey":appKey}];
}
+(BOOL)isWeiboInstalled{
    return [self canOpen:@"weibosdk://request"];
}
+(void)shareToWeibo:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if (![self beginShare:schema Message:msg Success:success Fail:fail]) {
        return;
    }
    NSDictionary *message;
    if ([msg isEmpty:@[@"link" ,@"image"] AndNotEmpty:@[@"title"] ]) {
        //text类型分享
        message= @{
                   @"__class" : @"WBMessageObject",
                   @"text" :msg.title
                   };
    }else if ([msg isEmpty:@[@"link" ] AndNotEmpty:@[@"title",@"image"] ]) {
        //图片类型分享
        message=@{
                  @"__class" : @"WBMessageObject",
                  @"imageObject":@{
                          @"imageData":msg.image
                          },
                  @"text" : msg.title
                  };
        
    }else if ([msg isEmpty:nil AndNotEmpty:@[@"title",@"link" ,@"image"] ]) {
        //链接类型分享
        message=@{
                  @"__class" : @"WBMessageObject",
                  @"mediaObject":@{
                          @"__class" : @"WBWebpageObject",
                          @"description": msg.desc?:msg.title,
                          @"objectID" : @"identifier1",
                          @"thumbnailData":msg.thumbnail?:msg.image,
                          @"title": msg.title,
                          @"webpageUrl":msg.link
                          }
                  
                  };
    }
    NSString *uuid=[[NSUUID UUID] UUIDString];
    NSArray *messageData=@[
                           @{@"transferObject":[NSKeyedArchiver archivedDataWithRootObject:@{
                                                                                             @"__class" :@"WBSendMessageToWeiboRequest",
                                                                                             @"message":message,
                                                                                             @"requestID" :uuid,
                                                                                             }]},
                           @{@"userInfo":[NSKeyedArchiver archivedDataWithRootObject:@{}]},
                           
                           @{@"app":[NSKeyedArchiver archivedDataWithRootObject:@{ @"appKey" : [self keyFor:schema][@"appKey"],@"bundleID" : [self CFBundleIdentifier]}]}
                           ];
    [UIPasteboard generalPasteboard].items=messageData;
    [self openURL:[NSString stringWithFormat:@"weibosdk://request?id=%@&sdkversion=003013000",uuid]];
}

+(void)WeiboAuth:(NSString*)scope redirectURI:(NSString*)redirectURI Success:(authSuccess)success Fail:(authFail)fail{
    if (![self beginAuth:schema Success:success Fail:fail]) {
        return;
    }
    NSString *uuid=[[NSUUID UUID] UUIDString];
    NSArray *authData=@[
                        @{@"transferObject":[NSKeyedArchiver archivedDataWithRootObject:@{
                                                                                          @"__class" :@"WBAuthorizeRequest",
                                                                                          @"redirectURI":redirectURI,
                                                                                          @"requestID" :uuid,
                                                                                          @"scope": scope?:@"all"
                                                                                          }]},
                        @{@"userInfo":[NSKeyedArchiver archivedDataWithRootObject:@{
                                                                                     @"mykey":@"as you like",
                                                                                    @"SSO_From" : @"SendMessageToWeiboViewController"
                                                                                    }]
                          },
                        
                        @{@"app":[NSKeyedArchiver archivedDataWithRootObject:@{
                                                                               @"appKey" :[self keyFor:schema][@"appKey"],
                                                                               @"bundleID" : [self CFBundleIdentifier],
                                                                               @"name" :[self CFBundleDisplayName]
                                                                               }]
                          }
                        ];
    [UIPasteboard generalPasteboard].items=authData;
    [self openURL:[NSString stringWithFormat:@"weibosdk://request?id=%@&sdkversion=003013000",uuid]];
}

+(BOOL)Weibo_handleOpenURL{
    NSURL* url=[self returnedURL];
    if ([url.scheme hasPrefix:@"wb"]) {
        NSArray *items=[UIPasteboard generalPasteboard].items;
        NSMutableDictionary *ret=[NSMutableDictionary dictionaryWithCapacity:items.count];
        for (NSDictionary *item in items) {
            for (NSString *k in item) {
                ret[k]=[k isEqualToString:@"sdkVersion"]?item[k]:[NSKeyedUnarchiver unarchiveObjectWithData:item[k]];
            }
        }
        NSDictionary *transferObject=ret[@"transferObject"];
        if ([transferObject[@"__class"] isEqualToString:@"WBAuthorizeResponse"]) {
            //auth
            if ([transferObject[@"statusCode"] intValue]==0) {
                if ([self authSuccessCallback]) {
                    [self authSuccessCallback](transferObject);
                }
            }else{
                if ([self authFailCallback]) {
                    NSError *err=[NSError errorWithDomain:@"weibo_auth_response" code:[transferObject[@"statusCode"] intValue] userInfo:transferObject];
                    [self authFailCallback](transferObject,err);
                }
            }
        }else if ([transferObject[@"__class"] isEqualToString:@"WBSendMessageToWeiboResponse"]) {
            //分享回调
            if ([transferObject[@"statusCode"] intValue]==0) {
                if ([self shareSuccessCallback]) {
                    [self shareSuccessCallback]([self message]);
                }
            }else{
                if ([self shareFailCallback]) {
                    NSError *err=[NSError errorWithDomain:@"weibo_share_response" code:[transferObject[@"statusCode"] intValue] userInfo:transferObject];
                    [self shareFailCallback]([self message],err);
                }
            }
        }
        return YES;
    } else{
        return NO;
    }
}


@end
