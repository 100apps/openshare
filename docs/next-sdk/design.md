# OpenShare Next：跨平台 SDK 设计草案

日期：2026-11-09；契约草案 v1，不是产品发布版本号。本文定义下一步实现目标；代码中的 `OpenShare`、`OSWeChat` 和 Java `WeChat` 仍是现有接口。

依据：[ShareSDK 调研](../research/sharesdk.md)、[协议分析](../research/protocols.md)。验收条件见[验证与迁移](validation.md)。

## 1. 设计目标

保留极简接入：简单分享一次调用，登录返回清楚的授权凭证。默认核心无厂商 SDK、无自有账号、无统计上传、无短链转换，不要求一套 OpenShare 云服务才能工作。默认 UI 使用系统能力。

“跨平台”首先指一致的模型、能力判断、生命周期及结果语义。第一阶段保持 iOS / Android 原生实现，用同一套契约和测试场景约束两端，不为共享少量分支逻辑先引入跨平台 UI 框架、Kotlin/Native 或 Rust FFI。是否共享状态机源码，等模型稳定且收益可测后再决定。

基础目标沿用 iOS 15 / Android API 23。某个 provider 的 SDK 需要更高版本时，只提高该模块或能力的要求，通过 preflight 返回原因；不悄悄提高整个核心下限。最新系统采用其可用的现代 API，旧构造函数是否仍需要使用由可用性分支决定。

## 2. 模块与依赖

| 模块 | 职责 | 依赖方向 |
| --- | --- | --- |
| Core | 值类型、provider 注册、能力计划、操作登记与终态去重、回调路由规则 | 无厂商依赖；不管理业务用户数据库 |
| SystemShare | 系统面板、系统结果映射、原生展示上下文 | Core + 系统框架 |
| PublicLinks | 经确认的 Telegram / WhatsApp 等链接构造和打开 | Core + 系统打开链接能力 |
| BrowserAuth | 提供方允许的浏览器认证、state/PKCE、redirect 验证 | Core + 原生浏览器传输；不包揽所有提供方 |
| Provider.WeChat / QQ / Weibo / … | 注册、平台参数、SDK/协议映射、回调验证、精确能力 | Core + 该提供方必需依赖，分别安装 |
| AuthExchange | 可选业务后端接口和公共客户端换令牌实现 | Core；由宿主选择 HTTP 实现和服务端 |
| MediaPreparation | 可选的受控拷贝、压缩、资源下载、租约管理 | Core + 平台文件能力；网络下载单独启用 |
| UI / Flutter / React Native 等 | 可选菜单和语言桥接 | 依赖上述契约，不复制另一套路由规则 |
| Legacy | 保留原 category、旧消息转换及旧回调语义 | 显式选择；新 Core 不自动依赖 |

iOS 以独立 SPM products / Pod subspecs 组织；Android 以独立 Gradle modules 组织。依赖图必须证明只选 Core/SystemShare 不会传递引入微信或聚合商框架。Java 可回调调用，不强制 Kotlin 协程；Swift async 和 Kotlin `await()` 是可选便利层。

独立 wire 实现与官方 SDK 实现拥有同一个 provider ID、不同 adapter ID，例如 `wechat.official` 与 `wechat.wire.experimental`。宿主只能为某项能力明确选定一个回调所有者，不能同时让两个实现竞争处理同一响应。实验模块不被默认解析器自动选中。

## 3. 类型模型

以下为语言无关 IDL，名称仍可调整，不能直接复制到现有项目编译。

```text
ProviderId       = 可扩展标识，例如 wechat / qq / weibo / telegram
ShareTarget      = System | Provider(providerId, channel)
Channel          = provider 内的渠道，例如 wechat.session / wechat.timeline
ShareContent     = Text(text)
                 | Link(url, title?, summary?, thumbnail?)
                 | Images(assets[], caption?)
                 | Video(asset, caption?)
                 | File(asset, suggestedName?)
                 | ProviderContent(受注册扩展定义并校验的类型)
AssetRef         = 宿主登记的原生资源引用；附 MIME、长度等已知元数据
ShareRequest     = content + target + policy + deadline
AuthRequest      = providerId + requestedScopes + credentialRequirement
                   + interactionPolicy + deadline
AuthCredential   = AuthorizationCode(Sensitive<code>, redirectContext?)
                 | IdentityToken(Sensitive<idToken>, nonceContext)
                 | AccessCredential(Sensitive<accessToken>, expiresAt?, scopes?)
                 | CredentialBundle(该 provider 明确允许的上述组合)
```

不再使用一个全是可空字段的大消息对象猜测分享类型。多图、视频、文件、小程序是明确类型；不支持的组合在打开目标前返回错误。小程序、音乐等使用 provider 自己的强类型扩展，核心无需导入 WXMediaMessage 等厂商类型。

`channel` 不属于登录模型：微信会话/朋友圈共享一个微信身份提供方，QQ/QZone 亦然。消费用户授权、网站登录、企业/商家授权是不同产品和注册类型，不能因属于同一品牌就互换。

若调用方要求授权码而该路径只能返回 token，preflight 返回 `unsupportedCredentialKind`；不在运行后把 token 填入 code 字段。

AssetRef 在 native 层映射为 UIImage/NSItemProvider/文件 URL 或 Android Uri。桥接层传不透明资源 ID，不传 UIImage 对象、整份 Base64 数据或可任意读取的文件路径。进程内引用在重启后失效时明确报错，不能伪装成可持久化文件。

`Sensitive` 的默认日志/description 必须脱敏；它不声称阻止调试器读取内存。凭证只通过明确的授权结果/后端交换接口交付，不写入通用事件流、诊断日志、URL 日志或统计事件。

### provider 扩展接口

```text
ShareProvider {
  descriptor() -> ProviderDescriptor
  capabilities(context) -> CapabilityDescriptor
  prepare(request, assetResolver) -> PreparedShare | PreparationError
  dispatch(preparedShare, presentation, operationContext, observer)
}
AuthProvider {
  descriptor() -> ProviderDescriptor
  capabilities(context) -> CapabilityDescriptor
  authorize(request, presentation, operationContext, observer)
}
CallbackOwner {
  routes() -> RegisteredRoutes
  handle(event, pendingRegistry) -> handled | unhandled
}
```

一个模块可实现多个接口，但纯分享 provider 不必实现登录空方法。`PreparedShare` 是本地对象，不是可从网络传入执行的命令；高级厂商对象只在对应模块中构造。`observer` 向 Core 提交平台观察事件，Core 检查归属并决定 caller 终态。

`operationContext` 包含本地 operationId、渠道锁、期限与关联上下文；operationId 不自动等同于 OAuth state 或厂商 transaction。`AuthExchange` 接受明确类型的凭证及 attempt 上下文，不接收一个无法验证语义的任意字典。

## 4. 能力计划：先知道会做什么

### 4.1 静态能力和运行条件分开

```text
CapabilityDescriptor {
  providerId, adapterId, operation, channel, platform
  contentTypes, supportedFields, documentedLimits
  credentialKinds, pkceSupport, oidcSupport
  observableOutcomes, correlationAssurance
  minimumOS, dependencyVersion
  evidenceStatus, evidenceReference
}

Readiness = ready | configurationMissing | permissionRequired
          | approvalRequired | unavailable | unknown
```

`unknown` 与“不支持”“未安装”不同。没有 scheme 白名单/Android query 配置而探测失败，不能直接报目标 App 未安装。能力描述也不能证明某个 App ID 获批；本地配置、安装情况、应用审核和运行权限另行诊断。

查询某个明确目标时才按宿主的授权策略做必要探测，不在初始化阶段枚举所有已安装应用。没有进入具体 provider 前，不初始化它的 SDK。

### 4.2 prepare / execute

`prepare(request)` 返回不可变的 `Plan` 或明确错误。Plan 记录实际 provider/adapter、目标渠道、保留/转换/丢弃的字段、依赖/权限要求、可能结果和关联保证。能力查询本身不弹权限框、不发送授权、不自动分享，也不自动下载远程媒体。

执行前重新检查配置/内容/资源及计划指纹，防止准备和发送之间状态变化。需要权限、压缩、写相册或上传时先向宿主报告；处理完后执行批准过的计划。

默认策略是 `strict`：不支持字段、未知必要能力、目标变化或内容语义损失都在发送前返回原因。宿主可显式接受某个替代 Plan；一个全局 `allowFallback=true` 不能同时授权删除文案、更换平台和上传媒体。

例如，小红书若不能保留 caption，`Images(..., caption)` 返回具体 `unsupportedField=caption`，不静默删除。微信未安装时，系统面板可以作为候选，但它不保证朋友圈目的地，必须明确呈现这个变化。

外部已经接收请求后不自动切下一条路线，避免一次操作变成两次发布。SDK 结果不明、网络超时、用户回到 App 都不能触发自动重发。

### 4.3 一个能力例子

```json
{
  "providerId": "system",
  "adapterId": "android.sharesheet",
  "operation": "share",
  "platformCondition": "API >= 35, result listener enabled",
  "observableOutcomes": ["targetSelected", "copied", "edited", "indeterminate"],
  "publicationReceipt": false,
  "evidenceStatus": "documented"
}
```

这是拟定的描述格式，不是声称当前代码已经实现 result listener。结果集合不是按强弱排列的数字等级：复制到剪贴板不能升级为向社交平台发布。

## 5. 结果模型

每个操作有一个 caller 终态，且附带 `source`、`observedStage`、`correlationAssurance` 和必要的提供方错误码；不用通用 `success=true` 掩盖观察边界。

| 结果 | 准确含义 |
| --- | --- |
| handedOff | 系统/外部入口接受了交接；不保证到了指定 App |
| targetSelected | chooser 报告选择了接收组件；不保证接收方发送 |
| copied / edited | chooser 报告对应动作完成；不推断社交发布 |
| activityCompleted | iOS activity 报告执行完成 |
| sdkReportedSuccess | 厂商 SDK 报告成功，保留其归因保证；不是服务端最终发布证明 |
| publicationConfirmed | 具有对应权限的可信平台服务端接口确认了特定发布结果；需要独立证据 |
| credentialReceived | 收到指定类型的授权凭证；尚未建立业务登录态 |
| notCompleted | 平台只说未执行，未能进一步确认原因 |
| cancelledByUser | 平台明确报告用户取消 |
| cancelledLocally | 调用方取消本地等待；不代表撤回外部行为 |
| failed | 已知错误及发生阶段；记录外部行为是否可能已经发生 |
| indeterminate | 请求已经交接或状态不明，当前无法确定结果 |

iOS `completed=false` 要检查 error；没有明确原因时用 `notCompleted`。Android 没有 chooser 结束通知时，不以 onResume 推断取消。超时后也不能一律返回 cancelled。

调用方可要求特定 `requiredObservation`，例如 `publicationConfirmed`；若 provider 没有能力观察，就在发送前拒绝。默认 `bestAvailable` 返回 Plan 声明范围内的结果，绝不自动强化。

## 6. 回调、并发与请求关联

### 6.1 路由所有权

App 级 `CallbackRouter` 负责登记哪个 adapter 拥有哪些精确路由，宿主转交 AppDelegate/SceneDelegate、Android onCreate/onNewIntent 等入口。只有明确接管并处理的事件才返回 handled。

URL 用解析后的 scheme、host、path 和已登记 App 配置匹配，不用 `hasPrefix("wb")` 之类前缀归属。SDK 路线必须先交 SDK 做其规定的校验，再检验响应类型、state/transaction 和 pending 上下文；不直接相信 Intent/URL 里的 openid、errCode 或对象类名。

浏览器 redirect 检查已登记的端点部分及固定参数，动态 code/state 则按协议解析；不能把整个带动态参数的回调字符串和初始 redirect 简单比较。拒绝重复或冲突的敏感参数、非预期的 token/fragment 和重复解码。厂商专用路由按其明确契约登记，路由匹配本身不是校验完成。

冷启动要处理 Scene connectionOptions 和 Android 首个 Intent。没有可恢复 pending 上下文的回调标记为 orphan，不合成一次授权成功。认证 state、PKCE verifier、nonce 如需跨重启恢复，用受保护的短期 journal 保存；原始令牌不写明文偏好存储。没有 journal 的默认行为是 fail closed，由用户重新开始。

### 6.2 关联保证不能伪造

```text
CorrelationAssurance = requestBound      // 经验证的 state/transaction 等
                     | sdkManaged       // 有明确文档保证的 SDK 会话归属
                     | serializedOnly   // 只保证同一通道最多一个在途请求
                     | unknown
```

微信 iOS 分享公开响应没有可用的通用 requestId。串行化能减少错配，但不能在新请求期间区分一个无 ID 的旧重复响应，不能声称严格关联已经解决。要求 `requestBound` 的调用必须在 preflight 拒绝此能力；允许 `bestAvailable` 的调用得到带 `serializedOnly` 标记的 SDK 报告。这一限制不能靠在本地生成 UUID 消除。

WeChat 授权的 state 和 Android 可用的 transaction 可用于绑定，但具体响应字段必须按锁定 SDK 确认。QQ/微博需要核对拟接入 SDK 的会话保证，不能凭平台名假定具备同样的 requestId。

### 6.3 两种锁和两种生命周期

- **展示锁**：限制同一原生展示上下文的交互 UI，避免同时弹出多个页面。
- **provider 通道锁**：由厂商 SDK 的全局状态和回调关联能力决定，不简单按每个 client 实例各建一把锁。

Core 持有 app 级 provider registry，避免新建 client 实例绕过在途限制。终态前处理状态先置位再调用业务回调，允许调用方重入而不产生重复终态。

同一 SDK 的冲突 App ID、重复 provider 所有者或重叠的独占路由在注册阶段报错，不采用最后注册者覆盖。等待预算可在 client 级设置、由单次请求覆盖；它与厂商授权码/令牌有效期不同。没有后续观察能力的 Plan 在交接后即可返回 handedOff，不为了等待不存在的回调一直持有操作。

caller 等待已取消，不代表 provider 请求已结束。对不可关联的在途响应，保留通道占用，直到有可确认结束事件或文档支持的重同步步骤。不能到达 deadline 就释放后让旧回应完成新请求。

进程重启也不能凭空证明旧请求结束。恢复状态不明时报告 `blockedUnknown`；严格关联策略不允许继续。若宿主选择较弱策略重新开始，应继续暴露该 provider 的关联限制，不能声称跨重启 exactly-once。重复回调可以去重到已知请求，但不可为没有标识的响应发明唯一标识。

### 6.4 状态机

```text
created → validating → awaitingApproval/permission → preparing
        → dispatching → awaitingExternal → terminal

发送前的确定错误                  → failed
发送前的本地取消                  → cancelledLocally
交接之后的本地取消                → caller terminal；通道/资源按实际状态保留
明确的外部回应                    → 对应可观察终态
交接后超时或丢失上下文            → indeterminate，不自动重发
```

迟到回应可用于释放通道或记录脱敏诊断，不再次完成已终止的 caller。操作取消、外部撤回、令牌撤销和退出业务账号是四个不同动作。

## 7. 登录与业务服务端

推荐接口分为 `authorize`、可选 `fetchProfile`、`clearLocalCredentials` 和可选 `revokeAuthorization`，不提供一个含义不明的全局 `isLogin`。缓存有 token 不代表它未被撤销，更不代表业务服务端会话有效。获取资料需要额外权限时，必须由宿主明确发起增量授权。

### 7.1 凭证处理

| 凭证 | SDK/客户端负责 | 业务服务端或受信任验证器负责 |
| --- | --- | --- |
| 授权码 | 关联回调、一次性交付、隐藏敏感日志 | 按正确应用类型和提供方规则兑换；保管 confidential client secret |
| OIDC/Apple ID token | 保存请求 nonce 上下文并安全交付 | 验签、受信任 issuer/JWKS、允许算法、audience/时间/nonce；不是只 decode JWT |
| 原生 SDK access token | 如实标记类型、提供方、客户端配置及已知过期信息 | 按提供方允许的接口核实 token/身份/应用归属；未能确认的保证不能补造 |

只在提供方实际支持时启用 PKCE/OIDC；缺少证据的能力默认 unknown。已确认安全的公共客户端可以按其注册方式直接交换令牌，不被强迫依赖 OpenShare 云服务；需要 app secret 的交换放在宿主服务端。

服务端建议先创建短期 `authAttempt`，绑定提供方、客户端注册和请求上下文；验证后发放应用自己的 session。授权码兑换通过 attemptId 做幂等处理。网络结果不明时先查询该 attempt，不能盲目重用一次性 code。

如果服务端接收网页回调，再回到移动 App，回传一个短期、一次性、绑定该 attempt 的不透明票据；App 向自己的服务端兑换结果。不在回跳 URL 中放 app secret、长期 token 或业务 session。

### 7.2 身份模型

服务器身份键包含提供方、issuer/注册范围与 subject。微信 openid 与 unionid 不互换，unionid 并非必有；QQ 的应用范围、Apple 的开发者/应用范围等必须按官方定义处理。不凭相同昵称、头像或邮件自动合并账户。

用户信息中未返回的字段保持 absent；没有明确的 granted scopes 不把 requested scopes 当成已授权列表。刷新、撤销和账号转移是可选能力，各有提供方规则。

## 8. 媒体资源与隐私

资源准备独立于发送：检查可读性、MIME、已知大小和媒体要求；需要压缩/转码时报告转换和损失。下载网络资源是显式模块，设置字节数/重定向/超时与目标约束；核心不默认抓取链接预览内容或上传图片。

`MediaLease` 管理 SDK 创建的临时文件、相册资源访问和 URI 权限。**本地操作结束不代表远端读完文件**：handedOff、targetSelected 或本地取消后不能立即删除附件/撤销授权。由平台明确的消费结束事件或宿主选择的保留策略决定清理；不存在适用于所有接收方的“30 秒后一定安全”。

iOS 对安全作用域资源持有必要访问期；写相册仅在 provider 要求且用户批准后进行。Android 使用最小只读 URI 授权，避免写权限、广泛存储权限和全量包可见性。桥接进程重启后不能恢复资源时返回明确错误。

默认无统计、设备指纹、自动短链及 method swizzling。厂商 SDK 自身的隐私行为和权限另行列入 provider 文档；适配器尊重宿主的授权时序，不能把“配置 provider”实现成隐式初始化所有 SDK。

## 9. 错误与诊断

建议错误族：`invalidContent`、`unsupportedContent/Field/Channel/CredentialKind`、`capabilityUnknown`、`unsupportedObservation/Correlation`、`configurationMissing`、`approvalRequired`、`permissionDenied`、`providerUnavailable`、`busy/blockedUnknown`、`dispatchRejected`、`callbackRejected`、`credentialInvalid`、`resourceUnavailable`、`providerError`。

错误带 stage、provider code、是否有外部副作用及可执行的恢复建议。重试建议不等于自动重试。原始错误数据可能含 token/URL，必须在可记录的诊断之前脱敏、限长，不把整份 vendor response 随手打印。

## 10. 接入示意

下列为拟定调用形式，不是现有 API：

```swift
// Swift async 便利层；配置只含公开 client ID 和回调设置。
let client = OpenShareClient(providers: [SystemShareProvider(), wechatProvider])
let plan = try client.prepare(.share(.link(url), to: .wechat(.session)))
let operation = client.execute(plan, presentingFrom: context)
let outcome = await operation.result
// switch outcome，不把交接、SDK 成功和发布确认合并成 Bool。
```

```java
// Java 回调层无需 Kotlin 协程依赖。
SharePlan plan = client.prepare(request);
Operation operation = client.execute(plan, presentationContext);
operation.onResult(result -> renderObservedResult(result));
```

简单系统分享可提供组合 prepare/execute 的便利方法，但仍沿用相同的错误和结果定义。高级调用方能先检查 Plan；语言桥接共享契约与路由所有权，不能另建一份静态全局 callback。

## 11. 当前明确不进入核心的业务

支付、好友关系、统计后台、短链、自动账号合并与服务端业务会话都不是默认分享登录核心职责。支付若保留，放在独立模块，不能通过 ShareContent 的通用扩展偷偷传 PayReq，再把 SDK 回应当成到账。

本草案没有新增这些接口的运行实现；落地按[分阶段迁移计划](validation.md)推进，保留现有 PR 的已验证基线。
