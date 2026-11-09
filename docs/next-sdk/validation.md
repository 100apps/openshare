# OpenShare Next：验证、落地与迁移

日期：2026-11-09。以下是设计验收标准，未打勾的未来能力不能称为已实现或已通过测试。

## 1. 已经确认与尚未完成

| 对象 | 当前证据 | 不覆盖什么 |
| --- | --- | --- |
| ShareSDK iOS 4.4.51 | 已读取版本化 podspec、ZIP 目录及选定当前头文件，记录哈希 | 没有运行它、构建最终 App、抓网络流量或验证 Lite 能力 |
| ShareSDK Android 3.10.36 | 已核对官方 Maven release，下载指定 Core/微信/QQ/微博制品作静态检查 | 没有运行库或解析完整插件依赖图；不能据空 POM 声称独立无依赖 |
| 微信 2.0.9 / 6.8.40 | 已检查公开 API；Android 部分序列化和传输校验作静态观察 | 没有用自身 App ID 完成真实登录/分享，没有独立 wire 互通实现 |
| QQ、微博、抖音等 | 已按[来源目录](../research/sources.md)标明文档/制品/索引证据 | 不是所有平台均已实现 adapter 或通过最新客户端测试 |
| 当前 OpenShare 基线 | [四组 CI 已通过](https://github.com/100apps/openshare/actions/runs/42510143598) | 不覆盖 Next 契约、ShareSDK 集成或真实账号授权 |
| Next 契约 | P1 已实现 Core、系统分享、公开链接及可选微信 Provider | 实际范围与测试见[实现说明](implementation.md)；下列 36 项仍是完整路线图，不等于全部执行 |

研究中遇到的读取限制也保留在 evidence.json：微信指南的网络访问限制、Mob 隐私正文的 JavaScript 页面、Meta 429 等。没有用其他人的博客或 demo 密钥填补这些空白。

## 2. 分阶段实施

| 阶段 | 交付 | 完成门槛 |
| --- | --- | --- |
| P0 证据与契约 | 本轮文档、可追溯来源、能力与结果语义 | 事实/推断/待验证明确区分；关键设计约束可评审 |
| P1 核心与已有路径 | Core、SystemShare、公开链接；把现有微信适配器接到契约下 | iOS/Android 跑同一批契约场景，旧入口行为受控；不扩大已验证能力宣传 |
| P2 协议互通与重点登录 | Android 微信独立 wire PoC 优先，扩至 iOS/QQ/微博；BrowserAuth/后端接口及必要官方过渡适配器；Legacy 拆分 | 编码对照不等同于互通；对真实校验、凭证、关联与回调有版本化证据及真机验收 |
| P3 按需扩展 | 抖音、Apple、Google；具备资格后的小红书及其他平台 | 每项能力分别验收，不能以某个 share 测试替代该平台 auth 验证 |
| P4 可选桥接与扩展 | Flutter/RN 等薄封装及其他协议 adapter | 同一契约与证据等级；实验路径不自动升级为默认稳定能力 |

这不是同时支持 40+ 平台的承诺，也没有隐含的日期承诺。各阶段可以独立提交 PR。发布顺序由实际业务所需平台及已获得的接入资格决定。

## 3. 两端必须共用的契约场景

P1 已增加共享输入及 native 测试，具体覆盖见[实现说明](implementation.md)。下表保留更完整的后续验收要求，应随每项能力逐步落实。SDK 传输替身只验证状态机；真机测试另列，结果不能互相替代。

| ID | 场景 | 验收断言 |
| --- | --- | --- |
| C01 | 系统分享文字/Unicode/链接 | 内容保真，不自动短链或追踪 |
| C02 | 合法图片/文件引用 | 只读授权、生命周期正确，不强制读取为整份 Base64 |
| C03 | 空内容、不可读资源、Android file URI | 发送前失败，没有外部副作用 |
| C04 | iPad 来源视图失效、后台展示、Activity 销毁 | 清楚的展示错误，不崩溃、不更换未知窗口 |
| C05 | provider 支持图片但不支持 caption | strict 拒绝；替代 Plan 列出字段变化 |
| C06 | 目标不支持所选 channel/mini-program | 发送前失败，不偷换为文字或普通链接 |
| C07 | 配置缺失导致安装探测失败 | configurationMissing/unknown，不直接断言未安装 |
| C08 | SDK 未引入、应用未获批、权限未给 | 分别报告依赖/审批/权限状态 |
| C09 | 用户批准压缩或写入相册 | 实际内容与批准的 Plan 一致 |
| C10 | prepare 后资源或配置发生变化 | 执行前复核，必要时重新批准 |
| C11 | 系统接受启动 | 只报告 handedOff，不报告 published |
| C12 | Android 选择接收组件 | 只报告 targetSelected，不推断接收方发送 |
| C13 | API 35 chooser Copy/Edit | 返回对应动作；不混作社交发布 |
| C14 | iOS activity true/false/error | 正确区分 activityCompleted/notCompleted/failed |
| C15 | 平台没有结束或取消回调 | 回 App 不触发虚构取消；超时后 indeterminate |
| C16 | 发送前后分别 cancel | cancelledLocally；交接后的资源/通道不立即清空 |
| C17 | 有 ID 的迟到/重复/不相关响应 | 不再次完成 caller，不完成另一个请求 |
| C18 | 无 requestId 的响应 | 不宣称严格归因；requestBound 要求被 preflight 拒绝 |
| C19 | 无 ID 的在途请求取消后马上重试 | busy/blockedUnknown，不让晚回应完成新的严格请求 |
| C20 | 两个 client 操作同一全局 SDK | 共用 app 级通道限制，不通过实例数绕过 |
| C21 | 不同 provider 与同一展示上下文并发 | provider 与展示锁各按契约处理 |
| C22 | 回调里再次发起请求/抛出业务错误 | 终态先落定，不产生重复回调或损坏 registry |
| C23 | URL scheme 前缀相似、host/path 错误 | 不归属于当前路由，不吞掉其他模块回调 |
| C24 | SDK 校验失败、类型错、state/transaction 错 | 拒绝，不建立授权结果或业务会话 |
| C25 | Scene 冷启动、onCreate/onNewIntent | 同一所有者处理；无 pending 时视为 orphan |
| C26 | 重启后 verifier/资源丢失 | fail closed 或明确资源错误；不猜测恢复成功 |
| C27 | 微信 code、微博 token、Apple 凭证组合 | 保留类型；不把 token 改名为 code |
| C28 | scope 未确认、缺少 profile 字段 | 不把请求 scope 当成已授权；字段保持 absent |
| C29 | OAuth state/PKCE、OIDC issuer/aud/nonce 错 | 各按已支持流程拒绝；不能只 decode JWT |
| C30 | 一次性 code 交换超时 | 按 attempt 查询/幂等处理，不盲目重复兑换 |
| C31 | 本地退出、撤销提供方授权、业务退出 | 三个独立动作，不因清缓存声称撤销授权成功 |
| C32 | SDK/客户端接受请求后结果不明 | 不自动切系统分享或再次调用发布 |
| C33 | URI 尚被接收方读取，本地已终止 | 租约不因 caller terminal 立即销毁 |
| C34 | 默认构造 Core/SystemShare | 不初始化其他 SDK、不联系 OpenShare/Mob 云端、不枚举 App |
| C35 | 默认日志与桥接事件 | 不含原始 token、code、state、verifier、完整回调 URL |
| C36 | provider 版本或契约字段未知 | 不通配接受；返回可诊断的不支持/未知能力 |

C18 不是要求测试引擎神奇识别没有标识的旧响应。它要求能力与结果如实暴露 `serializedOnly`，严格模式在执行前拒绝该保证；具体限制见[设计第 6 节](design.md)。

## 4. 每个平台的真实验收记录

每次测试记录 OS/设备、目标 App 版本、adapter/SDK 版本和制品哈希、应用注册类型、包名/Bundle ID、签名与域名配置、内容/渠道、步骤、实际响应和证据。App ID 可脱敏；不要把 secret/token 放进公开报告。

| 平台 | 必须覆盖的项目 |
| --- | --- |
| 系统 | 手机/平板、文本/链接/媒体、横竖屏、多窗口、目标选择、复制、取消/未完成、文件延迟读取 |
| 微信 | 安装/未安装、会话/朋友圈各支持内容、Universal Link、Android 签名和回调 Activity、成功/拒绝/取消/冷启动、授权 state；服务端兑换另测 |
| QQ/QZone | 正确移动注册、平台 SDK 回调、不同渠道的媒体差异、凭证形态、实际 SDK 会话保证、域名/签名错误 |
| 微博 | SSO、受控的不可用行为、真实 token 结果、SDK WebView 回退策略、请求关联与服务端验证能力 |
| 抖音 | 授权码、回调、相册权限、图片/视频/编辑页、用户放弃、ShareID 查询所需的独立权限 |
| 小红书 | 接入资格、文字限制、iOS 相册、Android FileProvider、用户离开后无结果、目标版本；不能用一次懒鉴权通过代表持续可用 |
| Apple/Google/X | 对应平台注册、nonce/PKCE/令牌校验、拒绝/撤销/过期；不把一个桌面或网站样例当成两端验证 |
| 公开链接 | 正确编码、App/浏览器两种交接、无安装情形；没有发布回执时仍报告 handedOff |

授权功能不能只录屏“打开了客户端”。至少需要绑定请求上下文、实际凭证及宿主后端验证结果的受控证据。发布确认只有在平台提供相应可信接口时才能验收。

## 5. CI 与构建策略

四组 CI 同时验证新旧接口，包括共享输入、Core 生命周期与官方 SDK 类型的替身传输测试。手机/平板的真实系统面板 UI 已切换新 client；这不代表社交客户端的真实登录/发布通过。

持续验证要求：

1. Core 与纯链接构造的单测不依赖真实凭据或已安装社交 App；iOS/Android 使用一致的场景数据。
2. 系统面板在手机/平板模拟器上做真实 UI 检查；Android 增加不同 API 级别的 chooser 观察分支、URI 授权及 16 KB 页兼容。
3. 可选模块分别构建；验证只选核心的依赖树。厂商回调状态机使用真实 SDK 类型、模拟传输，清楚标注替身边界。
4. 指定 SDK 的 class 如不适用于标准 JVM 校验，应在 ART 运行相关测试，不通过禁用 verifier 伪造通过。
5. 真机授权和发布采用自有已审核配置单独验收；不把示例密钥放进公共 PR CI，不让 CI 中的替身结果冒充平台真实成功。
6. 固定 SDK/构建依赖及校验值，记录实际 Xcode/Android SDK。升级通过单独 PR、兼容矩阵和必要真机回归，不使用 `+` 自动替换平台 SDK。

体积与性能另做可复现测量：相同空宿主、Release、相同架构与裁剪设置，对比仅核心及每种模块的最终增量，分别记录冷启动、初始化和首个请求。下载 ZIP 大小、模拟器 slice 或聚合商宣传值不能代替这些数据。

## 6. 从当前实现迁移

| 当前入口 | 下一步映射 | 兼容限制 |
| --- | --- | --- |
| OSMessage + System category | 明确的 ShareContent 与 SystemShareProvider | 旧多空字段先校验，无法判断时拒绝，不猜类型 |
| Android ShareMessage/OpenShare | Core 请求、SystemShareProvider | 保留原 boolean 启动结果的旧接口，新接口返回准确结果 |
| OSWeChat / Java WeChat | 官方 WeChat provider 的第一批实现基础 | 新 Provider 已补充 app 级所有权、能力及关联保证；旧 API 继续保留 |
| 原微信/QQ/微博/人人 category | 显式 Legacy 包与迁移说明 | 不自动作为新 provider 的失败回退，不把旧回调升级为可信凭证 |
| 旧字符串/布尔成功回调 | 旧兼容层保留原契约，新接口使用结构化结果 | 无法恢复的原因标为 unknown/legacy；不把旧 cancelled 一概解释成用户取消 |
| 现有 PayReq / 支付宝接口 | 独立支付模块或保留为 Legacy | 不进入 ShareProvider/AuthProvider 的通用扩展逃生口 |

先并行引入新入口，再在明确的兼容版本中迁移默认依赖。移除默认 Legacy 属于需要版本说明的接口/依赖变化，不能仅靠更新文档就改变已发布用户行为。

同一个 App 中只能有一个模块拥有某个 SDK/URL 路由。禁止同时初始化聚合商和独立适配器处理同一平台，然后依赖 swizzling 顺序决定谁收到回应。

## 7. 尚待补证的项目

- ShareSDK Lite 的逐项运行能力、是否依赖宿主已有厂商 SDK，以及聚合服务网络行为。
- ShareSDK Android 插件组装后的精确运行依赖图、动态路径及实际运行行为；已核对的 3.10.36 元数据不能代替这些结果。
- QQ/微博拟接入 SDK 的精确凭证、请求关联和回退保证；微博新版标准浏览器流程/PKCE 证据。
- 微信最新可访问的服务端官方指南及本项目真实 App ID 验收。
- 小红书当前接入资格、限制及具体合作应用的能力；Meta 最新文档/权限；X 旧 Web Intent 的现行契约。
- 任何独立私有 wire adapter 的完整互通链路、目标版本范围及回归成本。

以上条目在证据补齐前不进入稳定支持清单。这些是后续具体接入工作的门槛，不妨碍先实现已确认的系统分享、公开链接和 Core 契约。
