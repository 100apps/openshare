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
/// SendMessageToWXReq (advanced media) or server-signed PayReq. Use authorize: for OAuth.
- (void)sendRequest:(BaseReq *)request completion:(OSWeChatCompletion)completion;
/// Releases the callback. The SDK cannot abort an external request; a new request remains
/// busy until its response arrives, preventing a late response from completing the next share.
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
