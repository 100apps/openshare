//
//  WebviewAuthHelpeer.m
//  openshare
//
//  Created by dourgulf on 16/9/18.
//

#import "WebviewAuthHelper.h"
#import "OpenShare.h"

@interface WebviewAuthHelper()

@property (strong, nonatomic) UIView *containerView;
@property (strong, nonatomic) WKWebView *webview;
@property (strong, nonatomic) UIActivityIndicatorView *loadingIV;
@property (strong, nonatomic) NSDictionary *loadingParameters;

@property (strong, nonatomic) id keepInMemory;

@end

@implementation WebviewAuthHelper

- (instancetype)init
{
    self = [super init];
    if (self) {
        _containerView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(8, 20, 80, 36);
        closeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(didPressCloseButton) forControlEvents:UIControlEventTouchUpInside];
        [_containerView addSubview:closeButton];
        
        CGRect frame = [UIScreen mainScreen].bounds;
        frame.origin.y = 25 + 36;
        _webview = [[WKWebView alloc] initWithFrame:frame];
        [_containerView addSubview:_webview];
        _webview.navigationDelegate = self;
        _loadingIV = [[UIActivityIndicatorView alloc] init];
        _loadingIV.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        [_webview addSubview:_loadingIV];
    }
    return self;
}

- (void)dealloc
{
#ifdef DEBUG
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
#endif
}

- (void)startLoadingIndicator{
    _loadingIV.center = _webview.center;
    [_loadingIV startAnimating];
}

- (void)stopLoadingIndicator {
    [_loadingIV stopAnimating];
}

- (void)didPressCloseButton {
    NSLog(@"User cancelled");
    [self closeAuthviewWithResult:nil error:[NSError errorWithDomain:@"User Cancelled" code:-1 userInfo:nil]];
}

#pragma mark 视图显示生命周期
- (void)showAuthview {
    self.keepInMemory = self;
    CGRect frame = _containerView.frame;
    frame.origin.y = frame.size.height;
    _containerView.frame = frame;
    [[UIApplication sharedApplication].keyWindow addSubview:_containerView];
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect newFrame = frame;
        newFrame.origin.y = 0;
        _containerView.frame = newFrame;
    } completion: nil];
}

- (void)closeAuthviewWithResult:(NSDictionary *)info error:(NSError *)err {
    CGRect frame = _containerView.frame;
    frame.origin.y = frame.size.height;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        _containerView.frame = frame;
    } completion:^(BOOL finished) {
        [_containerView removeFromSuperview];
        [OpenShare finishWebAuthWithResult:info error:err];
        self.keepInMemory = nil;
    }];
}

#pragma mark 辅助方法
- (NSDictionary *)extractParametersOfURI:(NSURL *)URL {
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in components.queryItems) {
        [params setObject:item.value forKey:item.name];
    }
    return params;
}

- (BOOL)isFinishRedirectURI:(NSURL *)URL {
    NSString *host = [URL host];
    NSLog(@"isFinishRedirectURI:%@, %@", host, self.finishRedirectURI);
    return self.finishRedirectURI.length > 0 && [self.finishRedirectURI containsString:host];
}

- (void)postRequestURL:(NSURL *)URL completion:(void(^)(NSDictionary *info, NSError *err))handler {
    NSURLSessionConfiguration *configure = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configure];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error == nil && data != nil) {
            NSError *error;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!error && [json isKindOfClass:[NSDictionary class]]) {
                if (handler) {
                    handler(json, nil);
                }
            }
            else {
                NSString *info = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"JSON serailzation error:%@, %@", error, info);
            }
        }
        else {
            if (handler) {
                handler(nil, error);
            }
        }
    }];
    [task resume];
}

#pragma mark - WKWebView代理方法

// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    [self startLoadingIndicator];
}

// 收到服务器的跳转请求的时候触发
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    NSURL *navURL = webView.URL;
    if ([self isFinishRedirectURI:navURL]) {
        NSDictionary *codeParams = [self extractParametersOfURI:navURL];
        NSString *code = codeParams[@"code"];
        if (code.length > 0) {
            [webView stopLoading];
            NSMutableString *userInfoAPI = [NSMutableString stringWithString:@"https://api.weibo.com/oauth2/access_token?"];
            [userInfoAPI appendFormat:@"code=%@", code];
            [userInfoAPI appendFormat:@"&client_id=%@", self.loadingParameters[@"client_id"]];
            [userInfoAPI appendFormat:@"&client_secret=%@", self.loadingParameters[@"client_secret"]];
            [userInfoAPI appendFormat:@"&redirect_uri=%@", self.loadingParameters[@"redirect_uri"]];
            [userInfoAPI appendString:@"&grant_type=authorization_code"];
            NSLog(@"redirect %@", userInfoAPI);
            [self postRequestURL:[NSURL URLWithString:userInfoAPI] completion:^(NSDictionary *info, NSError *err) {
                NSLog(@"completion info:%@", info);
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 把字典修正
                    NSString *accessToken = info[@"access_token"]? : @"";
                    NSString *userID = info[@"uid"] ? : @"";
                    NSDictionary *normalInfo = @{@"accessToken": accessToken, @"userID": userID};
                    [self closeAuthviewWithResult:normalInfo error:err];
                });
            }];
        }
        else {
            [self closeAuthviewWithResult:nil error:nil];
        }
    }
}

// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self stopLoadingIndicator];
    
    // 把微博授权的注册按钮屏蔽掉
    if ([webView.URL.host containsString:@"open.weibo.cn"]) {
        // 这个OAuth认证好可怕呀, 恶意APP是不是可以随便添加脚本获得用户的账号信息....
        NSString *scriptString = @"document.querySelector('aside.logins').style.display = 'none';";
        [webView evaluateJavaScript:scriptString completionHandler:nil];
        // TODO: 这里可能实现不够严谨
        NSDictionary *params = [self extractParametersOfURI:webView.URL];
        if (params.count > 0) {
            self.loadingParameters = params;
        }
    }
}

// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [self stopLoadingIndicator];
    NSURL *failingURL = [[error userInfo] objectForKey:NSURLErrorFailingURLErrorKey];
    if (![self isFinishRedirectURI:failingURL]) {
        [self closeAuthviewWithResult:nil error:error];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    [self stopLoadingIndicator];
    NSURL *failingURL = [[error userInfo] objectForKey:NSURLErrorFailingURLErrorKey];
    if (![self isFinishRedirectURI:failingURL]) {
        [self closeAuthviewWithResult:nil error:error];
    }
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    [self stopLoadingIndicator];
    [self closeAuthviewWithResult:nil error:[NSError errorWithDomain:@"Terminated" code:-2 userInfo:nil]];
}

@end
