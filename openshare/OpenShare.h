//
//  OpenShare.h
//  openshare
//
//  Created by LiuLogan on 15/5/13.
//  Copyright (c) 2015年 OpenShare. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
/**
 分享类型，除了news以外，还可能是video／audio／app等。
 */
typedef enum : NSUInteger {
    OSMultimediaTypeNews,
    OSMultimediaTypeAudio,
    OSMultimediaTypeVideo,
    OSMultimediaTypeApp,
    OSMultimediaTypeFile,
    OSMultimediaTypeUndefined
} OSMultimediaType;
/**
 *  OSMessage保存分享消息数据。
 */
@interface OSMessage : NSObject
@property NSString* title;
@property NSString* desc;
@property NSString* link;
@property UIImage *image;
@property UIImage *thumbnail;
@property OSMultimediaType multimediaType;
//for 微信
@property NSString* extInfo;
@property NSString* mediaDataUrl;
@property NSString* fileExt;
@property (nonatomic, strong) NSData *file;   /// 微信分享gif/文件
/**
 *  判断emptyValueForKeys的value都是空的，notEmptyValueForKeys的value都不是空的。
 *
 *  @param emptyValueForKeys    空值的key
 *  @param notEmptyValueForKeys 非空值的key
 *
 *  @return YES／NO
 */
-(BOOL)isEmpty:(NSArray*)emptyValueForKeys AndNotEmpty:(NSArray*)notEmptyValueForKeys;
@end


typedef void (^shareSuccess)(OSMessage * message);
typedef void (^shareFail)(OSMessage * message,NSError *error);
typedef void (^authSuccess)(NSDictionary * message);
typedef void (^authFail)(NSDictionary * message,NSError *error);
typedef void (^paySuccess)(NSDictionary * message);
typedef void (^payFail)(NSDictionary * message,NSError *error);
/**
 粘贴板数据编码方式，目前只有两种:
 1. [NSKeyedArchiver archivedDataWithRootObject:data];
 2. [NSPropertyListSerialization dataWithPropertyList:data format:NSPropertyListBinaryFormat_v1_0 options:0 error:&err];
 */
typedef enum : NSUInteger {
    OSPboardEncodingKeyedArchiver,
    OSPboardEncodingPropertyListSerialization,
} OSPboardEncoding;
@interface OpenShare : NSObject


+ (OpenShare *)shared;

@property (nonatomic, copy) authSuccess authSuccess;
@property (nonatomic, copy) authFail authFail;

- (void)addWebViewByURL:(NSURL *)URL;

/**
 *  设置平台的key
 *
 *  @param platform 平台名称
 *  @param key      NSDictionary格式的key
 */
+(void)set:(NSString*)platform Keys:(NSDictionary *)key;
/**
 *  获取平台的key
 *
 *  @param platform 平台名称，每个category自行决定。
 *
 *  @return 平台的key(NSDictionary或nil)
 */
+(NSDictionary *)keyFor:(NSString*)platform;

/**
 *  通过UIApplication打开url
 *
 *  @param url 需要打开的url
 */
+(void)openURL:(NSString*)url;
+(BOOL)canOpen:(NSString*)url;
/**
 *  处理被打开时的openurl
 *
 *  @param url openurl
 *
 *  @return 如果能处理，就返回YES。够则返回NO
 */
+(BOOL)handleOpenURL:(NSURL*)url;
+(shareSuccess)shareSuccessCallback;

+(shareFail)shareFailCallback;

+(void)setShareSuccessCallback:(shareSuccess)suc;

+(void)setShareFailCallback:(shareFail)fail;

+(NSURL*)returnedURL;

+(NSDictionary*)returnedData;

+(void)setReturnedData:(NSDictionary*)retData;

+(NSMutableDictionary *)parseUrl:(NSURL*)url;

+(void)setMessage:(OSMessage*)msg;

+(OSMessage*)message;

+(BOOL)beginShare:(NSString*)platform Message:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail;
+(BOOL)beginAuth:(NSString*)platform Success:(authSuccess)success Fail:(authFail)fail;

+(NSString*)base64Encode:(NSString *)input;
+(NSString*)base64Decode:(NSString *)input;
+(NSString*)CFBundleDisplayName;
+(NSString*)CFBundleIdentifier;

+(void)setGeneralPasteboard:(NSString*)key Value:(NSDictionary*)value encoding:(OSPboardEncoding)encoding;
+(NSDictionary*)generalPasteboardData:(NSString*)key encoding:(OSPboardEncoding)encoding;
+(NSString*)base64AndUrlEncode:(NSString *)string;
+(NSString*)urlDecode:(NSString*)input;
+ (UIImage *)screenshot;

+(authSuccess)authSuccessCallback;
+(authFail)authFailCallback;

+(void)setPaySuccessCallback:(paySuccess)suc;

+(void)setPayFailCallback:(payFail)fail;

+(paySuccess)paySuccessCallback;
+(payFail)payFailCallback;

+ (NSData *)dataWithImage:(UIImage *)image;
+ (NSData *)dataWithImage:(UIImage *)image scale:(CGSize)size;

@end


