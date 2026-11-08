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
- (void)testLegacyHelpersRejectBadData {
    XCTAssertNil([OpenShare dataWithImage:nil scale:CGSizeZero]);
    XCTAssertEqualObjects([OpenShare urlDecode:@"%E4%BD%A0%E5%A5%BD+a%2Bb"], @"你好 a+b");
    NSString *key = @"us.gfzj.openshare.test";
    [[UIPasteboard generalPasteboard] setData:[@"invalid" dataUsingEncoding:NSUTF8StringEncoding] forPasteboardType:key];
    XCTAssertNil([OpenShare generalPasteboardData:key encoding:OSPboardEncodingKeyedArchiver]);
    [OpenShare setGeneralPasteboard:key Value:@{@"code": @0} encoding:OSPboardEncodingPropertyListSerialization];
    XCTAssertEqualObjects([OpenShare generalPasteboardData:key encoding:OSPboardEncodingPropertyListSerialization], @{@"code": @0});
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
}
@end
