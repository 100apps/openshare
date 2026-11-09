# OpenShare Next：已实现的最小版本

本次落实[设计](design.md)中的 P1：两端原生实现，同一套值类型和生命周期约束。最低 iOS 15 / Android API 23。新接口与旧 API 并存，不发布版本、不修改已有包的默认入口。

## 支持范围

| Provider | 输入 | 可观察结果 | 关联保证 |
| --- | --- | --- | --- |
| `system` | 文本、HTTP(S) 链接、图片、视频、文件 | iOS：`activityCompleted` / `notCompleted`；Android：`handedOff` | requestBound，绑定本次系统操作，不代表发布回执 |
| `telegram` | HTTP(S) 链接，不接受 title/summary | `handedOff` | requestBound，只证明本次打开请求被接收 |
| `whatsapp` | 文本或 HTTP(S) 链接，不接受 title/summary | `handedOff` | 同上 |
| `wechat`（可选官方 SDK） | 文本/链接，`default` / `session` / `timeline` / `favorite`；授权码登录 | `sdkReportedSuccess` / `cancelledByUser`；登录 `credentialReceived` | Android transaction/state：requestBound；iOS 分享：serializedOnly，登录 state：requestBound |

所有路径还可能返回 `failed`、本地取消 `cancelledLocally`、等待超时 `indeterminate`。SDK 成功不等于服务器确认发布；授权码不是应用自己的登录 session。`notCompleted` 也不被臆断成用户取消。

Telegram 使用 `https://t.me/share/url?url=…`，WhatsApp 使用 `https://wa.me/?text=…`，逐字段编码，保留 Unicode、`+`、签名 URL 的原值。只在调用时打开，不联网探测，不保证目标 App 安装或接收后发布成功。

微信新入口暂不接媒体、小程序或支付；旧官方适配器的原生请求入口仍保留。新 Core 不自动回退旧私有协议。不支持的内容/字段/渠道/凭证类型在发送前报错。

## iOS 接入

SPM 选择 `OpenShareNext` product，导入 `OpenShareCore` 和 `OpenShareSystem`，依赖树没有厂商 SDK。只要模型可选择 `OpenShareCore`。

```swift
import OpenShareCore
import OpenShareSystem

// 在 @MainActor 中创建并保留。公开链接按需添加对应 Provider。
let client = try ShareClient(providers: [
    SystemShareProvider(),
    PublicLinkProvider(.telegram)
])

let operation = try client.execute(
    .share(provider: "system", content: .link(URL(string: "https://example.com/")!, title: "Example")),
    context: SharePresentation(controller, sourceView: button)
) { result in
    print(result.outcome) // 在主 actor 异步交付，最多一次
}
// operation.cancel() // 只取消本地等待，不撤销已经交接的分享
```

CocoaPods 当前用本地依赖，尚未发布新版本：

```ruby
pod 'OpenShare/Next', :path => '../openshare'
# 或需要微信时选这一项，它依赖 Next + 官方 SDK 2.0.9：
# pod 'OpenShare/NextWeChat', :path => '../openshare'
```

Pod 的 Swift 文件统一位于 `OpenShare` module，使用 `import OpenShare`，不用上面两个 SPM module 的 import。微信本轮通过 Pod / 本仓库 XcodeGen 工程集成，SPM 不提供厂商 binary target。

```swift
// Pod: import OpenShare
let wechat = try WeChatProvider(appID: ownAppID, universalLink: ownUniversalLink)
let client = try ShareClient(providers: [wechat]) // app 生命周期保留同一个实例
try client.execute(.authorize(provider: "wechat", scope: "snsapi_userinfo"),
                   context: SharePresentation(controller, sourceView: button)) { result in
    if let credential = result.credential {
        // credential.kind == .authorizationCode
        // 将 credential.value 交给自己的服务端兑换、校验；不要输出原值。
    }
}
```

遵循[微信配置](../wechat.md)设置自己的 URL scheme、白名单、Universal Link 和 AASA。将 AppDelegate/SceneDelegate 收到的 URL，以及 `NSUserActivity.webpageURL` 转交 **这个新 client** 的 `handleCallback(url)`；返回 false 时由宿主继续其他路由。不要同时交给旧 OSWeChat 或聚合 SDK。没有 pending 的回调不建立新授权。

展示上下文必须来自当前 foregroundActive scene 的可见页面，来源视图属于该页面；正在转场或已有 presented controller 时明确失败，不猜另一个窗口。iPad 使用传入的 view 作为锚点。

## Android 接入

沿用 README 的 `:openshare` Gradle module。只引用它没有微信 SDK。主线程创建并调用：

```java
import us.gfzj.openshare.ShareClient;
import us.gfzj.openshare.SystemShareProvider;
import us.gfzj.openshare.PublicLinkProvider;

ShareClient client = new ShareClient(new SystemShareProvider(),
    new PublicLinkProvider(PublicLinkProvider.Service.telegram));
ShareClient.Operation operation = client.execute(
    ShareClient.Request.share("system", ShareClient.Content.link("https://example.com/", "Example", null)),
    activity, result -> { /* result.outcome：handedOff 只是启动已交接 */ });
```

可选引用 `:openshare-wechat`（官方 SDK 6.8.40），添加 `new us.gfzj.openshare.wechat.WeChatProvider(ownAppId)`。App 生命周期保留 client/provider。在自己包下的 `wxapi.WXEntryActivity.onCreate/onNewIntent` 中，将 intent 转交 `client.handleCallback("wechat", intent)`，然后关闭回调 Activity；SDK 校验回调。初始化前的 orphan 不作为成功。包名、签名、queries 与 exported 回调配置仍按[微信说明](../wechat.md)，将旧示例的 `wechat.handleIntent` 换成上述入口。不要双重注册不同实现。

内置 UI Provider 要求可见且有 window focus 的 Activity；不能从后台服务或已销毁 Activity 发起。没有 `QUERY_ALL_PACKAGES`，没有申请存储权限。媒体使用可授权的 `content://`，调用方提供 MIME；图片列表复制成只读快照，多图使用 SEND_MULTIPLE，每个 URI 都加入 ClipData，只授予读取权限。拒绝 `file://`。

## 计划、取消与资源

需要提前检查时调用 `prepare(request)`，返回只读 Plan；`execute(plan, …)` 重新检查内容、资源及能力。Plan 只能用于持有同一 Provider 实例的 client。请求和 Provider 配置须保持不可变，不在准备后换目标。

要求特定结果时，Swift 使用 `prepare(request, requiring: .sdkReportedSuccess, requestBound: true)`，Java 使用 `prepare(request, Outcome.sdkReportedSuccess, true)`。不能提供该保证就报 `unsupportedObservation` / `unsupportedCorrelation`。例如 iOS 微信分享拒绝 requestBound 要求，而不是凭一个本地 UUID 冒充平台关联标识。

默认期限 300 秒。Swift `timeout` 单位秒；Java 的 Plan execute 参数 `timeoutMillis` 单位毫秒。caller 的 callback 总在主线程/主 actor 异步执行，最多一次，先记终态再执行回调。凭证和 Result 的默认字符串表示不含凭证原文；显式读取 value 仍由业务负责保密。

SDK 的 lane 和回调命名空间是 app 级的，多个 client 不能绕过互斥。取消/超时不释放 SDK 在途通道；收到真实响应或明确发送拒绝后才释放。SDK 永不回调时会持续 busy，当前版本没有“强行清空后立即重试”接口。进程重启没有持久恢复记录，旧回调 fail closed。不要因返回前台、取消或超时自动重发。

iOS 资源为可读本地文件 URL，Android 为可读 content URI；发送前检查可读性。核心不下载、复制、压缩、转码、写相册、删除文件或撤销 URI 权限。调用方管理文件和 security-scoped 访问的生命周期，尤其 Android handoff、本地取消/超时之后，接收方可能仍在读取；不能以 caller terminal 作为删除信号。系统最终如何展示标题/摘要由所选 activity 决定，不能承诺它原样发布。

## 扩展 Provider

只实现三个必要成员：`id`、`prepare`、`start`。prepare 校验明确支持的 operation/content/field/channel，返回可观察结果及关联级别；start 使用原生传输，向 operation 调用 `complete` / `fail`。支持登录的 Provider 才接受 authorize，返回明确的 Credential.Kind。不导入厂商类型到 Core。

可选覆盖 `lane`（默认 provider ID，nil 表示独立操作）、`callbackKeys` 和 `handleCallback`。SDK/URL 回调命名空间必须独占；同一 Provider 实例可被多个 client 复用，第二个实现抢同一路由会被拒绝。Provider 必须先核对回调类型、state/transaction 和路由，再提交终态；Core 的一次性投递不能代替平台关联验证。所有调用与回调在主线程/主 actor。

本轮把设计中的 descriptor、ShareProvider、AuthProvider、CallbackOwner 收敛到一个小接口；不需要空的登录方法或可变的万能消息字典。平台新增能力优先在对应 Provider 内增加明确类型和检查，尚无调用需求的框架层不预建。

## 验证与后续边界

- 两端读取同一份 [16 个契约输入](../../tests/contracts.json)，检查非法输入、渠道/字段限制、Unicode 和公开链接编码。
- native 单测检查能力/Plan、跨 client 的 SDK lane、取消/超时、重复/迟到回调、凭证类型及脱敏；Android 在 API 23/30/36 跑核心单测，官方微信类型的替身传输测试在 ART 跑，保留 verifier。
- 两端示例已改用新 client，CI 的系统面板 UI 测试实际点击新入口；iOS 手机/平板，Android 最新稳定 16 KB 模拟器。微信测试使用真实 SDK 请求/响应类型，替换发送与安装探测，不是已审核 App 的真实登录/发布验收。
- CI 同时构建旧 SPM/demo、新 SPM product，lint Core/WeChat/Next/NextWeChat Pod subspec；旧 API 回归继续运行。

[36 项长期验收](validation.md)不是本轮全部已完成的声明。BrowserAuth、PKCE/OIDC、服务端兑换、私有 wire PoC、QQ/微博等 Provider、chooser target/Copy/Edit 结果监听、资源租约和桥接层留待各自证据和实际需求齐备后实现；本轮对无法观察的结果明确拒绝。没有默认统计、远程配置、短链、OpenShare/Mob 后端或自动 fallback。未做最终 Release 增量体积测量，源码行数不替代体积数据。
