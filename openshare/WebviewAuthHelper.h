//
//  WebviewAuthHelpeer.h
//  openshare
//
//  Created by dourgulf on 16/9/18.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface WebviewAuthHelper : NSObject <WKNavigationDelegate>

@property (copy, nonatomic) NSString *finishRedirectURI;
@property (strong, readonly, nonatomic) WKWebView *webview;
@property (strong, readonly, nonatomic) UIActivityIndicatorView *loadingIV;

- (void)showAuthview;


@end
