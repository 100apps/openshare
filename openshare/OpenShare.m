//
//  OpenShare.m
//  openshare
//
//  Created by LiuLogan on 15/5/13.
//  Copyright (c) 2015年 OpenShare. All rights reserved.
//

#import "OpenShare.h"
#import <WebKit/WebKit.h>

@interface OpenShare() <WKNavigationDelegate>

@end


@implementation OpenShare

+ (OpenShare *)shared {
    static OpenShare *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    
    return _instance;
}

- (id)init {
    self = [super init];
    if (self) {
    }
    
    return self;
}

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
static shareSuccess shareSuccessCallback;
static shareFail shareFailCallback;

static authSuccess authSuccessCallback;
static authFail authFailCallback;

static paySuccess paySuccessCallback;
static payFail payFailCallback;

static OSMessage *message;
+(shareSuccess)shareSuccessCallback{
    return shareSuccessCallback;
}
+(shareFail)shareFailCallback{
    return shareFailCallback;
}
+(void)setShareSuccessCallback:(shareSuccess)suc{
    shareSuccessCallback=suc;
}
+(void)setShareFailCallback:(shareFail)fail{
    shareFailCallback=fail;
}
+(void)setPaySuccessCallback:(paySuccess)suc{
    paySuccessCallback=suc;
}
+(void)setPayFailCallback:(payFail)fail{
    payFailCallback=fail;
}
+(paySuccess)paySuccessCallback{
    return paySuccessCallback;
}
+(payFail)payFailCallback{
    return payFailCallback;
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
+(authSuccess)authSuccessCallback{
    return authSuccessCallback;
}
+(authFail)authFailCallback{
    return authFailCallback;
}
+(BOOL)beginShare:(NSString*)platform Message:(OSMessage*)msg Success:(shareSuccess)success Fail:(shareFail)fail{
    if ([self keyFor:platform]) {
        message=msg;
        shareSuccessCallback=success;
        shareFailCallback=fail;
        return YES;
    }else{
        NSLog(@"please connect%@ before you can share to it!!!",platform);
        return NO;
    }
}
+(BOOL)beginAuth:(NSString*)platform Success:(authSuccess)success Fail:(authFail)fail{
    if ([self keyFor:platform]) {
        authSuccessCallback=success;
        authFailCallback=fail;
        return YES;
    }else{
        NSLog(@"please connect%@ before you can share to it!!!",platform);
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
+(NSString*)urlDecode:(NSString*)input{
   return [[input stringByReplacingOccurrencesOfString:@"+" withString:@" "]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
/**
 *  截屏功能。via：http://stackoverflow.com/a/8017292/3825920
 *
 *  @return 对当前窗口截屏。（支付宝可能需要）
 */
+ (UIImage *)screenshot
{
    CGSize imageSize = CGSizeZero;
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        imageSize = [UIScreen mainScreen].bounds.size;
    } else {
        imageSize = CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, window.center.x, window.center.y);
        CGContextConcatCTM(context, window.transform);
        CGContextTranslateCTM(context, -window.bounds.size.width * window.layer.anchorPoint.x, -window.bounds.size.height * window.layer.anchorPoint.y);
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            CGContextRotateCTM(context, M_PI_2);
            CGContextTranslateCTM(context, 0, -imageSize.width);
        } else if (orientation == UIInterfaceOrientationLandscapeRight) {
            CGContextRotateCTM(context, -M_PI_2);
            CGContextTranslateCTM(context, -imageSize.height, 0);
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            CGContextRotateCTM(context, M_PI);
            CGContextTranslateCTM(context, -imageSize.width, -imageSize.height);
        }
        if ([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
        } else {
            [window.layer renderInContext:context];
        }
        CGContextRestoreGState(context);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (NSData *)dataWithImage:(UIImage *)image {
    return UIImageJPEGRepresentation(image, 1);
}

+ (NSData *)dataWithImage:(UIImage *)image scale:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0,0, size.width, size.height)];
    UIImage* scaledImage =UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return UIImageJPEGRepresentation(scaledImage, 1);
}

- (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)size{
       UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0,0, size.width, size.height)];
    UIImage* scaledImage =UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}

- (void)hideWebView:(WKWebView *)webView withOAuthDic:(NSDictionary *)OAuthDic {
    [self activityIndicatorViewAction:webView stop:YES];
    [webView stopLoading];
    
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        webView.frame = CGRectMake(0, UIScreen.mainScreen.bounds.size.height, webView.frame.size.width, webView.frame.size.height);
    } completion:^(BOOL finished) {
        [webView removeFromSuperview];
        if (!OAuthDic) {
            return;
        }
        
        if (OAuthDic[@"error"]) {
            if (self.authFail) {
                self.authFail(nil, OAuthDic[@"error"]);
            }
        } else if (OAuthDic[@"JSON"]) {
            if (self.authSuccess) {
                NSDictionary *dic = OAuthDic[@"JSON"];
                self.authSuccess(@{@"accessToken": (dic[@"access_token"] ?: [NSNull null]),
                                   @"userID": (dic[@"uid"] ?: [NSNull null])});
            }
        }
    }];
}

- (void)activityIndicatorViewAction:(WKWebView *)webView stop:(BOOL)stop {
    for (UIActivityIndicatorView *view in webView.scrollView.subviews) {
        if ([view isKindOfClass:[UIActivityIndicatorView class]]) {
            if (stop) {
                [view stopAnimating];
            } else {
                [view startAnimating];
            }
        }
    }
}

- (void)addWebViewByURL:(NSURL *)URL {
    WKWebView *webView = [WKWebView new];
    webView.frame = UIScreen.mainScreen.bounds;
    webView.navigationDelegate = self;
    webView.backgroundColor = [UIColor whiteColor];
    webView.frame = CGRectMake(0, 20, webView.frame.size.width, webView.frame.size.height - 20);
    
    [webView loadRequest:[NSURLRequest requestWithURL:URL]];

    
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    indicator.center = CGPointMake(CGRectGetMidX(webView.bounds), CGRectGetMidY(webView.bounds)+30);
    indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [webView.scrollView addSubview:indicator];
    [indicator startAnimating];
    
    [[UIApplication sharedApplication].keyWindow addSubview:webView];
    [UIView animateWithDuration:0.32 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        webView.frame = CGRectMake(0, 20, webView.frame.size.width, webView.frame.size.height);
    } completion:nil];
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    if (!webView.URL) {
        return;
    }
    
    if ([webView.URL.absoluteString containsString:@"about:blank"]) {
        [self hideWebView:webView withOAuthDic:nil];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self activityIndicatorViewAction:webView stop:YES];
    if (!webView.URL) {
        return;
    }
    
    NSString *absoluteString = webView.URL.absoluteString;
    NSMutableString *scriptString = [@"var button = document.createElement('a'); button.setAttribute('href', 'about:blank'); button.innerHTML = '关闭'; button.setAttribute('style', 'width: calc(100% - 40px); background-color: gray;display: inline-block;height: 40px;line-height: 40px;text-align: center;color: #777777;text-decoration: none;border-radius: 3px;background: linear-gradient(180deg, white, #f1f1f1);border: 1px solid #CACACA;box-shadow: 0 2px 3px #DEDEDE, inset 0 0 0 1px white;text-shadow: 0 2px 0 white;position: fixed;left: 0;bottom: 0;margin: 20px;font-size: 18px;'); document.body.appendChild(button);" mutableCopy];
    if ([absoluteString containsString:@"open.weibo.cn"]) {
        [scriptString appendString:@"document.querySelector('aside.logins').style.display = 'none';"];
    }
    [webView evaluateJavaScript:scriptString completionHandler:nil];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorNotConnectedToInternet) {
        NSLog(@"error: lost connection");
    }
}

- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    if (!webView.URL) {
        return;
    }
    
    // Weibo OAuth
    if ([webView.URL.absoluteString.lowercaseString hasPrefix:[OpenShare keyFor:@"Weibo"][@"redirectURI"]]) {
        [webView stopLoading];
        
        NSURLComponents *components = [NSURLComponents componentsWithURL:webView.URL resolvingAgainstBaseURL:NO];
        NSMutableDictionary *queryDic = [NSMutableDictionary new];
        for (NSURLQueryItem *item in components.queryItems) {
            [queryDic setObject:item.value forKey:item.name];
        }
        
        if (!queryDic[@"code"]) {
            return;
        }
        
        NSMutableString *string = [NSMutableString new];
        [string appendFormat:@"https://api.weibo.com/oauth2/access_token?"];
        [string appendFormat:@"client_id=%@", [OpenShare keyFor:@"Weibo"][@"appKey"]];
        [string appendFormat:@"&client_secret=%@", [OpenShare keyFor:@"Weibo"][@"appSecret"]];
        [string appendFormat:@"&grant_type=authorization_code&"];
        [string appendFormat:@"redirect_uri=%@", [OpenShare keyFor:@"Weibo"][@"redirectURI"]];
        [string appendFormat:@"&code=%@", queryDic[@"code"]];
        
        [self activityIndicatorViewAction:webView stop:NO];
        
        NSString *urlString = [string stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSURL *url = [NSURL URLWithString:urlString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
        [request setHTTPMethod:@"POST"];
        NSURLSession *sharedSession = [NSURLSession sharedSession];
        NSURLSessionDataTask *dataTask = [sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (data && (error == nil)) {
                    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data
                                                                               options:NSJSONReadingAllowFragments
                                                                                 error:nil];
                    [self hideWebView:webView withOAuthDic:@{@"JSON":jsonObject}];
                } else {
                    [self hideWebView:webView withOAuthDic:@{@"error":error}];
                }
            });
        }];
        [dataTask resume];
    }
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
