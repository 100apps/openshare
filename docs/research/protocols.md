# 分享与登录协议：确认结果和适用边界

核对日期：2026-11-09。阅读前先看[证据定义](sources.md)：下列“确认”可能指公开契约或指定制品静态字段，均不等同于已完成当前社交客户端的真机互通。

## 1. 把“协议”拆成四层

| 层 | 解决的问题 | 典型机制 | 不能据此推断的事 |
| --- | --- | --- | --- |
| OS 路由 | 打开哪个应用/页面，交给哪个进程 | iOS Universal Link / URL Scheme；Android Intent / App Links | 授权、来源真实性、发布成功 |
| 数据传递 | 图片、文件、消息字段怎样送达 | content URI、NSItemProvider、相册资源标识、Bundle、剪贴板 | 用户已经同意分享或登录 |
| 业务授权 | 哪个用户同意向哪个应用开放哪些能力 | OAuth 2.0、OIDC、厂商原生 SSO | App 自身的业务登录态已经建立 |
| 结果与关联 | 回调对应哪个请求，能证明什么 | state、nonce、transaction、SDK 校验、服务端回执 | 所有平台都能返回同一种成功/取消回调 |

ShareSDK 的统一 API 位于这些机制之上。OpenShare 新核心应复用共同的请求生命周期与类型，而不是假定存在一个跨微信、QQ、微博的统一 IPC 格式。

## 2. 可以依赖的系统与公开协议

### 2.1 系统分享

**iOS**：`UIActivityViewController` 交给 activity 文本、URL、图片或文件。iPad 必须有合法弹出位置。completion 的 `completed` 表示 activity 是否执行，`activityError` 另行保留。`false` 并不能无条件归因于用户取消，`true` 也不是社交服务器的发布证明。[A03](sources.md#a03)。

**Android**：`ACTION_SEND` / `ACTION_SEND_MULTIPLE`、MIME、`EXTRA_TEXT/EXTRA_STREAM` 配合 chooser。附件通过可读 `content://` URI 及临时只读授权传递；裸文件路径不是可移植的跨进程授权方式。[G01](sources.md#g01)。

Android 并非完全没有分享观察接口：选择回调可提供被选组件；API 35 起 `ChooserResult` 又区分选择组件、Copy、Edit 等 chooser 会话动作。它们依然不能证明接收方 App 发出了消息，也没有一个适用于所有接收方的取消回执。当前 OpenShare Android 基础库只返回启动是否被系统接受；增强观察接口属于新设计。[G01](sources.md#g01)。

结论：两端都可零厂商 SDK 分享，但目的地由系统及接收方扩展决定。不能用“系统列表里可能有微信”来宣称支持“指定微信朋友圈富媒体分享”。

### 2.2 公开链接

| 入口 | 已确认参数与行为 | 结果边界 |
| --- | --- | --- |
| Telegram `https://t.me/share/url` | URL 编码的 `url` 与可选 `text`，用户选择会话并可编辑 | 只能记录交接；这份文档未定义发布回执或附件接口 [T01](sources.md#t01) |
| WhatsApp `https://wa.me/?text=...` | 编码的预填文字；也可使用带电话号码的会话入口 | 打开会话/预填不等于发送；不能推出个人 OAuth 登录 [T02](sources.md#t02) |
| X 旧 Web Intent | 本次旧官方文档地址跳到首页 | 暂不把旧 URL 计入已确认入口；先使用已确认的系统分享路线 [X01](sources.md#x01) |

用 URL 构造器对每个参数分别编码，不对整个 URL 重复编码。签名链接不擅自重写、转短链或附加追踪参数。HTTPS 链接可能打开浏览器而非 App，因此结果中不能伪造确定的目标应用。

### 2.3 OAuth 2.0 / OIDC

OAuth 是授权框架；OIDC 才进一步定义标准身份令牌。不能把任意 OAuth access token 当作 OIDC ID token，也不能只解析 JWT 载荷就建立业务会话。[O01](sources.md#o01)、[O02](sources.md#o02)。

对于**提供方明确允许的原生公共客户端**，推荐授权码加 PKCE S256，使用系统承载的认证浏览器：iOS `ASWebAuthenticationSession`，Android 使用合适的系统浏览器/Custom Tabs 传输。不要用宿主可读取登录页内容的自定义 WebView 收集账号密码。系统认证会话的界面可以显示在 App 内，并不改变其安全隔离属性。[A01](sources.md#a01)、[O01](sources.md#o01)。

```text
创建请求上下文：operationId、随机 state、PKCE verifier/challenge、必要时 nonce
→ 系统认证浏览器打开受信任的授权端点
→ 仅接受已登记的精确 redirect、对应提供方和 state
→ 公共客户端按其注册方式换令牌，或交业务服务端处理
→ 如使用 OIDC，验证签名、issuer、audience、有效期和 nonce
→ 业务服务端建立自己的会话
```

PKCE 与 state 解决不同的关联/拦截问题，不能拿可预测的业务用户 ID 代替随机 state。厂商客户端 SSO 是否支持 PKCE，需要厂商证据；不能在 WeChat/QQ 请求里加一个 `code_challenge` 就声称具备保护。若某旧接口只提供较弱模式，适配器必须明确标注并限制，不能伪装成标准 PKCE 路线。

Universal Links / App Links 负责系统对域名与应用的关联；应用仍须验证请求上下文、授权结果和 SDK 对回调的校验。HTTP 链接调起成功也不是身份签名。[A04](sources.md#a04)、[G02](sources.md#g02)。

## 3. 原 OpenShare 的实际协议

本节来自基线源码，**只确认历史构造方式**。[L01](sources.md#l01)。

| 平台/操作 | 基线里的路由 | 数据格式与关键字段 | 新版必须重新确认的部分 |
| --- | --- | --- | --- |
| 微信分享 | `weixin://app/{appId}/sendreq/` | 通用剪贴板 `content`，binary plist，App ID 外层字典；`command=1010/1020`、`sdkver=1.5`、`scene`、媒体类型及数据 | 当前客户端是否接受、Universal Link/签名验证、回调关联、媒体限制 |
| QQ 分享 | `mqqapi://share/to_fri` | URL 参数做 Base64/百分号编码；大数据使用命名剪贴板与 keyed archive；`cflag` 表示不同渠道 | 现行 SDK/客户端协议、客户端校验、QQ/QZone 的媒体差异 |
| QQ 登录 | `mqqOpensdkSSoLogin://SSoLogin/...` | 命名剪贴板，`response_type=token`，旧 `sdkv=2.9` | 新凭证与来源验证、回调上下文，不能当成新授权码流程 |
| 微博分享/SSO | `weibosdk://request` | keyed archive，`transferObject/userInfo/app`，`__class`、`requestID`、旧 sdkversion | 安全解码、来源和 requestID 匹配、现代 SDK 支持范围 |
| 微博 Web 授权 | WebView 加旧 OAuth 地址 | 客户端配置 appSecret，后续令牌处理位于旧实现 | 新版应移出客户端 secret；旧端点与权限本次未确认 |
| 人人分享 | `renrenshare://share` | `renren_share` binary plist，`sdk_ver=1.0`、回调 scheme | 当前服务及客户端可用性；原代码把无结果的回调当成功，新设计不能沿用 |
| 支付宝支付 | 接受服务端提供的支付链接 | 可选截图剪贴板；以 `safepay` 及状态码解析回调 | 这是支付而非通用登录分享；必须独立验签及查单 |

它们共同使用的 URL/剪贴板只是传输材料，不构成一个跨平台标准。iOS 的剪贴板协议也不能直接移植为 Android Intent 协议。

需要正视基线的遗留约束：微博 category 仍直接调用旧式 `unarchiveObjectWithData:`，一些 category 用 scheme 前缀匹配回调，通用单例保存当前请求。上一轮通用解码辅助函数的白名单不能自动覆盖这些独立解析点。新设计应把 Legacy 隔离，不让未经验证的回调进入它们；是否单独修补旧 API 属于后续代码工作。

## 4. 当前 SDK 的公开契约与实现线索

### 4.1 ShareSDK Android 3.10.36 的自有协议线索

官方 Maven 的微信 Core JAR 包含 50 个 class，带自己的 `WXMediaMessage`、文字/网页/文件/小程序模型。对消息构造、标识映射和传输入口的静态检查确认，至少存在自有的 IPC 路径，不能把这一端简单描述为“仅转发给官方 SDK”。[M06](sources.md#m06)。

| 模块 | 指定制品观察 | 能确认与不能确认 |
| --- | --- | --- |
| Wechat-Core | Intent/Bundle；`_mmessage_sdkVersion`、`_mmessage_appPackage`、`_mmessage_content`、`_mmessage_checksum`；目标 `com.tencent.mm.plugin.base.stub.WXEntryActivity`；token、ContentResolver 和返回处理 | 确认自己的传输实现；不代表抄字段就完成安全校验或当前客户端互通 |
| Wechat-Core 媒体 | 自有模型标识与 `com.tencent.mm.opensdk.modelmsg` 标识映射；`_wxobject_*`、scene 等字段 | 标识中出现官方类名不自动意味着调用了那个官方 class；仅作序列化兼容观察 |
| QQ | 自有分享 Activity 构造 `mqqapi://share/to_fri`；授权代码含 `m_authorize` 的 token 模式 | 当前 SDK 制品仍含这些路径；未确认所有条件分支或平台是否继续接受 |
| SinaWeibo | 自有分享 Activity 构造 `ACTION_WEIBO_ACTIVITY` Intent；有 `_weibo_appPackage`、`_weibo_appKey`、`_weibo_sign`、`_weibo_transaction` 等字段及错误解析 | 确认 Android Intent 契约与 iOS 旧剪贴板结构不同；未做真实客户端验收 |

研究版本对应的 POM 基本不描述依赖；实际模块还使用 Mob 公共库。不能因 POM 没写腾讯依赖就断言全部零依赖，也不能把这些专有实现直接复制进 GPL 项目。可以记录互操作事实并独立编写 adapter，再用合法的测试宿主验证。

独立协议路线建议先做只包含合成内容的编码对照：与锁定的官方 SDK 对比其公开模型产生的数据；再在自有已审核应用中采集请求和返回的脱敏证据，覆盖注册、签名、权限、内容传递与响应校验。编码相同不代表校验链相同，更不代表不需要平台审核。

### 4.2 微信

腾讯 iOS 2.0.9 公开头文件确认：注册 App ID / Universal Link，发送 `SendAuthReq` 或分享请求，使用 SDK 处理 URL/Universal Link，由 `onResp` 返回业务结果。授权请求/响应均有 state，授权响应可有 code；发送函数 completion 与业务响应不是同一个事件。[W01](sources.md#w01)。

Android 6.8.40 的公开模型有 `transaction`，授权模型有 `scope/state/code`。指定制品的静态检查进一步观察到：

| 所在模型 | 序列化线索 | 证据范围 |
| --- | --- | --- |
| BaseReq | `_wxapi_command_type`、`_wxapi_basereq_transaction` | 该版本 Bundle 键 |
| SendAuth.Req | type 1；`_wxapi_sendauth_req_scope`、`_wxapi_sendauth_req_state` | 该版本授权模型 |
| SendMessageToWX.Req | type 2；`_wxapi_sendmessagetowx_req_scene` | 该版本分享模型 |
| 文字/网页对象 | `_wxtextobject_text`、`_wxwebpageobject_webpageUrl` | 该版本媒体序列化 |
| 传输与返回入口 | 包签名验证、SDK token/消息校验，Intent 处理 | 说明不能只照抄字段就宣称实现完整可信链路 |

这些键是实现观察，不是厂商承诺稳定的独立协议。此处没有提供校验绕过，也没有确认新 iOS 的完整 wire format；不能通过把旧 plist 的 `sdkver` 改为 2.0.9 完成升级。[W02](sources.md#w02)。

**接入选择**：默认使用可选官方适配器，核心保持无厂商依赖。独立 wire adapter 如继续研究，应单独标记实验性，并以准确的 App 版本、SDK 制品、系统版本、已审核 App ID、签名、回调样本和真实互通结果为准。微信授权服务端的精确请求和权限在接入前还要复核 W03；本次没有拿不可读的文档充当已确认的端点说明。

### 4.3 QQ / QZone

网站 OAuth 文档确认 code + state，并要求服务端 secret 换令牌；同一官方文档也限定了网站/H5/移动场景，不能把网站流程直接嵌进 App 当作通用后备登录。移动路线应按移动应用类型接入 QQ SDK，配置签名及 Universal Links。[Q01](sources.md#q01)、[Q02](sources.md#q02)。

QQ 与 QZone 是同一账户提供方的不同分享渠道，不能把它们建模成两套登录身份。移动授权具体返回 token、code 或其他凭证，需要锁定拟接入 SDK 的公开类型后确认，本报告不强行统一为 code。

### 4.4 微博

微博 iOS 当前官方仓库的授权响应明确包含 token 等字段；Android README 也描述 SSO/Web 授权返回 token。因而通用结果至少要区分“授权码”和“提供方 access token”。不能将 token 改名为 code，也不能把客户端声称的 userID 当成服务端已验证身份。[B01](sources.md#b01)、[B02](sources.md#b02)。

iOS 头文件暴露无法 SSO 时启用 SDK WebView 的开关。新适配器应禁用未经评估的隐式回退；如考虑浏览器路线，需先核实厂商支持的 App 类型、精确端点和安全参数。本次未确认微博通用 PKCE 支持。

### 4.5 抖音

移动授权是 SDK 承载的 OAuth 授权码流程，state 可关联请求；Android 使用专用回调 Activity。抖音与 TikTok 是不同目标和配置，不可复用一个 provider ID。[D01](sources.md#d01)。

iOS 分享资料描述使用相册资源标识，支持特定图片/视频组合与目标编辑/发布页面，而不是任意“文字＋链接卡片”。平台还提供与 ShareID 及额外权限有关的追踪能力：SDK 接受/返回、发布状态查询和后续传播统计应是分开的功能。[D02](sources.md#d02)。

### 4.6 小红书

当前能取得的官方索引说明媒体分享、iOS 相册和 Android FileProvider 路线，FAQ 限制自动填充标题/文案；入口还显示暂停接入。正文直读受限，因此以 S 级证据记录，不承诺新应用必定可申请成功。[R01](sources.md#r01)。

对应设计结论：有 SDK 文件不代表账号有资格；能分享图片不代表文案可保留。要求保留文案的请求，应在发送前报 `unsupportedField`，或由用户明确批准修改后的内容。这里没有确认消费用户的通用登录能力，不拿商家电商 OAuth 填补该项。

### 4.7 Apple / Google / X 等

| 提供方 | 本次确认的路线 | 新接口要保留的差异 |
| --- | --- | --- |
| Apple | iOS 系统认证；授权码、身份令牌由业务服务端验证 | nonce、应用/服务 ID、首登资料可能不重复返回；Android 需网页/服务端配置 [A02](sources.md#a02) |
| Google | Android Credential Manager 与 iOS Google Sign-In 官方集成 | 按平台选择注册和依赖；认证与 API 授权不混为一个状态 [G03](sources.md#g03) |
| X | 公开的 OAuth 2.0 PKCE 流程 | 不是 OIDC 的证据；分享编辑页、API 发帖权限另行核实 [X01](sources.md#x01) |
| Telegram / WhatsApp | 已确认的公开分享/会话链接 | 该资料没有确认其通用登录；不得自动扩展成登录支持 [T01](sources.md#t01)、[T02](sources.md#t02) |
| Facebook / Instagram | 分发包存在相关模块；当前 Meta 分享文档访问受限 | API 权限、登录和内容发布分别列待核实，不列为已完成接入 [F01](sources.md#f01) |
| 人人 / 支付宝 | 本仓库的旧分享或支付代码 | 未确认现代通用登录分享契约；支付不进入本轮通用模型 [L01](sources.md#l01) |

## 5. 发布前的协议确认门槛

每个适配器应提供一份版本清单：官方来源、SDK/协议版本、可使用的应用类型、OS/目标 App 版本、内容和渠道矩阵、请求序列化约束、回调来源验证、可观察结果、取消/超时/冷启动行为。没有这些信息的条目只能是 `research` 或 `experimental`。

发布支持状态应区分：`documented`、`artifactInspected`、`integrationBuilt`、`deviceVerified`。旧源码和聚合 SDK 的“成功”枚举不能自动提升为 `deviceVerified`。第三方客户端更新后，原真机结论只覆盖记录中的版本组合。

详细的接口、状态机和迁移安排见[新 SDK 设计](../next-sdk/design.md)与[验收矩阵](../next-sdk/validation.md)。
