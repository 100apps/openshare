# 微信官方 SDK 接入

适配器不在基础分享中自动启用。请先完成微信开放平台应用审核，取得你自己的 App ID；代码示例中的域名、包名和 App ID 均需替换。SDK 初始化应遵循应用自己的隐私授权流程。

## iOS

```ruby
pod 'OpenShare/WeChat', :path => '../openshare'
```

Swift Package 的默认 product 只提供基础库。使用 SPM 的项目可以自行链接官方 XCFramework，再把 `adapters/ios` 加到一个依赖 `OpenShare` 的模块；仓库内 `ios/project.yml` 展示了所需的系统链接库。

在主线程创建并长期保留一个实例：

```objc
#import <OpenShare/OSWeChat.h>

self.wechat = [[OSWeChat alloc] initWithAppID:@"你的微信AppID"
                             universalLink:@"https://你的域名/wechat/"];
// nil 表示 URL 语法或 SDK 注册失败，不能继续发送请求。

OSMessage *message = [OSMessage new];
message.title = @"Hello";
message.link = @"https://example.com/article";
[self.wechat shareMessage:message scene:WXSceneSession completion:^(BaseResp *response, NSError *error) {
    // 错误码保留微信 errCode，包括 WXErrCodeUserCancel。
}];
```

Universal Link 必须是 HTTPS，以 `/` 结尾，并与开放平台登记内容一致。App 的 Associated Domains 添加 `applinks:你的域名`，域名上提供可通过 HTTPS 直接访问的 AASA，包含你的 Team ID、Bundle ID 和匹配路径。Info.plist 配置：

```xml
<key>CFBundleURLTypes</key>
<array><dict><key>CFBundleURLSchemes</key><array><string>你的微信AppID</string></array></dict></array>
<key>LSApplicationQueriesSchemes</key>
<array><string>weixin</string><string>weixinULAPI</string><string>weixinURLParamsAPI</string></array>
```

将系统回调转交给同一个 adapter 实例，返回实际处理结果。以下示例中的 `self.wechat` 是应用持有的实例，不要每次回调都重新创建：

```objc
// AppDelegate（未使用 Scene 时）：
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary *)options {
    return [self.wechat handleOpenURL:url];
}
- (BOOL)application:(UIApplication *)app continueUserActivity:(NSUserActivity *)activity
 restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))handler {
    return [self.wechat handleUniversalLink:activity];
}

// SceneDelegate（使用 Scene 时，取应用长期持有的同一个 wechat 实例）：
- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)contexts {
    for (UIOpenURLContext *context in contexts) [self.wechat handleOpenURL:context.URL];
}
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)activity {
    [self.wechat handleUniversalLink:activity];
}
```

冷启动的 Scene 回调在 `scene:willConnectToSession:options:` 的 `connectionOptions.URLContexts` 和 `connectionOptions.userActivities` 中，需要同样转交。业务层应自行恢复进程退出前的业务状态；没有 pending 请求时 adapter 不会伪造 completion。

```objc
[self.wechat authorize:@"snsapi_userinfo" completion:^(BaseResp *response, NSError *error) {
    if (!error && [response isKindOfClass:SendAuthResp.class]) {
        NSString *code = ((SendAuthResp *)response).code;
        // 把 code 发给自己的服务端兑换令牌。
    }
}];

// 图片：OSMessage.image。文件、音视频、小程序：构建官方对象，交给适配器。
SendMessageToWXReq *request = [SendMessageToWXReq new];
request.scene = WXSceneSession;
request.message = mediaMessage; // 自己按官方文档配置的 WXMediaMessage
[self.wechat sendRequest:request completion:completion];
// 支付：同一入口传入由服务端签名数据填充的 PayReq。
```

所有请求和回调在主线程使用。`cancel` 仅取消本地回调，无法撤回微信中的操作；在旧响应到达前新请求返回 busy。见[回调约束](modernization.md)。不要同时把相同微信回调交给旧 `OpenShare+Weixin` 协议解析器。

## Android

加入 `android/openshare-wechat` 模块，再 `implementation project(':openshare-wechat')`。这个模块带官方 SDK 依赖及 Android 11+ 所需的微信 package query；基础模块没有此依赖。

```java
// Application 或其他长期持有者中，在自己的授权流程完成后初始化，主线程调用：
WeChat wechat = new WeChat(context, "你的微信AppID");
wechat.shareText("Hello", SendMessageToWX.Req.WXSceneSession, (response, error) -> {
    // error 为 null / busy / not_installed / invalid_request / invalid_response / send_failed / cancelled / wechat_error。
    // response 非 null 时保留原始 errCode / errStr。
});
wechat.shareLink("https://example.com/article", "Hello", "description", 0, callback);
wechat.authorize("snsapi_userinfo", (response, error) -> {
    if (error == null) {
        String code = ((SendAuth.Resp) response).code;
        // 由自己的服务端兑换，不在客户端嵌入 app secret。
    }
});
// 高级媒体：wechat.share(mediaMessage, scene, callback);
// 支付：wechat.send(serverSignedPayReq, callback);
```

应用包名、发行签名必须与微信开放平台登记内容一致。库不提供使用自有包名的回调 Activity，宿主需要在**自己 applicationId 对应的包**下创建 `wxapi.WXEntryActivity`：

```java
package your.application.id.wxapi;

public class WXEntryActivity extends android.app.Activity {
    @Override protected void onCreate(android.os.Bundle state) {
        super.onCreate(state);
        handle(getIntent());
    }
    @Override protected void onNewIntent(android.content.Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handle(intent);
    }
    private void handle(android.content.Intent intent) {
        // App.wechat() 返回进程内同一个实例；冷启动按自己的初始化/授权流程恢复。
        ((your.application.id.App) getApplication()).wechat().handleIntent(intent);
        finish();
    }
}
```

```xml
<activity android:name=".wxapi.WXEntryActivity"
    android:exported="true" android:launchMode="singleTask" />
```

若使用微信支付，再创建 `wxapi.WXPayEntryActivity`（可继承上述 Activity）并在 manifest 同样声明。只有 SDK 校验通过且与在途 transaction / OAuth state 匹配的响应才完成回调。回调 Activity、adapter 操作都在主线程执行。`cancel()` 释放待处理 callback；请由业务层处理页面退出与超时策略。

## 必须真机确认的项目

两端的 SDK 编译、错误映射与回调状态机可以自动化验证，但开放平台审核、Universal Links 域名、AASA、Android 签名、微信实际收发和支付商户回调不能用测试替身代替。使用[真机验收表](modernization.md)记录结果后再决定是否发布。

官方资料：[iOS 接入](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)、[Android 接入](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/Android.html)。
