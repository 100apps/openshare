#import <XCTest/XCTest.h>
#import <OpenShare/OpenShareHeader.h>
#import <OpenShareWeChat/OSWeChat.h>
#import <objc/runtime.h>

// Replace only SDK transport in tests: requests and responses remain the real SDK types.
static BaseReq *sentRequest;
static BOOL testInstalled = YES;
static BOOL testSendAccepted = YES;
@interface WXApi (OpenShareTests)
+ (BOOL)os_testInstalled;
+ (void)os_testSend:(BaseReq *)request completion:(void (^)(BOOL))completion;
+ (BOOL)os_testRegister:(NSString *)appID universalLink:(NSString *)link;
@end
@implementation WXApi (OpenShareTests)
+ (BOOL)os_testInstalled { return testInstalled; }
+ (void)os_testSend:(BaseReq *)request completion:(void (^)(BOOL))completion {
    sentRequest = request;
    completion(testSendAccepted);
}
+ (BOOL)os_testRegister:(NSString *)appID universalLink:(NSString *)link { return YES; }
@end

@interface OpenShareTests : XCTestCase
@end
@implementation OpenShareTests
+ (void)setUp {
    [super setUp];
    method_exchangeImplementations(class_getClassMethod(WXApi.class, @selector(isWXAppInstalled)),
                                   class_getClassMethod(WXApi.class, @selector(os_testInstalled)));
    method_exchangeImplementations(class_getClassMethod(WXApi.class, @selector(sendReq:completion:)),
                                   class_getClassMethod(WXApi.class, @selector(os_testSend:completion:)));
    method_exchangeImplementations(class_getClassMethod(WXApi.class, @selector(registerApp:universalLink:)),
                                   class_getClassMethod(WXApi.class, @selector(os_testRegister:universalLink:)));
}
+ (void)tearDown {
    method_exchangeImplementations(class_getClassMethod(WXApi.class, @selector(isWXAppInstalled)),
                                   class_getClassMethod(WXApi.class, @selector(os_testInstalled)));
    method_exchangeImplementations(class_getClassMethod(WXApi.class, @selector(sendReq:completion:)),
                                   class_getClassMethod(WXApi.class, @selector(os_testSend:completion:)));
    method_exchangeImplementations(class_getClassMethod(WXApi.class, @selector(registerApp:universalLink:)),
                                   class_getClassMethod(WXApi.class, @selector(os_testRegister:universalLink:)));
    [super tearDown];
}
- (void)setUp { testInstalled = YES; testSendAccepted = YES; sentRequest = nil; }

- (void)testSystemShareItemsPreserveUnicodeAndLinks {
    OSMessage *message = [OSMessage new];
    message.title = @"你好";
    message.link = @"https://example.com/?a=1&b=2";
    NSError *error = nil;
    NSArray *items = [OpenShare systemActivityItemsForMessage:message error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(items[0], @"你好");
    XCTAssertEqualObjects([items[1] absoluteString], message.link);
}
- (void)testSystemRejectsEmptyUnsafeAndUnreadableContent {
    OSMessage *message = [OSMessage new];
    NSError *error = nil;
    XCTAssertNil([OpenShare systemActivityItemsForMessage:message error:&error]);
    XCTAssertEqual(error.code, OSSystemShareErrorInvalidMessage);
    message.link = @"javascript:alert(1)";
    XCTAssertNil([OpenShare systemActivityItemsForMessage:message error:nil]);
    message.link = nil;
    message.fileURL = [NSURL fileURLWithPath:@"/missing/file.pdf"];
    XCTAssertNil([OpenShare systemActivityItemsForMessage:message error:nil]);
    message.fileURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    XCTAssertNil([OpenShare systemActivityItemsForMessage:message error:nil]);
}
- (void)testReadableFileCanBeSharedWithoutCopying {
    NSURL *file = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [@"attachment" writeToURL:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
    OSMessage *message = [OSMessage new];
    message.fileURL = file;
    XCTAssertEqualObjects([OpenShare systemActivityItemsForMessage:message error:nil], @[file]);
    [[NSFileManager defaultManager] removeItemAtURL:file error:nil];
}
- (void)testInvalidPresenterReturnsErrorInsteadOfPresenting {
    OSMessage *message = [OSMessage new];
    message.title = @"hello";
    __block BOOL called = NO;
    [OpenShare shareMessage:message fromViewController:[UIViewController new] sourceView:[UIView new]
                completion:^(BOOL completed, NSError *error) {
        called = YES;
        XCTAssertFalse(completed);
        XCTAssertEqual(error.code, OSSystemShareErrorInvalidPresenter);
    }];
    XCTAssertTrue(called);
}
- (void)testSystemSharePresentsWithPopoverAnchor {
    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] && scene.activationState == UISceneActivationStateForegroundActive) {
            window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
            break;
        }
    }
    UIViewController *presenter = [UIViewController new];
    window.rootViewController = presenter;
    [window makeKeyAndVisible];
    OSMessage *message = [OSMessage new];
    message.title = @"OpenShare";
    [OpenShare shareMessage:message fromViewController:presenter sourceView:presenter.view completion:nil];
    XCTAssertTrue([presenter.presentedViewController isKindOfClass:UIActivityViewController.class]);
    XCTNSPredicateExpectation *shown = [[XCTNSPredicateExpectation alloc]
        initWithPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
            return presenter.presentedViewController.view.window != nil &&
                   !presenter.presentedViewController.isBeingPresented;
        }] object:nil];
    [self waitForExpectations:@[shown] timeout:5];
    UIPopoverPresentationController *popover = presenter.presentedViewController.popoverPresentationController;
    XCTAssertEqual(popover.sourceView, presenter.view);
    XCTAssertTrue(CGRectEqualToRect(popover.sourceRect, presenter.view.bounds));
    UIImage *screenshot = [OpenShare screenshot];
    XCTAssertNotNil(screenshot);
    if (screenshot) {
        XCTAttachment *attachment = [XCTAttachment attachmentWithImage:screenshot];
        attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
        [self addAttachment:attachment];
    }
    [presenter dismissViewControllerAnimated:NO completion:nil];
    window.hidden = YES;
}
- (void)testLegacyHelpersRejectBadData {
    XCTAssertNil([OpenShare dataWithImage:nil scale:CGSizeZero]);
    XCTAssertEqualObjects([OpenShare urlDecode:@"%E4%BD%A0%E5%A5%BD+a%2Bb"], @"你好 a+b");
    // Test untrusted decoding without the simulator's host-clipboard daemon.
    XCTAssertNil([OpenShare decodePasteboardData:[@"invalid" dataUsingEncoding:NSUTF8StringEncoding] encoding:OSPboardEncodingKeyedArchiver]);
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:@{@"code": @0}
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    XCTAssertEqualObjects([OpenShare decodePasteboardData:plist encoding:OSPboardEncodingPropertyListSerialization], @{@"code": @0});
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:@{@"code": @0} requiringSecureCoding:YES error:nil];
    XCTAssertEqualObjects([OpenShare decodePasteboardData:archive encoding:OSPboardEncodingKeyedArchiver], @{@"code": @0});
    NSData *arrayArchive = [NSKeyedArchiver archivedDataWithRootObject:@[@"invalid-root"] requiringSecureCoding:YES error:nil];
    XCTAssertNil([OpenShare decodePasteboardData:arrayArchive encoding:OSPboardEncodingKeyedArchiver]);
}
- (void)testWeChatRejectsInsecureUniversalLinks {
    XCTAssertNil([[OSWeChat alloc] initWithAppID:@"wx-test" universalLink:@"http://example.com/wx/"]);
    XCTAssertNil([[OSWeChat alloc] initWithAppID:@"wx-test" universalLink:@"https://example.com/wx"]);
}
- (OSWeChat *)client { return [[OSWeChat alloc] initWithAppID:@"wx-test" universalLink:@"https://example.com/wx/"]; }
- (void)testWeChatChecksAuthStateAndCompletesOnce {
    OSWeChat *client = [self client];
    __block NSInteger count = 0;
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) { count++; XCTAssertNil(error); }];
    SendAuthResp *response = [SendAuthResp new];
    response.state = @"wrong";
    [client onResp:response];
    XCTAssertEqual(count, 0);
    response.state = ((SendAuthReq *)sentRequest).state;
    response.code = @"server-exchange-code";
    [client onResp:response];
    [client onResp:response];
    XCTAssertEqual(count, 1);
}
- (void)testWeChatReportsBusyMissingAppAndCancel {
    OSWeChat *client = [self client];
    testInstalled = NO;
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) { XCTAssertEqual(error.code, 3); }];
    testInstalled = YES;
    __block NSInteger count = 0;
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) { count++; XCTAssertEqual(error.code, WXErrCodeUserCancel); }];
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) { XCTAssertEqual(error.code, 2); }];
    [client cancel];
    [client cancel];
    XCTAssertEqual(count, 1);
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) { XCTAssertEqual(error.code, 2); }];
    SendAuthResp *late = [SendAuthResp new];
    late.state = ((SendAuthReq *)sentRequest).state;
    [client onResp:late];
    XCTAssertEqual(count, 1);
}
- (void)testWeChatRejectsEmptySuccessfulAuthorizationCode {
    OSWeChat *client = [self client];
    __block BOOL called = NO;
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) {
        called = YES;
        XCTAssertEqual(error.code, 5);
    }];
    SendAuthResp *response = [SendAuthResp new];
    response.state = ((SendAuthReq *)sentRequest).state;
    [client onResp:response];
    XCTAssertTrue(called);
}
- (void)testWeChatShareWaitsForSDKResponseAndPreservesCancellation {
    OSWeChat *client = [self client];
    OSMessage *message = [OSMessage new];
    message.title = @"Hello";
    __block NSInteger count = 0;
    [client shareMessage:message scene:WXSceneSession completion:^(BaseResp *response, NSError *error) {
        count++;
        XCTAssertEqual(error.code, WXErrCodeUserCancel);
    }];
    XCTAssertEqual(count, 0); // Transport acceptance must never be reported as share success.
    SendMessageToWXResp *response = [SendMessageToWXResp new];
    response.errCode = WXErrCodeUserCancel;
    [client onResp:response];
    [client onResp:response];
    XCTAssertEqual(count, 1);
}
- (void)testWeChatReportsAsynchronousDispatchFailure {
    OSWeChat *client = [self client];
    testSendAccepted = NO;
    XCTestExpectation *failed = [self expectationWithDescription:@"SDK dispatch failed"];
    [client authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) {
        XCTAssertEqual(error.code, 4);
        [failed fulfill];
    }];
    [self waitForExpectations:@[failed] timeout:5];
}
@end
