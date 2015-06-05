<?php
/*注意以下partner，key等参数都是示例用的，已经根据我申请的key进行了替换（位数是对的,^_^），直接用是行不通的，须换成你自己的。*/
if($_GET["payType"]=="alipay"){
    //支付宝支付的服务器端
    $partner = "1111512341234567";
    $seller = "gf@gfzj.us";
    //坑，注意，需要转换密钥！！！ openssl pkcs8 -topk8 -inform PEM -in your.key -outform PEM -nocrypt > your_nocrypt.key
    // $privateKey=file_get_contents("/ramdisk/your_nocrypt.key");//这里为了方便直接写入到php文件里了。
$privateKey=<<<EOF
-----BEGIN PRIVATE KEY-----
DEMO/private/key/EfgHijklmnkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC
4ptuRrkZVFKns0dTg/tsga33eOxXgz0eGzm6svcbHk5zJvxIH7w01QCh1Og4ZJ3i
LLU0SyAdajUl4yNLWp/wc49gtkYZVg+z57o2f2kSzq5POsfWB2c+fTzTxZzyKgOu
AbcdEfgHijklmnd62IjiRKm8UtSaM4+/sFSz0x2UPDFD4J0lun9zvJx7iEhAVFz9
uG/r3NiPujVMQRVs3ZQ93xfaRPo6U8zrB/KN8q6UZXCA2Tq9NlAZLvmUstZEryP+
hkZJgwdL/FAL4YjKdqcOw1RHYjLBOBDHWbzT9s294hZLIQGqN1mkiEi4PicNFX7E
hjz0hHYHAgMBAAECggEADzDAMke0tebwUy8GN73ETgdfs2WscHZujqwWj6o9Bo83
GHQrhFmoKpVNWzyHcJ1Usw1sjVe8CMlFjsm9jxP7zjNOvjJHmiyew3YH8y8unkk4
DZZra2Wc1NZ/GUOn0GPEi/MphblWZNJom5znxG5BJwjw1ypebAAuHVdelYyJUbiV
AZeEKWEcAlDV0hGNWwgeTgUyxvI1qD+Ynm8wmU7MNrIDvEcGSLwzG62i1tfc50Ye
LTYDJgWnIJjtlmYNHwAvnfbZUvZSAYHmP5DPCCNJy6QU5IH3ZOsMVXuqHsWs2TTL
aCx7XSFWCdeqSdL5fIz38XCH4hxlOORidZ/5stMZIQKBgQDYioT5rBqTQ5jnmTY7
XBJg1ktLL58wQZMpc4F4sCWTZJLAZVYSw98Gubv0RmDKgWJTEVihAMsP1Bjn0Rwg
KkoW65LzUfMtBgX6l5jTlg7YOkej9zBWprk7VRE2xCMk/x5KIm9oT/KxBVYM3QbN
rnXe5TvYSf5n6a5C3B5IwBio3QKBgQDE0EnCwwAO4JzGX9yURxxVJfCvIOM+7prO
mBfXiHTD0gPoC/VYobIwBpad0hsqG8oHfhCQ6GPYtE9Z96yDqy65ACBAD7wx5k5q
lLA0gFNlDgeHPVME+w1VyMPFDMI85Xn8MzfrpjvMycThz3t+1aLOjO86uGIFzeMR
Ay+lUM/6MwKBgDKpbeUQHAOaTBrbYLHQn8giOulzUdYzcV/AU2lOJOxwGlmDG/k1
9GcZa10CXkDitoNiyo6YpemlINKTvPXVjxH/uZjN8ov1Hc78StguAnkaYYp+GcQc
K7gy9d0PVH2iZo7HsbMBCXHbIr/NsnrKt28XyMGYxjm/lXK1FyzELMDNAoGAGNLU
mtYRic7Wt0acAa++aRbx9oTFZMififMw/qRdZd11VK09csJiQSBzmtBHUNZUcwF5
gW1uOoTzhTtx7OGIcRkM+EeDyx9rQJIkb1rIKfTNCke30ub/VZSO7KmhTiD7c83Z
/cTnwfqo9HpA70xuznKEMfnTkzvWqeym88jvknUCgYEAh4MDXbPAnkryK703D5/o
3PzGwGQ8Dc1bm8CdRz/S+Rxx/q5UbDRcmUeUk56ZzHLt9KJnOKEVxYxSRdpOnEIf
zb8h9f74FDlActvDmyszrpNqnvxw2LZO0Q0i9P0R0euv4FDUashJdGgltFyXAfpI
AbcdEfgHi/DPrS/TL45bsw=
-----END PRIVATE KEY-----
EOF;
    //组装订单信息。可以让客户端传进来orderId等信息，这里连接数据库，查询价格，商品名等信息。ps：价格一定不要让客户端传进来,免得被骗:)
    $dataString=sprintf('partner="%s"&seller_id="%s"&out_trade_no="%s"&subject="1"&body="%s"&total_fee="%.2f"&notify_url="%s"&service="mobile.securitypay.pay"&payment_type="1"&_input_charset="utf-8"&it_b_pay="30m"&show_url="m.alipay.com"',$partner,$seller,"out_trade_no".rand(),"我是测试数据",0.02,"http://www.xxx.com");
    //获取签名
    $res = openssl_get_privatekey($privateKey);
    openssl_sign($dataString, $sign, $res);
    openssl_free_key($res);
    $sign = urlencode(base64_encode($sign));
    $dataString.='&sign_type="RSA"&bizcontext="{"appkey":"2014052600006128"}"&sign="'.$sign.'"';
    //生成可以直接打开的链接，让iOS客户端打开：[[UIApplication sharedApplication] openURL:[NSURL URLWithString:$iOSLink]];
    $iOSLink= "alipay://alipayclient/?".urlencode(json_encode(array('requestType' => 'SafePay', "fromAppUrlScheme" => /*iOS App的url schema，支付宝回调用*/"openshare","dataString"=>$dataString)));
    echo $iOSLink;
    //也可以用Safari打开。可以尝试点击下面的链接。
    // echo "<h1><a href='${iOSLink}'>支付宝支付</a></h1>";
}else if($_GET["payType"]=="weixin"){
    // STEP 0. 账号帐户资料
    //更改商户把相关参数后可测试
    $APP_ID="wx0fff1111111111c6"   ;            //APPID
    $APP_SECRET="496f0d0913714d40demodemodemodemo";//appsecret
    //商户号，填写商户对应参数
    $MCH_ID="12451111111";
    //商户API密钥，填写相应参数
    $PARTNER_ID="DemoDemoklLQw4nu8t9LM9pPCBXKL96X";
    //支付结果回调页面
    $NOTIFY_URL="http://wxpay.weixin.qq.com/pub_v2/pay/notify.v2.php";

    //STEP 1. 构造一个订单。
    $order=array(
        "body" => "V3支付测试",
        "appid" => $APP_ID,
        "device_info" => "APP-001",
        "mch_id" => $MCH_ID,
        "nonce_str" => mt_rand(),
        "notify_url" => $NOTIFY_URL,
        "out_trade_no" => time(),
        "spbill_create_ip" => "196.168.1.1",
        "total_fee" => 1,//坑！！！这里的最小单位时分，跟支付宝不一样。1就是1分钱。只能是整形。
        "trade_type" => "APP"
        );
    ksort($order);

    //STEP 2. 签名
    $sign="";
    foreach ($order as $key => $value) {
        if($value&&$key!="sign"&&$key!="key"){
            $sign.=$key."=".$value."&";
        }
    }
    $sign.="key=".$PARTNER_ID;
    $sign=strtoupper(md5($sign));

    //STEP 3. 请求服务器
    $xml="<xml>\n";
    foreach ($order as $key => $value) {
        $xml.="<".$key.">".$value."</".$key.">\n";
    }
    $xml.="<sign>".$sign."</sign>\n";
    $xml.="</xml>";
    $opts = array(
        'http' =>
        array(
            'method'  => 'POST',
            'header'  => 'Content-type: text/xml',
            'content' => $xml
            ),
        "ssl"=>array(
            "verify_peer"=>false,
            "verify_peer_name"=>false,
            )
        );
    $context  = stream_context_create($opts);
    $result = file_get_contents('https://api.mch.weixin.qq.com/pay/unifiedorder', false, $context);
    $result = simplexml_load_string($result,null, LIBXML_NOCDATA);

    //使用$result->nonce_str和$result->prepay_id。再次签名返回app可以直接打开的链接。
    $input=array(
        "noncestr"=>"".$result->nonce_str,
        "prepayid"=>"".$result->prepay_id,//上一步请求微信服务器得到nonce_str和prepay_id参数。
        "appid"=>$APP_ID,
        "package"=>"Sign=WXPay",
        "partnerid"=>$MCH_ID,
        "timestamp"=>time(),
        );
    ksort($input);
    $sign="";
    foreach ($input as $key => $value) {
        if($value&&$key!="sign"&&$key!="key"){
            $sign.=$key."=".$value."&";
        }
    }
    $sign.="key=".$PARTNER_ID;
    $sign=strtoupper(md5($sign));
    $iOSLink=sprintf("weixin://app/%s/pay/?nonceStr=%s&package=Sign%%3DWXPay&partnerId=%s&prepayId=%s&timeStamp=%s&sign=%s&signType=SHA1",$APP_ID,$input["noncestr"],$MCH_ID,$input["prepayid"],$input["timestamp"],$sign);

    echo $iOSLink;
    //或者在Safari中打开以便测试。
    // echo "<h1><a href='${iOSLink}'>微信支付</a></h1>";
}

