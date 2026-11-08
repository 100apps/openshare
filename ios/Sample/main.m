#import <UIKit/UIKit.h>
#import <OpenShare/OpenShare+System.h>

@interface OSShareViewController : UIViewController
@end
@implementation OSShareViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.accessibilityIdentifier = @"openshare.share";
    [button setTitle:@"Share / 分享" forState:UIControlStateNormal];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button addTarget:self action:@selector(share:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [button.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor]
    ]];
}
- (void)share:(UIButton *)sender {
    OSMessage *message = [OSMessage new];
    message.title = @"OpenShare";
    message.link = @"https://github.com/100apps/openshare";
    [OpenShare shareMessage:message fromViewController:self sourceView:sender completion:nil];
}
@end

@interface OSShareSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation OSShareSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [OSShareViewController new];
    [self.window makeKeyAndVisible];
}
@end

@interface OSShareAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation OSShareAppDelegate
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(OSShareAppDelegate.class));
    }
}
