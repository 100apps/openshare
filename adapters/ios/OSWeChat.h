#import <OpenShare/OpenShare.h>
#import <WechatOpenSDK/WXApi.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^OSWeChatCompletion)(BaseResp * _Nullable response, NSError * _Nullable error);
FOUNDATION_EXPORT NSErrorDomain const OSWeChatErrorDomain;

/// One retained instance per application, used on the main thread. Uses the official SDK.
@interface OSWeChat : NSObject <WXApiDelegate>
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithAppID:(NSString *)appID universalLink:(NSString *)universalLink;
- (BOOL)handleOpenURL:(NSURL *)url;
- (BOOL)handleUniversalLink:(NSUserActivity *)activity;
- (void)shareMessage:(OSMessage *)message scene:(int)scene completion:(OSWeChatCompletion)completion;
/// Code exchange belongs on your server. The adapter checks a random OAuth state.
- (void)authorize:(NSString *)scope completion:(OSWeChatCompletion)completion;
/// Advanced media requests and server-signed PayReq. Use authorize: for OAuth requests.
- (void)sendRequest:(BaseReq *)request completion:(OSWeChatCompletion)completion;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
