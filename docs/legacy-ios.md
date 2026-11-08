![](https://github.com/100apps/openshare/raw/gh-pages/images/slogo.png)

<p align="center">
    <a href="https://travis-ci.org/100apps/openshare">
        <img src="https://img.shields.io/travis/100apps/openshare.svg">
    </a>
    <a href="http://cocoapods.org/pods/OpenShare">
        <img src="https://img.shields.io/cocoapods/v/OpenShare.svg?style=flat">
    </a>
    <a href="http://cocoapods.org/pods/OpenShare">
        <img src="https://img.shields.io/cocoapods/p/OpenShare.svg?style=flat">
    </a>
    <a href="https://github.com/100apps/openshare/blob/master/LICENSE">
        <img src="https://img.shields.io/cocoapods/l/OpenShare.svg?style=flat">
    </a>
    <a href="https://twitter.com/thinkphone">
        <img src="https://img.shields.io/badge/twitter-@thinkphone-blue.svg?style=flat">
    </a>
</p>

OpenShare 的功能就是替代官方的 SDK 向各个平台的移动客户端（比如 QQ）发起请求（分享、OAuth），然后接收返回结果。

OpenShare 非常小，目前支持 QQ、微信、微博、人人，只有几百行代码。即使你不在项目中使用 OpenShare，也可以 clone 下来研究一下 App 和客户端之间的通信机制，所以给个 star 是值得的。

注：为方便书写，如无特殊说明，下文中的「*客户端*」指的是 QQ、微信、微博这样的社交软件官方开发的客户端；「*App*」特指我们自己开发的应用。

## 预览

![](https://github.com/100apps/openshare/raw/gh-pages/images/demo.gif)

## 示例

把项目 clone 下来以后，直接 `open OpenShareDemo/openshare.xcodeproj` 就可以运行了。注意 sina 微博的 key 没有通过 sina 的审核，直接分享会提示错误，可以替换成自己的 key。

## 简介

楼主做 iOS 开发的过程中遇到这样的问题：自己 App 中的信息需要分享到 QQ、微信、微博等社交网络。现在的客户端越做越强大，直接集成了分享功能，比如用户手机上安装了微信，只需要 App 调起微信，并且给微信传入相应的参数就可以了，完全不需要自己操作 REST API。这样如果实现分享，一般情况下要去官方下载 SDK，然后按照官方翔一样的 Demo 代码和文档来改造自己的程序。这样做不仅增大了代码量（想象一下引入的官方类库，有时候，光这些第三方的 SDK 都要比我自己的 App 还大），而且使用还很繁琐（SDK 一般没有源代码，想象 Apple 强制 App 支持 64 位的时候）。所以楼主调试了一下各个平台的 SDK，研究了各个厂商实现的应用程序间通信的规则，把功能封装成了 OpenShare。

## 设计思路

比如分享功能，OpenShare 有一个 OSMessage 类，保存 OpenShare 向客户端发送的消息。分享的消息基本上有以下几种情况：

1. 纯文本
2. 图片
3. 链接
4. 其他格式多媒体（声音、视频、文件等）

这样对应 OSMessage 中的属性：

```objc
@property NSString* title;
@property NSString* desc;
@property NSString* link;
@property NSData* image;
@property NSData* thumbnail;
@property OSMultimediaType multimediaType;
// for 微信
@property NSString* extInfo;
@property NSString* mediaDataUrl;
@property NSString* fileExt;
```

比如一个文本消息，可以只设置 title，其他不管；发送一个图片，只需要设置 image / thumbnail / title / desc，其他不用设置。对于其他多媒体消息，可以用 multimediaType 来标示。所以 OSMessage 可以封装所有 App 向客户端发的各类分享请求。

另外，还需要解决的是，客户端分享完成以后回调 App 的功能。我们熟悉的是 block 方法。而不是每个平台都到 application:openURL:sourceApplication:annotation: 中判断。比如最好是这样的：

```objc
OSMessage *msg=[[OSMessage alloc] init];
msg.title=@"Hello World";
// 分享到微信
[OpenShare shareToWeixinSession:msg Success:^(OSMessage *message) {
	ULog(@"微信分享到会话成功：\n%@",message);
} Fail:^(OSMessage *message, NSError *error) {
	ULog(@"微信分享到会话失败：\n%@\n%@",error,message);
}];
// 分享到QQ
[OpenShare shareToQQFriends:msg Success:^(OSMessage *message) {
	ULog(@"分享到QQ好友成功:%@",msg);
} Fail:^(OSMessage *message, NSError *error) {
	ULog(@"分享到QQ好友失败:%@\n%@",msg,error);
}];
```

基于以上考虑，楼主用 category 实现了 OpenShare。

## 如何使用

### 1. 快速集成

OpenShare 已经支持 CocoaPods。所以您可以用：

```
pod 'OpenShare'
```

引入 OpenShare。

*第零步*: 修改 `Info.plist` 添加 `URLSchemes`，让客户端可以回调 App：

```xml
<!--  OpenShare添加回调urlschemes  -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OpenShare</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!--      微信          -->
            <string>wxd930ea5d5a258f4f</string>
            <!--       QQ         -->
            <string>tencent1103194207</string>
            <string>tencent1103194207.content</string>
            <string>QQ41C1685F</string>
            <!--微博-->
            <string>wb402180334</string>
            <!--人人-->
            <string>renrenshare228525</string>
            <!--facebook-->
            <string>fb776442542471056</string>

        </array>
    </dict>
</array>
```

*第一步*：到 `AppDelegate` 中的 `application:didFinishLaunchingWithOptions:` 中全局注册 AppId / AppKey：

```objc
// 全局注册appId，别忘了#import "OpenShareHeader.h"
[OpenShare connectQQWithAppId:@"1103194207"];
[OpenShare connectWeiboWithAppKey:@"402180334"];
[OpenShare connectWeixinWithAppId:@"wxd930ea5d5a258f4f"];
[OpenShare connectRenrenWithAppId:@"228525" AndAppKey:@"1dd8cba4215d4d4ab96a49d3058c1d7f"];
```

*第二步*：到`AppDelegate中`的`application:openURL:sourceApplication:annotation:`中添加整体回调：

```objc
// 如果OpenShare能处理这个回调，就调用block中的方法，如果不能处理，就交给其他（比如支付宝）。
if ([OpenShare handleOpenURL:url]) {
	return YES;
}
```

*第三步*：在需要分享、OAuth 的地方调用：

```objc
// 比如微信登录，其他登录可以参考文档或者代码，或者让Xcode自动提示。
[OpenShare WeixinAuth:@"snsapi_userinfo" Success:^(NSDictionary *message) {
	ULog(@"微信登录成功:\n%@",message);
} Fail:^(NSDictionary *message, NSError *error) {
	ULog(@"微信登录失败:\n%@\n%@",message,error);
}];
//分享纯文本消息到微信朋友圈，其他类型可以参考示例代码
OSMessage *msg=[[OSMessage alloc]init];
msg.title=@"Hello msg.title";
[OpenShare shareToWeixinTimeline:msg Success:^(OSMessage *message) {
	ULog(@"微信分享到朋友圈成功：\n%@",message);
} Fail:^(OSMessage *message, NSError *error) {
	ULog(@"微信分享到朋友圈失败：\n%@\n%@",error,message);
}];
```

### 2. 扩展支持更多平台

现在的社交网络各种各样，如何把这些平台集成到 OpenShare 中呢？就像插件一样，可以把自己实现的 `OpenShare+foobar.h` 和 `OpenShare+foobar.m` 添加进来就可以了。[这里](http://openshare.gfzj.us/#plugins) 提供了一个模板工具，只需要输入你想扩展的平台的名称，就会自动生成 `.h` 和 `.m` 文件，然后基于这个模板修改即可。

## 未完成

1. [ ] 没有安装客户端情况下的 fallback
2. [x] 支付宝和微信支付
3. [ ] Facebook 和 twitter 等国外社交平台的支持
4. [ ] ReadMe 国际化

## 其它

由于每个厂商的通信协议都不一样，所以 hack 的时候还是走了一些弯路，如果想了解整个实现过程，可以看看我的博客：<http://www.gfzj.us/series/openshare/>

现在行业急需要像 OAuth 一样的标准，来实现 App 和客户端之间的分享，登录。这样就不用为每一个客户端实现一遍了。比如这个协议标准就叫做「OpenShare」（大言不惭、捂脸中）。客户端只需要声明支持 OpenShare 的某个版本，App 就能很简单的调用了。如果您对实现 OpenShare 标准有任何想法，欢迎交流。

## 联系

在 OpenShare 使用过程中有任何问题，都可以添加一个 [issues](issues)，我会及时解决。如果您想贡献代码，欢迎 [Pull Requests](pulls)。其他任何问题可以在下面留言，或者通过邮箱 <gf@gfzj.us> 联系我。

## 协议

<a href="https://github.com/100apps/openshare/blob/master/LICENSE">
    <img src="https://www.gnu.org/graphics/gplv3-127x51.png">
</a>

OpenShare 基于 GPLv3 协议进行分发和使用，更多信息参见协议文件。
