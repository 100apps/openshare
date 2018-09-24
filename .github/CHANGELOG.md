# Change Log

-----

## [0.0.1](https://github.com/100apps/openshare/releases/tag/0.0.1) (2015-06-05)

支持支付宝／微信支付

![](https://raw.githubusercontent.com/100apps/openshare/gh-pages/images/pay.gif)

对于微信支付，首先要去 [申请开通支付能力](https://open.weixin.qq.com)。如果 App 已经「获得微信支付能力」，那么请去配置 `pay.php`。同样对于支付宝，也需要配置，否则 Demo 是无法运行的。

我强烈反对把密钥等放在 App 客户端里面，我相信一般人也不会这么干！所以 OpenShare 支付只支持服务器端计算签名。`pay.php` 是用「世界上最好的语言」写成，当然你可以很方便的把它转化为其他语言实现。
