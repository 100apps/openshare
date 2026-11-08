# 0.1.0 兼容性与验证边界

## 设计

保留原来的“小消息模型 + 简单调用”思路，新增原生 Android 实现，不引入跨平台 UI 框架。默认分享走系统 API，不需要各厂商 SDK。微信需要 Universal Links、应用签名校验和厂商协议维护，使用可选官方 SDK；不继续把 2015 年剪贴板协议伪装成新系统兼容实现。

原来的 iOS categories 继续保留，CocoaPods 默认 Core 及 Swift Package 都包含它们，以减少源代码迁移成本。系统分享是新增入口，不会把现有定向分享调用静默改成系统分享。新版最低版本为 iOS 13 / Android API 23。

## 工具链

本次从官方稳定渠道核对并固定的版本：

| 项目 | 版本 / 来源 |
| --- | --- |
| Android compile SDK | 37.2，Google repository `platforms;android-37.2` |
| Android sample target SDK | 37 |
| Android Gradle Plugin / Gradle | 9.5.1 / 9.9.0；Wrapper 固定发行版 SHA-256 |
| Java | CI 使用 Temurin JDK 21，源码目标 Java 17 |
| Robolectric | 4.17；单元测试覆盖 API 23、30、36 |
| Android 运行测试 | 稳定 `android-37.2;google_apis_ps16k;x86_64`，16 KB 页 |
| iOS 构建 | GitHub `macos-15` / `macos-26` 默认 Xcode，另用 `xcode-27` 的 27.2 SDK 验证 iOS 27.2；日志输出实际 Xcode / SDK 版本 |
| 微信 iOS | `WechatOpenSDK-XCFramework` 2.0.9；腾讯下载文件固定 SHA-256 |
| 微信 Android | Maven Central `com.tencent.mm.opensdk:wechat-sdk-android:6.8.40` |

依赖版本可在后续 PR 升级；CI 不使用 `+`、`latest.release` 或未验证的动态 SDK 版本。

2026-11-08 对照 [Apple 发布列表](https://developer.apple.com/news/releases/) 核对，当前正式版为 iOS 27.2 / Xcode 27.2，27.3 是 beta。GitHub `xcode-27` 镜像当前提供 Xcode 27.2 RC（27B48）；Apple 正式 Xcode 是 27B52，下载完整工具链需要开发者登录。本 CI 如实记录 runner 的编译器 build，并通过 Apple 的 `xcodebuild -downloadPlatform` 下载 iOS 27.2 正式运行时，创建对应的 iPhone / iPad 设备运行测试；不把 RC 工具链写成正式工具链验证。

## 自动化覆盖

- Android：Unicode / URL 保真、附件 ClipData 和只读授权、空内容与 `file://` 拒绝、Application Context 启动、微信请求互斥、缺失 App、发送失败、OAuth state、取消和重复回调；构建 AAR 与示例 APK；严格 lint；最新稳定模拟器打开真实系统分享面板。
- 微信官方 Android SDK 的部分 class 文件未包含标准 JVM 要求的 StackMap frames，相关回调测试运行在 Android ART 模拟器上，不通过禁用 JVM 字节码校验绕过。基础库的 Robolectric 测试仍在 JVM 上运行。
- iOS：消息转系统分享项、无效链接和文件、可读文件、无效 presenter、旧工具方法、无效归档输入、Universal Link 语法、微信 state、请求互斥、取消和重复回调。SDK 传输使用测试替身，不会向微信发真实请求。独立 XCUITest 在 iPhone / iPad 上点击示例 App 的分享按钮、确认内容可见，并保留真实面板截图。
- iOS 独立编译默认 Swift Package，确认基础包不依赖厂商 SDK；编译旧 demo，验证保留接口可构建；`pod lib lint` 验证 Core 与 WeChat 两种集成。

CI artifact 是构建 / 模拟器证据。它不能证明微信服务器审批通过或某笔支付完成。

## 合并前真机验收

使用自己的开放平台配置，分别在 iPhone / iPad 和 Android 真机验证：

1. 系统文本、图片、文件分享；取消分享；接收方读取附件；多窗口和横竖屏 / 平板弹出位置。
2. 微信安装 / 未安装；会话与朋友圈分享；取消和错误回调；从冷启动及后台通过 URL Scheme / Universal Link / Android WXEntryActivity 返回。冷启动时没有内存中的 pending 请求，应用应恢复自己的业务状态，不应把未关联回调当成功。
3. 微信登录：授权码、拒绝、state 不匹配；服务端兑换令牌。不要在 App 中存 app secret。
4. 若需要支付：测试商户、服务端签名下单、SDK 回调和服务端通知 / 查单结果一致。SDK 返回值不作为发货依据。

项目未包含有效的已审核应用凭证、Universal Link 域名和支付商户；这些步骤没有被 CI 自动完成。

## 保留但未恢复的功能

QQ / 微博 / 人人 / 支付宝旧 iOS 私有协议仅做源代码保留，未宣称支持最新客户端。Android 没有移植这些协议。系统分享能否选择这些 App 取决于它们自己的分享扩展 / Intent 支持；定向登录与支付需要后续独立的官方适配器和真机验收。

旧微信 category 同样保留，但新接入请使用 OSWeChat；旧入口不会自动获得 Universal Links 支持。旧微博 Web OAuth 的客户端 secret 方案没有迁移成推荐方案。

`pay.php` 仍是历史示例，本次恢复了 TLS 对端与主机名校验；没有将历史微信支付 API v2 / 支付宝示例升级为生产支付后端，也不建议部署原样例。

## 回调约束

系统分享完成与实际社交平台发布成功不是同一件事。Android Sharesheet 不提供通用的发送成功回调；iOS completion 是 activity 的结果。

微信适配器只允许一个在途请求。Android 用 transaction / OAuth state 关联回调；iOS 分享回调没有公开 transaction，取消本地 callback 后仍等待原 SDK 回应才解除 busy，防止旧回应完成下一个请求。保持一个长期存活的 adapter 实例，避免重建实例绕过在途请求状态；应用进程退出后由业务层恢复流程。
