//
//  OpenShare.m
//  openshare
//
//  Created by LiuLogan on 15/5/13.
//  Copyright (c) 2015年 OpenShare. All rights reserved.
//

#import "OpenShare.h"

@implementation OpenShare
/**
 *  用于保存各个平台的key。每个平台需要的key／appid不一样，所以用dictionary保存。
 */
static NSMutableDictionary *keys;
                                  
+(void)set:(NSString*)platform Keys:(NSDictionary *)key{
    if (!keys) {
        keys=[[NSMutableDictionary alloc] init];
    }
    keys[platform]=key;
}
+(NSDictionary *)keyFor:(NSString*)platform{
    return [keys valueForKey:platform]?keys[platform]:nil;
}

+(void)openURL:(NSString*)url{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}
+(BOOL)canOpen:(NSString*)url{
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]];
}
+(BOOL)handleOpenURL:(NSURL*)openUrl{
    returnedURL=openUrl;
    for (NSString *key in keys) {
        SEL sel=NSSelectorFromString([key stringByAppendingString:@"_handleOpenURL"]);
        if ([self respondsToSelector:sel]) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:
                                        [self methodSignatureForSelector:sel]];
            [invocation setSelector:sel];
            [invocation setTarget:self];
            [invocation invoke];
            BOOL returnValue;
            [invocation getReturnValue:&returnValue];
            if (returnValue) {//如果这个url能处理，就返回YES，否则，交给下一个处理。
                return YES;
            }
        }else{
            NSLog(@"fatal error: %@ is should have a method: %@",key,[key stringByAppendingString:@"_handleOpenURL"]);
        }
    }
    return NO;
}

#pragma mark 分享／auth以后，应用被调起，回调。
static NSURL* returnedURL;
static NSDictionary *returnedData; 
static shareSuccess shareSuccesCallback;
static shareFail shareFailCallback;

static authSuccess authSuccesCallback;
static authFail authFailCallback;

static OSMessage *message;
+(shareSuccess)shareSuccesCallback{
    return shareSuccesCallback;
}
+(shareFail)shareFailCallback{
    return shareFailCallback;
}
+(void)setShareSuccesCallback:(shareSuccess)suc{
    shareSuccesCallback=suc;
}
+(void)setShareFailCallback:(shareFail)fail{
    shareFailCallback=fail;
}
+(NSURL*)returnedURL{
    return returnedURL;
}
+(NSDictionary*)returnedData{
    return returnedData;
}
+(void)setReturnedData:(NSDictionary*)retData{
    returnedData=retData;
}
+(void)setMessage:(OSMessage*)msg{
    message=msg;
}
+(OSMessage*)message{
    return message?:[[OSMessage alloc] init];
}
+(authSuccess)authSuccesCallback{
    return authSuccesCallback;
}
+(authFail)authFailCallback{
    return authFailCallback;
}
+(BOOL)beginShare:(NSString*)platform Message:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self keyFor:platform]) {
        message=msg;
        shareSuccesCallback=success;
        shareFailCallback=fail;
        return YES;
    }else{
        NSLog(@"place connect%@ before you can share to it!!!",platform);
        return NO;
    }
}
+(BOOL)beginAuth:(NSString*)platform Success:(authSuccess)success Fail:(authFail)fail{
    if ([self keyFor:platform]) {
        authSuccesCallback=success;
        authFailCallback=fail;
        return YES;
    }else{
        NSLog(@"place connect%@ before you can share to it!!!",platform);
        return NO;
    }
}

#pragma mark 公共实用方法
+(NSMutableDictionary *)parseUrl:(NSURL*)url{
    NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
    NSArray *urlComponents = [[url query] componentsSeparatedByString:@"&"];
    
    for (NSString *keyValuePair in urlComponents)
    {
        NSRange range=[keyValuePair rangeOfString:@"="];
        [queryStringDictionary setObject:range.length>0?[keyValuePair substringFromIndex:range.location+1]:@"" forKey:(range.length?[keyValuePair substringToIndex:range.location]:keyValuePair)];
    }
    return queryStringDictionary;
}
+(NSString*)base64Encode:(NSString *)input{
    return  [[input dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}
+(NSString*)base64Decode:(NSString *)input{
   return [[NSString alloc ] initWithData:[[NSData alloc] initWithBase64EncodedString:input options:0] encoding:NSUTF8StringEncoding];
}
+(NSString*)CFBundleDisplayName{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
}
+(NSString*)CFBundleIdentifier{
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
}
+(void)setGeneralPasteboard:(NSString*)key Value:(NSDictionary*)value encoding:(OSPboardEncoding)encoding{
    if (value&&key) {
        NSData *data=nil;
        NSError *err;
        switch (encoding) {
            case OSPboardEncodingKeyedArchiver:
                data=[NSKeyedArchiver archivedDataWithRootObject:value];
                break;
            case OSPboardEncodingPropertyListSerialization:
                data=[NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:&err];
            default:
                NSLog(@"encoding not implemented");
                break;
        }
        if (err) {
            NSLog(@"error when NSPropertyListSerialization: %@",err);
        }else if (data){
            [[UIPasteboard generalPasteboard] setData:data forPasteboardType:key];
        }
    }
}
+(NSDictionary*)generalPasteboardData:(NSString*)key encoding:(OSPboardEncoding)encoding{
    NSData *data=[[UIPasteboard generalPasteboard] dataForPasteboardType:key];
    NSDictionary *dic=nil;
    if (data) {
        NSError *err;
        switch (encoding) {
            case OSPboardEncodingKeyedArchiver:
                dic= [NSKeyedUnarchiver unarchiveObjectWithData:data];
                break;
            case OSPboardEncodingPropertyListSerialization:
                dic=[NSPropertyListSerialization propertyListWithData:data options:0 format:0 error:&err];
            default:
                break;
        }
        if (err) {
            NSLog(@"error when NSPropertyListSerialization: %@",err);
        }
    }
    return dic;
}
+(NSString*)base64AndUrlEncode:(NSString *)string{
    return  [[self base64Encode:string] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
}
@end

@implementation OSMessage
-(BOOL)isEmpty:(NSArray*)emptyValueForKeys AndNotEmpty:(NSArray*)notEmptyValueForKeys{
    @try {
        if (emptyValueForKeys) {
            for (NSString *key in emptyValueForKeys) {
                if ([self valueForKeyPath:key]) {
                    return NO;
                }
            }
        }
        if (notEmptyValueForKeys) {
            for (NSString *key in notEmptyValueForKeys) {
                if (![self valueForKey:key]) {
                    return NO;
                }
            }
        }
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"isEmpty error:\n %@",exception);
        return NO;
    }
}

@end