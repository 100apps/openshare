# OpenShare

[![Mobile CI](https://github.com/100apps/openshare/actions/workflows/ci.yml/badge.svg)](https://github.com/100apps/openshare/actions/workflows/ci.yml)

极简的原生分享库。iOS 使用 `UIActivityViewController`，Android 使用系统 Sharesheet；基础分享不依赖第三方 SDK。需要指定微信会话、朋友圈、登录或支付时，再按需引入微信官方 SDK 适配器。

这是 `0.1.0` 的开发版本；尚未发布 CocoaPods / Maven 版本或打 release tag。当前可使用仓库分支、本地 Pod 或 Gradle 模块集成。

| 能力 | iOS 15+ | Android 6 / API 23+ |
| --- | --- | --- |
| 系统文本、链接、图片、文件分享 | 支持，兼容 iPhone / iPad | 支持，附件使用 `content://` |
| 微信定向分享 / 登录 / SDK 支付请求 | 可选官方 SDK 2.0.9 | 可选官方 SDK 6.8.40 |
| QQ、微博、人人、支付宝旧协议 | 保留源码与接口；未验证最新客户端 | 没有移植私有协议 |

系统分享的接收方由系统和已安装 App 决定。它不能保证某个 App 出现在列表，也不能替代第三方登录或支付。微信适配器的自动化测试使用真实 SDK 类型、模拟传输；真实登录、支付、Universal Links 和签名配置仍需在你自己的已审核应用中真机验收。详见[兼容性与验证边界](docs/modernization.md)。

## 新版统一接口

已按设计实现极简双端 `ShareClient`：系统分享、Telegram/WhatsApp 公开链接、可选微信分享/授权码登录。强类型请求、能力预检、一次性结果回调；新增平台只需实现 Provider。新核心不依赖厂商 SDK。两端示例已使用新入口。

接入代码、模块选择、取消/超时与验证范围见 **[OpenShare Next 实现说明](docs/next-sdk/implementation.md)**。下面保留旧兼容 API 的说明。

## iOS

Swift Package Manager 添加本仓库，选择 `OpenShare` product。它不包含微信 SDK。

CocoaPods 本地集成：

```ruby
pod 'OpenShare', :path => '../openshare'
# 需要微信官方 SDK 时，改为：
# pod 'OpenShare/WeChat', :path => '../openshare'
```

```objc
#import <OpenShare/OpenShareHeader.h>

OSMessage *message = [OSMessage new];
message.title = @"Hello OpenShare";
message.link = @"https://github.com/100apps/openshare";
[OpenShare shareMessage:message
    fromViewController:self
            sourceView:sender  // 当前页面中的 UIView；iPad 弹出位置
            completion:^(BOOL completed, NSError *error) {
    // completed 表示所选系统 activity 完成，不是服务器确认发布成功。
}];
```

在主线程、可见页面调用。图片用 `message.image`；文件用 `message.fileURL`，文件必须可读并保留到分享结束。系统入口不会使用旧的 `message.file` 二进制数据或小程序私有协议。系统分享无需注册 App ID 或配置 URL Scheme。

Swift 中同样可以 `import OpenShare`，调用 `OpenShare.share(message, from: self, sourceView: button, completion: nil)`。构建分享项而不展示 UI 时使用 `try OpenShare.systemActivityItems(for: message)`。

旧 Objective-C API 仍可编译；最低 iOS 版本提升到了 15。历史接入说明见[旧版文档](docs/legacy-ios.md)，其中私有协议、示例 App ID 和商户配置不应直接用于新应用。

## Android

将 `android/openshare` 作为 Gradle library module 加入你的工程：

```groovy
// settings.gradle
include ':openshare'
project(':openshare').projectDir = file('../openshare/android/openshare')
// app/build.gradle
dependencies { implementation project(':openshare') }
```

```java
OpenShare.share(activity,
    ShareMessage.text("Hello https://github.com/100apps/openshare"), "Share");

// 图片、视频、PDF 等：URI 来自 FileProvider、MediaStore 或其他可授权的 provider。
OpenShare.share(activity,
    ShareMessage.attachment(contentUri, "image/png", "caption"), "Share");
```

不需要存储权限或 `QUERY_ALL_PACKAGES`。调用者负责提供可读且允许临时授权的 URI；不要传入 `file://`。返回 `true` 只说明系统已接收启动请求，不能表示发送成功。Java API 同样可以从 Kotlin 调用。

演示应用：用 Android Studio 打开 `android/`，运行 `sample`。它只演示系统分享，未配置任何厂商 App ID。

## 微信官方 SDK（可选）

适配器支持简单文本 / 链接，也允许直接传入 SDK 的媒体请求，以支持图片、音视频、文件和小程序。登录仅返回授权码，令牌交换放在你的服务端；支付仅传递服务端签名的 SDK 请求，支付结果必须由服务端核实。

完整配置、AppDelegate / SceneDelegate 回调以及 Android `WXEntryActivity` 示例见[微信接入](docs/wechat.md)。iOS 必须配置自己的 HTTPS Universal Link 与 AASA；Android 必须匹配开放平台登记的包名与签名。

## 构建和验证

```sh
# Android：JDK 21、Gradle Wrapper、Android SDK 37.2
cd android
./gradlew test lint assembleDebug
./gradlew :sample:connectedDebugAndroidTest  # 已连接的模拟器 / 设备
```

```sh
# iOS：macOS + Xcode + XcodeGen
bash scripts/download-wechat-ios.sh
xcodegen generate --spec ios/project.yml
bash scripts/ios-test.sh
```

[GitHub Actions](https://github.com/100apps/openshare/actions/workflows/ci.yml) 执行 Android 单元测试、lint、AAR/APK 构建和最新稳定模拟器测试；三组 macOS runner 执行 Swift Package 构建、iPhone / iPad XCTest、旧 demo 构建及 CocoaPods 本地 lint，包括使用正式 Xcode 27.2、核对及按需下载 iOS 27.2 正式运行时。实际工具链版本与[验证边界](docs/modernization.md)均有记录。测试报告、构建产物与 `.xcresult` 作为 CI artifacts 保存。

## 协议调研与设计

围绕 ShareSDK 与原 OpenShare 的实现，已整理[调研与取舍](docs/research/sharesdk.md)、[协议确认结果](docs/research/protocols.md)、[跨平台 SDK 设计](docs/next-sdk/design.md)及[验证与迁移计划](docs/next-sdk/validation.md)。[来源目录](docs/research/sources.md)记录指定版本、制品哈希和未确认项目。

完整设计包含后续阶段；本轮已落地的 P1 以[实现说明](docs/next-sdk/implementation.md)为准，不代表所有平台已适配或真实登录/发布验收已通过。

## 许可

OpenShare 保持 [GPLv3](LICENSE)。可选官方 SDK 按各厂商自己的许可提供，不随本仓库提交二进制文件。
