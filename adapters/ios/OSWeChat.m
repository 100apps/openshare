#import "OSWeChat.h"

NSErrorDomain const OSWeChatErrorDomain = @"us.gfzj.openshare.wechat";

@interface OSWeChat ()
@property (nonatomic, copy) OSWeChatCompletion pending;
@property (nonatomic, copy) NSString *authState;
@property (nonatomic, strong) BaseReq *pendingRequest;
@end

@implementation OSWeChat
- (instancetype)initWithAppID:(NSString *)appID universalLink:(NSString *)universalLink {
    NSURL *url = [NSURL URLWithString:universalLink];
    if (!appID.length || ![url.scheme isEqualToString:@"https"] || !url.host.length ||
        ![url.path hasSuffix:@"/"] || url.query || url.fragment || url.user || url.password) return nil;
    self = [super init];
    if (self && ![WXApi registerApp:appID universalLink:universalLink]) return nil;
    return self;
}

- (BOOL)handleOpenURL:(NSURL *)url { return [WXApi handleOpenURL:url delegate:self]; }
- (BOOL)handleUniversalLink:(NSUserActivity *)activity { return [WXApi handleOpenUniversalLink:activity delegate:self]; }

- (NSError *)error:(NSInteger)code description:(NSString *)description {
    return [NSError errorWithDomain:OSWeChatErrorDomain code:code
                          userInfo:@{NSLocalizedDescriptionKey: description}];
}

- (void)shareMessage:(OSMessage *)message scene:(int)scene completion:(OSWeChatCompletion)completion {
    if (!message || scene < 0 || scene > 2 || message.file.length || message.fileURL ||
        (message.multimediaType != OSMultimediaTypeNews && message.multimediaType != OSMultimediaTypeUndefined)) {
        completion(nil, [self error:1 description:@"Use sendRequest: for advanced official SDK media objects."]);
        return;
    }
    SendMessageToWXReq *request = [SendMessageToWXReq new];
    request.scene = scene;
    if (message.link.length) {
        NSURL *url = [NSURL URLWithString:message.link];
        if (!url.host.length || ![@[@"http", @"https"] containsObject:url.scheme.lowercaseString]) {
            completion(nil, [self error:1 description:@"An absolute HTTP(S) URL is required."]);
            return;
        }
        WXWebpageObject *object = [WXWebpageObject object];
        object.webpageUrl = message.link;
        request.message = [WXMediaMessage message];
        request.message.mediaObject = object;
    } else if (message.image) {
        WXImageObject *object = [WXImageObject object];
        object.imageData = UIImageJPEGRepresentation(message.image, 0.9);
        request.message = [WXMediaMessage message];
        request.message.mediaObject = object;
    } else if (message.title.length) {
        request.bText = YES;
        request.text = message.title;
    } else {
        completion(nil, [self error:1 description:@"The message is empty."]);
        return;
    }
    request.message.title = message.title;
    request.message.description = message.desc;
    if (message.thumbnail) request.message.thumbData = UIImageJPEGRepresentation(message.thumbnail, 0.8);
    [self sendRequest:request completion:completion];
}

- (void)authorize:(NSString *)scope completion:(OSWeChatCompletion)completion {
    if (!scope.length) { completion(nil, [self error:1 description:@"Scope is required."]); return; }
    SendAuthReq *request = [SendAuthReq new];
    request.scope = scope;
    request.state = [NSUUID UUID].UUIDString;
    [self startRequest:request state:request.state completion:completion];
}

- (void)sendRequest:(BaseReq *)request completion:(OSWeChatCompletion)completion {
    if (![request isKindOfClass:SendMessageToWXReq.class] && ![request isKindOfClass:PayReq.class]) {
        completion(nil, [self error:1 description:@"Use a media/payment request, or authorize: for OAuth."]);
        return;
    }
    [self startRequest:request state:nil completion:completion];
}

- (void)startRequest:(BaseReq *)request state:(NSString *)state completion:(OSWeChatCompletion)completion {
    NSAssert(NSThread.isMainThread, @"Use OSWeChat on the main thread.");
    if (!request || !completion) return;
    if (self.pendingRequest) { completion(nil, [self error:2 description:@"A request is already pending."]); return; }
    if (![WXApi isWXAppInstalled]) { completion(nil, [self error:3 description:@"WeChat is not installed."]); return; }
    self.pending = completion;
    self.authState = state;
    self.pendingRequest = request;
    // The SDK completion only says whether dispatch succeeded. onResp: carries the result.
    [WXApi sendReq:request completion:^(BOOL success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!success && self.pendingRequest == request) {
                [self finish:nil error:[self error:4 description:@"WeChat rejected the request."]];
            }
        });
    }];
}

- (void)onReq:(BaseReq *)request {}
- (void)onResp:(BaseResp *)response {
    NSAssert(NSThread.isMainThread, @"Handle WeChat responses on the main thread.");
    if (!self.pendingRequest || !response) return;
    if ([self.pendingRequest isKindOfClass:SendAuthReq.class]) {
        if (![response isKindOfClass:SendAuthResp.class] ||
            ![self.authState isEqualToString:((SendAuthResp *)response).state]) return;
    } else if ([self.pendingRequest isKindOfClass:SendMessageToWXReq.class]) {
        if (![response isKindOfClass:SendMessageToWXResp.class]) return;
    } else if ([self.pendingRequest isKindOfClass:PayReq.class]) {
        if (![response isKindOfClass:PayResp.class]) return;
    } else {
        [self finish:nil error:[self error:1 description:@"Unsupported response type."]];
        return;
    }
    NSError *error = response.errCode == WXSuccess ? nil :
        [self error:response.errCode description:response.errStr ?: @"WeChat request failed or was cancelled."];
    [self finish:response error:error];
}

- (void)finish:(BaseResp *)response error:(NSError *)error {
    OSWeChatCompletion callback = self.pending;
    self.pending = nil;
    self.pendingRequest = nil;
    self.authState = nil;
    if (callback) callback(response, error);
}

- (void)cancel {
    NSAssert(NSThread.isMainThread, @"Cancel on the main thread.");
    OSWeChatCompletion callback = self.pending;
    self.pending = nil;
    if (callback) callback(nil, [self error:WXErrCodeUserCancel description:@"Request cancelled locally."]);
}
@end
