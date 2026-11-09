# 登录与分享协议调研：来源与证据

核对日期：2026-11-09。对应 OpenShare 基线：`5ed0cf4978f09bcb7f4dd9671b24e7becbef3902`。

本文只使用平台官方资料、官方分发制品、厂商公开仓库和本项目源码。没有运行 ShareSDK、向社交平台发起授权、使用示例应用密钥，或完成真实发布。文档可访问、静态字段存在、当前客户端可互通，是三个不同的结论。

证据标记：**D**＝官方公开文档；**A**＝指定版本制品静态检查；**L**＝本项目历史实现；**S**＝官方页面的搜索索引摘要，当前正文读取受限；**U**＝未确认。D/A 都不能代替真机验收。文件哈希、提交号和读取限制记录于 [evidence.json](evidence.json)。没有把第三方 SDK 或头文件复制进仓库。

### M01

Mob 产品页：[用户提供的移动页](https://m.mob.com/mobService/sharesdk)、[桌面页](https://www.mob.com/mobService/sharesdk)。D。可确认产品宣传范围包括分享、授权登录、短链和回流统计。“40+ 平台”“600K”是厂商宣传，本文没有把它们当作全量功能、最终安装包体积或实测结果。

### M02

[CocoaPods 4.4.51 原始 podspec](https://trunk.cocoapods.org/api/v1/pods/mob_sharesdk/specs/4.4.51)。A。研究时 `specs/latest` 返回 4.4.51；这里只称它为该发布渠道查询到的版本，不代表所有渠道的最新版本。

podspec 指定的[官方分发 ZIP](https://sdk-dev-ios.oss-cn-hangzhou.aliyuncs.com/files/download/sharesdk/ShareSDK_For_iOS_v4.4.51.zip)共 73,859,066 字节。检查 ZIP 目录并按 HTTP Range 提取了 ShareSDK、SSDKRegister、WeChatConnector 的公开头文件，核对了 CRC 和单文件 SHA-256。没有下载完整 ZIP，因此没有声称计算了完整 ZIP 的 SHA-256；archive 大小也不是 App 增量大小。

### M03

[MobClub iOS 仓库固定快照](https://github.com/MobClub/ShareSDK-for-iOS/tree/b81262ceefa0e8394f4f06d6a4f3215fa42c319d)。A。其仓库 podspec 仍写 4.4.23，不能用来代表 M02 的 4.4.51。当前头文件结论优先使用 M02；旧快照只用于确认项目组织及历史兼容关系。

### M04

[MobClub Android 固定快照](https://github.com/MobClub/ShareSDK-for-Android/tree/3eabd65ca4b5b088431657ee8ad14c42c8ff1f2f)、[平台配置](https://github.com/MobClub/ShareSDK-for-Android/blob/3eabd65ca4b5b088431657ee8ad14c42c8ff1f2f/SampleFresh/MobSDK.gradle)。A。可确认按平台注册参数和插件式集成；示例 App 的 `versionName=3.9.10` 不是当前 ShareSDK Android 库版本。没有运行 Mob Gradle 插件，也没有解析带真实应用配置的依赖图。

配置里的历史 `bypassApproval` 注释仅说明该示例曾描述有限的文本/图片路径，不是当前授权或平台审核豁免的证据。本文不复制示例 AppKey/AppSecret，也不以其作为测试凭据。

### M05

[Mob ShareSDK FAQ](https://www.mob.com/problem/sharesdk)。D，页面标注更新时间 2019-06-26，属于历史资料。用于说明配置与平台能力差异，不用于证明当前 SDK/客户端支持状态。

[ShareSDK 隐私政策入口](https://www.mob.com/wiki/detailed?id=1&wiki=638)及[合规入口](https://m.mob.com/wiki/detailed?id=14&wiki=32)本次正文读取受 JavaScript 页面限制。搜索索引有正文，但不据此断言当前版本每次调用会收集哪些信息、数据实际发往何处，或各字段是否可关闭。需补充浏览器正文和网络实测。

### M06

[ShareSDK Core Maven 元数据](https://mvn.mob.com/android/cn/sharesdk/ShareSDK/maven-metadata.xml)、[微信模块元数据](https://mvn.mob.com/android/cn/sharesdk/ShareSDK-Wechat/maven-metadata.xml)、[微信 Core 元数据](https://mvn.mob.com/android/cn/sharesdk/ShareSDK-Wechat-Core/maven-metadata.xml)。A。研究时这些官方仓库入口的 release 为 **3.10.36**，更新时间字段为 2026-09-28；不称其为所有渠道的绝对最新版。

已下载并记录哈希：Core AAR、WeChat / WeChat-Core / QQ / SinaWeibo 的 JAR 与对应 POM。Core AAR 的实际字节码位于 `libs/ShareSDK-3.10.36.jar`。微信 Core 含 `cn.sharesdk.wechat.utils` 的消息模型及传输类；静态检查确认其 Bundle/Intent 构造、内容标识映射和返回解析。QQ/微博模块也检查了目标路由及部分字段。没有运行这些库。

这些 POM 没有声明完整传递依赖；不能把空 POM 等同于零运行依赖。模块引用 Mob 公共运行库，完整 Gradle 运行依赖与动态加载行为仍未验证。没有复制其模型或校验实现到 OpenShare。

### W01

[腾讯 iOS OpenSDK 2.0.9](https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.9.zip)。A。完整 ZIP 的 SHA-256：`ebbdd935f840bedabe1c39ad6149356b37764645ff939ce0160a438520545697`，本次重新下载核对通过。依据 `WXApi.h`、`WXApiObject.h` 核对 `sendReq`/`onResp`、Universal Link、授权 `scope/state/code`。没有据头文件推导完整私有 IPC 格式。

### W02

[腾讯 Android OpenSDK 6.8.40 AAR](https://repo.maven.apache.org/maven2/com/tencent/mm/opensdk/wechat-sdk-android/6.8.40/wechat-sdk-android-6.8.40.aar)。A。SHA-256：`c3c3215f2bc7f6aad0454541f9bdd91878cdb15b64d35e194a6c9240000c5d48`。对已下载的 `classes.jar` 使用 JDK `javap -c -p`，检查模型的 Bundle 序列化和传输入口；没有执行 SDK，也没有修改或跳过签名/校验逻辑。字段存在不等于完成独立互通实现。

### W03

[微信移动应用登录指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/WeChat_Login/Development_Guide.html)、[iOS 分享指南](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Share_and_Favorites/iOS_Development_Guide.html)。U：本次访问被工具/网络限制，不能把它们写成已读取的最新正文。W01/W02 足以确认 SDK 对外字段；服务端具体端点、权限和生命周期仍需在接入前用可访问的官方文档及已审核应用复核。

### Q01

[QQ Authorization Code 流程](https://wiki.connect.qq.com/使用authorization_code获取access_token/)。D。可确认网站应用的 `code/state`、服务端使用 `client_secret` 换令牌；页面明确区分网站和移动场景，不能将网站 H5 流程直接当作移动 App SSO。

### Q02

[QQ iOS 环境搭建](https://wiki.connect.qq.com/ios_sdk环境搭建/)、[API 说明入口](https://wiki.connect.qq.com/ios_sdk头文件所有api接口说明/)、[Universal Links FAQ](https://wiki.connect.qq.com/universal-links适配faq/)、[Android 接入](https://wiki.connect.qq.com/qq登录/)。D，含历史版本说明。可确认 SDK、应用注册及回调接入要求；不将其中旧版本号当成当前最新版。精确移动凭证输出和最新媒体限制仍需锁定新 SDK 后验收。

### B01

[微博 iOS SDK 固定快照](https://github.com/sinaweibosdk/weibo_ios_sdk/tree/632f6d5672fdc89091ec9ea88321efb5183fbc67)、[公开头文件](https://github.com/sinaweibosdk/weibo_ios_sdk/blob/632f6d5672fdc89091ec9ea88321efb5183fbc67/libWeiboSDK_xc/WeiboSDK.xcframework/ios-arm64/WeiboSDK.framework/Headers/WeiboSDK.h)。A。核对 `WBAuthorizeResponse` 的 `userID/accessToken/expirationDate/refreshToken`，以及 SSO 不可用时的 WebView 回退开关。SDK 自带回退不是必须照搬的设计。

### B02

[微博 Android 官方 README 固定快照](https://github.com/sinaweibosdk/weibo_android_sdk/blob/14fa654d2ae9d532e1357723236babf2aa71f88f/README.md)。A/D。该快照声明 SDK 13.10.8，区分 Web 与 SSO，并说明返回 token。没有下载/运行这一 SDK。旧 `open.weibo.com/wiki/...` 本次检索不能稳定取得原协议正文，因此不确认通用 PKCE 支持或原端点继续有效。

### D01

[抖音 Android 授权](https://open.douyin.com/platform/resource/docs/develop/permission/android/permission-develop-guide)、[iOS 授权](https://open.douyin.com/platform/resource/docs/develop/permission/ios/permission-develop-guide)、[总体授权](https://open.douyin.com/platform/resource/docs/develop/permission/overall-permission/)。D。确认 OAuth 2.0 授权码模型、SDK 回调及 state；不据此推断原生流程支持 PKCE。

### D02

[抖音 iOS 分享](https://open.douyin.com/platform/resource/docs/develop/share/ios)、[权限目录](https://open.douyin.com/platform/resource/docs/accession-guide/type-and-permission)。D。确认媒体/相册资源传递、发布界面，以及另需权限的 ShareID 数据追踪。SDK 分享回调与服务端查询不是同一观察方式。

### R01

[小红书分享平台](https://agora.xiaohongshu.com/)、[iOS](https://agora.xiaohongshu.com/doc/ios)、[Android](https://agora.xiaohongshu.com/doc/android)、[FAQ](https://agora.xiaohongshu.com/doc/qa)。S/A：官方搜索索引可读，直接正文是 JavaScript 空壳；M02 制品另外确认存在 XHS SDK 及 connector。索引显示暂停接入、限制自动填充标题/文案、iOS 相册传递和 Android FileProvider 等说明。暂停是否适用于特定已合作应用，需平台确认。电商平台 `open.xiaohongshu.com` 的商家 OAuth 不能替代此分享平台的消费用户登录。

### A01

[Apple Web Authentication](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)、[可机器读取的官方 Markdown](https://developer.apple.com/tutorials/data/documentation/authenticationservices/aswebauthenticationsession.md)。D。核对系统承载的浏览器认证会话、回调归属及 API 可用性；“外部用户代理”不要求界面一定跳出 App，自定义可注入脚本的 WKWebView 与该系统会话不同。

### A02

[Apple 身份验证](https://developer.apple.com/documentation/signinwithapple/verifying-a-user)、[官方 Markdown](https://developer.apple.com/tutorials/data/documentation/signinwithapple/verifying-a-user.md)。D。确认身份令牌、授权码及服务端校验职责。

### A03

[UIActivity completion](https://developer.apple.com/documentation/uikit/uiactivityviewcontroller/completionwithitemshandler-swift.typealias)、[官方 Markdown](https://developer.apple.com/tutorials/data/documentation/uikit/uiactivityviewcontroller/completionwithitemshandler-swift.typealias.md)。D。`completed=false` 表示 activity 未执行，可能有错误；不能一概当成用户取消。`true` 不证明第三方服务端已发布。

### A04

[Apple Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)、[官方 Markdown](https://developer.apple.com/tutorials/data/documentation/xcode/supporting-universal-links-in-your-app.md)。D。域名关联是路由机制，不自动证明回调业务字段可信。

### G01

[Android Sharesheet](https://developer.android.com/develop/ui/compose/sharing/send)、[ChooserResult](https://developer.android.com/reference/android/service/chooser/ChooserResult)。D。确认 ACTION_SEND、URI 授权及选择结果；API 35 的结果包含选择组件、复制、编辑等会话动作，不是接收方最终发送的回执。

### G02

[Android App Links 验证](https://developer.android.com/training/app-links/verify-applinks)。D。确认域名关联、`assetlinks.json` 与签名证书关系。

### G03

[Google Android 登录](https://developer.android.com/identity/sign-in/credential-manager-siwg)、[Google iOS 登录](https://developers.google.com/identity/sign-in/ios/start-integrating)。D。确认平台专用集成路线；桌面 OAuth 指南不能直接用来承诺 Android/iOS 的任意自定义 scheme 流程。

### O01

[RFC 8252](https://www.rfc-editor.org/rfc/rfc8252)、[RFC 7636](https://www.rfc-editor.org/rfc/rfc7636)、[RFC 9700](https://datatracker.ietf.org/doc/html/rfc9700)。D。分别作为原生应用浏览器认证、PKCE 和 OAuth 安全基线。不能因为标准建议 PKCE，就声称某个厂商已实现它。

### O02

[OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)。D。OIDC 在 OAuth 上提供身份层，不能把所有 OAuth 提供方当成 OIDC 提供方。

### T01

[Telegram 分享按钮](https://core.telegram.org/widgets/share)。D。确认 `https://t.me/share/url` 的 URL/text 参数。这一资料没有证明附件传递、发布回执或登录能力。

### T02

[WhatsApp click to chat](https://faq.whatsapp.com/5913398998672934)。D。确认 `wa.me` 和预填文字；聊天入口不能被称为已发消息或通用 OAuth 登录。

### X01

[X OAuth 2.0 PKCE](https://docs.x.com/fundamentals/authentication/oauth-2-0/authorization-code)。D。确认此授权路线，不自动确认旧 Web Intent 地址、发帖权限或 OIDC。旧 Tweet Button 文档链接本次跳至文档首页，Web 分享地址需另行复核。

### F01

[Meta Share Dialog 参考](https://developers.facebook.com/docs/sharing/reference/share-dialog/)。U：本次返回 429。M02 可确认分发结构存在相关模块，但不能据此确认当前 Graph API 权限和具体分享能力。

### L01

[OpenShare 基线源码](https://github.com/100apps/openshare/tree/5ed0cf4978f09bcb7f4dd9671b24e7becbef3902/openshare)。L。微信、QQ、微博、人人及支付宝字段以对应 category 的实际构造/解析代码为准。这是历史实现证据，不是这些协议如今仍可用的证明。

### C01

[上一轮完整 Mobile CI](https://github.com/100apps/openshare/actions/runs/42510143598)。只证明基线原生系统分享、现有微信适配器的编译/模拟传输测试及既有集成方式。没有验证 ShareSDK 的产品宣传、真实社交 App 登录发布，或后续新增的 Next 实现；新实现的范围与独立验证见[实现说明](../next-sdk/implementation.md)。
