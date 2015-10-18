//
//  ViewController.m
//  openshare
//
//  Created by LiuLogan on 15/5/20.
//  Copyright (c) 2015年 OpenShare http://openshare.gfzj.us/. All rights reserved.
//

#import "ViewController.h"
#import "UIControl+Blocks.h"
#import "OpenShareHeader.h"

@interface ViewController ()

@end

@implementation ViewController{
    NSDictionary *icons;
    UIScrollView *panel;
    UIImage *testImage,*testThumbImage;
    NSData *testGifImage,*testFile;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    //初始化测试数据
    testImage = [UIImage imageNamed:@"Default"];//[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Default@2x" ofType:@"png"]];
    testThumbImage= [UIImage imageNamed:@"logo"];//[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"logo" ofType:@"png"]];
    testGifImage= [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"logo" ofType:@"gif"]];
    testFile= [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"pdf"]];
    
    UIColor *blue=UIColorFromRGB(0x4799dd);
    //    UIColor *red=UIColorFromRGB(0xe3372b);
    
    //按钮图标。 curl http://at.alicdn.com/t/font_1433466220_572933.css|pcregrep --om-separator='\":@\"\\U0000' -o1 -o2 '.icon-(.*?):before { content: "\\(.*?)"' |while read line;do echo "@\"${line}\",";done|sed 's/-/_/g'
    
    icons=@{@"weibo":@"\U0000e600",
            @"weixin":@"\U0000e601",
            @"qq":@"\U0000e602",
            @"renren":@"\U0000e603",
            @"alipay":@"\U0000e605",
            //            @"facebook":@"\U0000e606",
            //            @"twitter":@"\U0000e604"
            };
    
    self.navigationItem.title=@"OpenShare 测试";
    self.view.backgroundColor=[UIColor whiteColor];
    
    int i=0;int buttonWidth=SCREEN_WIDTH/icons.count-20;
    if(buttonWidth>80){
        buttonWidth=80;
    }
    float fromX=SCREEN_WIDTH/2-icons.count*(buttonWidth+10)/2;
    if (fromX<0) {
        fromX=0;
    }
    for (NSString *icon in @[@"weibo",@"qq",@"weixin",@"renren",@"alipay"]/*对dictionary进行for-in，不能保证顺序*/) {
        UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
        btn.layer.cornerRadius=buttonWidth/2;
        btn.clipsToBounds=YES;
        btn.frame=CGRectMake(SCREEN_WIDTH/2-buttonWidth/2, MARGIN_TOP+10, buttonWidth, buttonWidth);
        btn.layer.borderColor=blue.CGColor;
        btn.layer.borderWidth=1;
        [btn setBackgroundImage:[self imageWithColor:[UIColor whiteColor]] forState:UIControlStateNormal];
        [btn setBackgroundImage:[self imageWithColor:blue] forState:UIControlStateSelected];
        [btn setTitleColor:blue forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        btn.titleLabel.font=[UIFont fontWithName:@"openshare" size:buttonWidth/2];
        [btn setTitle:icons[icon] forState:UIControlStateNormal];
        [self.view addSubview:btn];
        i++;
        [btn addTarget:self action:@selector(btnClicked:) forControlEvents:UIControlEventTouchUpInside];
        btn.tag=i;
    }
    //big panel uiscrollview
    float fromY=calcYFrom([self.view viewWithTag:1])+10;
    panel=[[UIScrollView alloc] initWithFrame:CGRectMake(0,fromY , SCREEN_WIDTH, SCREEN_HEIGHT-fromY)];
    [self.view addSubview:panel];
    panel.hidden=YES;
    panel.contentSize=CGSizeMake(SCREEN_WIDTH*(icons.count+1), SCREEN_HEIGHT-fromY);
    panel.pagingEnabled=YES;
    panel.scrollEnabled=NO;
    //第一屏。一个logo
    [panel addSubview:({
        UIImageView *imgView=[[UIImageView alloc] init];
        UIImage *img=[UIImage imageNamed:@"Default"];
        imgView.image=img;
        imgView.frame=CGRectMake(panel.frame.size.width/2-img.size.width/2, panel.frame.size.height/2-img.size.height/2, img.size.width, img.size.height);
        imgView;
    })];
    
    //测试分享的view
    CGRect frame=CGRectMake(0, 10, SCREEN_WIDTH-fromX*2, panel.frame.size.height);
    NSArray *views=@[[UIView new],[self sinaWeiboView:frame],[self qqView:frame],[self weixinView:frame],[self renrenView:frame],[self alipayView:frame]];
    for (int i=1; i<=icons.count; i++) {
        UIView *view=views[i];
        view.tag=100+i;
        view.frame=CGRectMake(i*SCREEN_WIDTH+fromX, view.frame.origin.y, view.frame.size.width,view.frame.size.height);
        [panel addSubview:view];
    }
    
    [UIView animateWithDuration:2 delay:0.5 usingSpringWithDamping:YES initialSpringVelocity:20 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        for (int i=1; i<=icons.count; i++) {
            [self.view viewWithTag:i].frame=CGRectMake(fromX+(i-1)*(buttonWidth+10), MARGIN_TOP+10, buttonWidth, buttonWidth);
        }
    } completion:^(BOOL finished) {
        panel.hidden=NO;
    }];
    
}
-(UIButton*)button:(NSString*)title WithCenter:(CGPoint)center{
    UIButton *btn=[UIButton buttonWithType:UIButtonTypeSystem];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn sizeToFit];
    btn.center=center;
    return btn;
}
#pragma mark 支付宝测试
-(UIView*)alipayView:(CGRect)frame{
    UIView *view=[[UIView alloc]initWithFrame:frame];
    UIButton *alipay=[self button:@"支付宝支付" WithCenter:CGPointMake(frame.size.width/2, 40)];
    [view addSubview:alipay];
    [alipay addEventHandler:^(UIButton* sender) {
        NSString *apiUrl=@"https://pay.example.com/pay.php?payType=alipay";
        if ([apiUrl hasPrefix:@"https://pay.example.com"]) {
            ULog(@"请部署pay.php，填写自家的key。否则无法测试。");
        }else{
            //网络请求不要阻塞UI，仅限Demo
            NSData *data=[NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:apiUrl]] returningResponse:nil error:nil];
            
            NSString *link=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            NSLog(@"link:%@",link);
            [OpenShare AliPay:link Success:^(NSDictionary *message) {
                ULog(@"支付宝支付成功:\n%@",message);
            } Fail:^(NSDictionary *message, NSError *error) {
                ULog(@"支付宝支付失败:\n%@\n%@",message,error);
            }];
        }
        
    } forControlEvents:UIControlEventTouchUpInside];
    
    
    return view;
}

#pragma mark 新浪微博测试
-(UIView*)sinaWeiboView:(CGRect)frame{
    UIView *ret=[[UIView alloc] initWithFrame:frame];
    UIButton *auth=[self button:@"登录" WithCenter:CGPointMake(frame.size.width/2, 40)];
    [ret addSubview:auth];
    [auth addEventHandler:^(id sender) {
        [OpenShare WeiboAuth:@"all" redirectURI:@"http://openshare.gfzj.us/" Success:^(NSDictionary *message) {
            ULog(@"微博登录成功:\n%@",message);
        } Fail:^(NSDictionary *message, NSError *error) {
            ULog(@"微博登录失败:\n%@\n%@",message,error);
        }];
    } forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *textShare=[self button:@"分享纯文本" WithCenter:CGPointMake(auth.center.x, calcYFrom(auth)+40)];
    [ret addSubview:textShare];
    textShare.tag=1001;
    [textShare addTarget:self action:@selector(weiboViewHandler:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *imgShare=[self button:@"分享图片" WithCenter:CGPointMake(auth.center.x, calcYFrom(textShare)+40)];
    [ret addSubview:imgShare];
    imgShare.tag=1002;
    [imgShare addTarget:self action:@selector(weiboViewHandler:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *newsShare=[self button:@"分享新闻" WithCenter:CGPointMake(auth.center.x, calcYFrom(imgShare)+40)];
    [ret addSubview:newsShare];
    newsShare.tag=1003;
    [newsShare addTarget:self action:@selector(weiboViewHandler:) forControlEvents:UIControlEventTouchUpInside];
    
    return ret;
}
-(void)weiboViewHandler:(UIButton*)btn{
    OSMessage *message=[[OSMessage alloc]init];
    message.title=@"hello openshare (message.title)";
    if (btn.tag>=1002) {
        message.image=testImage;
    }
    if (btn.tag==1003) {
        message.link=@"http://openshare.gfzj.us/";
    }
    [OpenShare shareToWeibo:message Success:^(OSMessage *message) {
        ULog(@"分享到sina微博成功:\%@",message);
    } Fail:^(OSMessage *message, NSError *error) {
        ULog(@"分享到sina微博失败:\%@\n%@",message,error);
    }];
}
#pragma mark QQ分享／登录API使用
-(UIView*)qqView:(CGRect)frame{
    UIView *ret=[[UIView alloc] initWithFrame:frame];
    UISegmentedControl *seg=[[UISegmentedControl alloc] initWithItems:@[@"登录",@"QQ好友",@"QQ空间",@"收藏",@"数据线"]];
    seg.tag=2002;
    seg.center=CGPointMake(frame.size.width/2, 20);
    seg.selectedSegmentIndex=0;
    [ret addSubview:seg];
    
    UIView *loginView=[[UIView alloc] initWithFrame:CGRectMake(0, 40, frame.size.width, frame.size.height-40)];
    loginView.backgroundColor=[UIColor whiteColor];
    UIButton *auth=[self button:@"QQ登录" WithCenter:CGPointMake(frame.size.width/2, 40)];
    [loginView addSubview:auth];
    [auth addEventHandler:^(id sender) {
        [OpenShare QQAuth:@"get_user_info" Success:^(NSDictionary *message) {
            ULog(@"QQ登录成功\n%@",message);
        } Fail:^(NSDictionary *message, NSError *error) {
            ULog(@"QQ登录失败\n%@\n%@",error,message);
        }];
    } forControlEvents:UIControlEventTouchUpInside];
    UIButton *chat=[self button:@"和我聊天" WithCenter:CGPointMake(frame.size.width/2, calcYFrom(auth)+40)];
    [loginView addSubview:chat];
    [chat addEventHandler:^(id sender) {
        [OpenShare chatWithQQNumber:@"393475141"];
    } forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *chatGroup=[self button:@"指定群聊天(必须是群成员)" WithCenter:CGPointMake(frame.size.width/2, calcYFrom(chat)+40)];
    [loginView addSubview:chatGroup];
    [chatGroup addEventHandler:^(id sender) {
        [OpenShare chatInQQGroup:@"60623498"];
    } forControlEvents:UIControlEventTouchUpInside];
    
    UIView *shareView=[[UIView alloc] initWithFrame:loginView.frame];
    shareView.backgroundColor=[UIColor whiteColor];
    OSMessage *message=[[OSMessage alloc] init];
    message.title=@"hello OpenShare(title)";
    NSArray *titles=@[@"分享文本消息",@"分享图片消息",@"分享新闻消息",@"分享音频消息",@"分享视频消息"];
    for (int i=0; i<titles.count; i++) {
        UIButton *btn=[self button:titles[i] WithCenter:CGPointMake(frame.size.width/2, 20+40*i)];
        [shareView addSubview:btn];
        [btn addTarget:self action:@selector(qqViewHandler:) forControlEvents:UIControlEventTouchUpInside];
        btn.tag=i+1;
    }
    [ret addSubview:shareView];
    [ret addSubview:loginView];
    
    [seg addEventHandler:^(id sender) {
        UISegmentedControl *seg=sender;
        if (seg.selectedSegmentIndex==0) {
            [ret bringSubviewToFront:loginView];
        }else{
            [ret bringSubviewToFront:shareView];
        }
    } forControlEvents:UIControlEventValueChanged];
    
    return ret;
}
-(void)qqViewHandler:(UIButton*)btn{
    UISegmentedControl *seg=(UISegmentedControl*)[panel viewWithTag:2002];
    OSMessage *msg=[[OSMessage alloc] init];
    msg.title=@"Hello OpenShare (msg.title)";
    if (btn.tag>=2) {
        msg.image=testImage;
        msg.thumbnail=testThumbImage;
        msg.desc=@"这里写的是msg.description";
    }
    if(btn.tag==3){
        msg.link=@"http://sports.qq.com/a/20120510/000650.htm";
    }else if(btn.tag==4){
        msg.link=@"http://wfmusic.3g.qq.com/s?g_f=0&fr=&aid=mu_detail&id=2511915";
        msg.multimediaType=OSMultimediaTypeAudio;
    }else if(btn.tag==5){
        msg.link=@"http://v.youku.com/v_show/id_XOTU2MzA0NzY4.html";
        msg.multimediaType=OSMultimediaTypeVideo;
    }
    switch (seg.selectedSegmentIndex) {
        case 1:
        {
            [OpenShare shareToQQFriends:msg Success:^(OSMessage *message) {
                ULog(@"分享到QQ好友成功:%@",msg);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"分享到QQ好友失败:%@\n%@",msg,error);
            }];
        }
            break;
            
        case 2:
        {
            [OpenShare shareToQQZone:msg Success:^(OSMessage *message) {
                ULog(@"分享到QQ空间成功:%@",msg);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"分享到QQ空间失败:%@\n%@",msg,error);
            }];
        }
            break;
        case 3:
        {
            [OpenShare shareToQQFavorites:msg Success:^(OSMessage *message) {
                ULog(@"分享到QQ收藏成功:%@",msg);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"分享到QQ收藏失败:%@\n%@",msg,error);
            }];
        }
            break;
            
        case 4:
        {
            [OpenShare shareToQQDataline:msg Success:^(OSMessage *message) {
                ULog(@"分享到QQ数据线成功:%@",msg);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"分享到QQ数据线失败:%@\n%@",msg,error);
            }];
        }
            break;
        default:
            break;
    }
    
}
#pragma mark 微信分享相关
-(UIView*)weixinView:(CGRect)frame{
    UIView *ret=[[UIView alloc] initWithFrame:frame];
    UISegmentedControl *seg=[[UISegmentedControl alloc] initWithItems:@[@"登录",@"会话",@"朋友圈",@"收藏"]];
    seg.selectedSegmentIndex=0;
    seg.tag=3003;
    seg.center=CGPointMake(frame.size.width/2, 20);
    [ret addSubview:seg];
    
    NSArray *titles=@[@"发送Text消息",@"发送Photo消息",@"发送Link消息",@"发送Music消息",@"发送Video消息",@"发送App消息",@"发送非gif表情",@"发送gif表情",@"发送文件消息"];
    NSArray *fromX=@[@(frame.size.width/4),@(frame.size.width*3/4)];
    int fromY=calcYFrom(seg)+ 40;
    for (int i=0; i<titles.count;i++ ) {
        UIButton *btn=[self button:[titles[i] stringByAppendingFormat:@"%d",i+1] WithCenter:CGPointMake([fromX[i%2] intValue], fromY)];
        [ret addSubview:btn];
        [btn addTarget:self action:@selector(weixinViewHandler:) forControlEvents:UIControlEventTouchUpInside];
        btn.tag=30001+i;
        if (i%2) {
            fromY+=40;
        }
    }
    
    UIView *loginView=[[UIView alloc]initWithFrame:CGRectMake(0, calcYFrom(seg)+30, frame.size.width, frame.size.height)];
    loginView.backgroundColor=[UIColor whiteColor];
    UIButton *loginBtn=[self button:@"登录(appid需要通过认证,300/年)" WithCenter:CGPointMake(loginView.frame.size.width/2,0)];
    loginBtn.tag=30000;
    [loginView addSubview:loginBtn];
    [loginBtn addTarget:self action:@selector(weixinViewHandler:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *payBtn=[self button:@"微信支付（需要在pay.php中设置支付参数）" WithCenter:CGPointMake(loginView.frame.size.width/2,40)];
    payBtn.tag=40001;
    [loginView addSubview:payBtn];
    [payBtn addTarget:self action:@selector(weixinViewHandler:) forControlEvents:UIControlEventTouchUpInside];
    
    
    [ret addSubview:loginView];
    [seg addEventHandler:^(UISegmentedControl *seg) {
        loginView.hidden=seg.selectedSegmentIndex!=0;
    } forControlEvents:UIControlEventValueChanged];
    return ret;
}
-(void)weixinViewHandler:(UIButton*)btn{
    OSMessage *msg=[[OSMessage alloc]init];
    msg.title=@"Hello msg.title";
    if (btn.tag==30000) {
        //login scope: @"snsapi_message,snsapi_userinfo,snsapi_friend,snsapi_contact";//,post_timeline,sns
        [OpenShare WeixinAuth:@"snsapi_userinfo" Success:^(NSDictionary *message) {
            ULog(@"微信登录成功:\n%@",message);
        } Fail:^(NSDictionary *message, NSError *error) {
            ULog(@"微信登录失败:\n%@\n%@",message,error);
        }];
    }else if(btn.tag==40001){
        NSString *apiUrl=@"https://pay.example.com/pay.php?payType=weixin";
        if ([apiUrl hasPrefix:@"https://pay.example.com"]) {
            ULog(@"请部署pay.php，填写自家的key。");
        }else{
            //网络请求不要阻塞UI，仅限Demo
            NSData *data=[NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:apiUrl]] returningResponse:nil error:nil];
            NSString *link=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            [OpenShare WeixinPay:link Success:^(NSDictionary *message) {
                ULog(@"微信支付成功:\n%@",message);
            } Fail:^(NSDictionary *message, NSError *error) {
                ULog(@"微信支付失败:\n%@\n%@",message,error);
            }];
        }
        
    }
    if (btn.tag>30001) {
        msg.desc=@"这里是msg.desc";
    }
    
    if (btn.tag==30002) {
        //图片
        msg.image=testImage;
        msg.thumbnail=testThumbImage;
    }else if (btn.tag==30003) {
        //link
        msg.link=@"http://tech.qq.com/zt2012/tmtdecode/252.htm";
        msg.image=testThumbImage;//新闻类型的职能传缩略图就够了。
    }else if (btn.tag==30004) {
        //Music
        msg.mediaDataUrl=@"http://stream20.qqmusic.qq.com/32464723.mp3";
        msg.link=@"http://tech.qq.com/zt2012/tmtdecode/252.htm";
        msg.thumbnail=testThumbImage;
        msg.multimediaType=OSMultimediaTypeAudio;
    }
    else if (btn.tag==30005) {
        //video
        msg.link=@"http://v.youku.com/v_show/id_XNTUxNDY1NDY4.html";
        msg.thumbnail=testThumbImage;
        msg.multimediaType=OSMultimediaTypeVideo;
    }
    else if (btn.tag==30006) {
        //app
        msg.extInfo=@"app自己的扩展消息，当从微信打开app的时候，会传给app";
        msg.link=@"http://www.baidu.com/";//分享到朋友圈以后，微信就不会调用app了，跟news类型分享到朋友圈一样。
        msg.image=testImage;
        msg.thumbnail=testThumbImage;
        msg.multimediaType=OSMultimediaTypeApp;
    }
    else if (btn.tag==30007) {
        //非gif表情／同图片。
        msg.image=testImage;
        msg.thumbnail=testThumbImage;
    }else if (btn.tag==30008) {
        //gif表情／同图片，只是格式是gif。
        msg.file =testGifImage;
        msg.thumbnail=testThumbImage;
    }else if (btn.tag==30009) {
        //file
        msg.file=testFile;
        msg.thumbnail=testThumbImage;
        msg.title=@"test.pdf";//添加到收藏的时候，微信会根据文件名打开。fileExt信息丢失。微信的bug
        msg.fileExt=@"pdf";
        msg.multimediaType=OSMultimediaTypeFile;
    }
    
    
    switch ([(UISegmentedControl*)[panel viewWithTag:3003] selectedSegmentIndex]) {
        case 1:
            [OpenShare shareToWeixinSession:msg Success:^(OSMessage *message) {
                ULog(@"微信分享到会话成功：\n%@",message);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"微信分享到会话失败：\n%@\n%@",error,message);
            }];
            break;
        case 2:
            [OpenShare shareToWeixinTimeline:msg Success:^(OSMessage *message) {
                ULog(@"微信分享到朋友圈成功：\n%@",message);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"微信分享到朋友圈失败：\n%@\n%@",error,message);
            }];
            break;
        case 3:
            [OpenShare shareToWeixinFavorite:msg Success:^(OSMessage *message) {
                ULog(@"微信分享到收藏成功：\n%@",message);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"微信分享到收藏失败：\n%@\n%@",error,message);
            }];
            break;
            
        default:
            break;
    }
}
#pragma mark 人人
-(UIView*)renrenView:(CGRect)frame{
    UIView *ret=[[UIView alloc] initWithFrame:frame];
    UISegmentedControl *seg=[[UISegmentedControl alloc] initWithItems:@[@"聊天",@"新鲜事"]];
    seg.tag=3004;
    seg.selectedSegmentIndex=0;
    seg.center=CGPointMake(frame.size.width/2, 20);
    [ret addSubview:seg];
    NSArray *titles=@[@"文本",@"图片",@"图文",@"语音",@"视频"];
    for (int i=0; i<titles.count; i++) {
        UIButton *btn=[self button:titles[i] WithCenter:CGPointMake(frame.size.width/2,calcYFrom(seg)+ 40+i*40)];
        [ret addSubview:btn];
        btn.tag=40001+i;
        [btn addTarget:self action:@selector(renrenViewHandler:) forControlEvents:UIControlEventTouchUpInside];
    }
    return ret;
}
-(void)renrenViewHandler:(UIButton*)btn{
    OSMessage *msg=[[OSMessage alloc]init];
    msg.title=@"Renren msg.title. hello openshare";
    if (btn.tag==40001) {
        msg.link=@"http://www.baidu.com/";
        msg.desc=@"this is msg.description";
    }else if (btn.tag==40002) {
        msg.image=testImage;
        msg.thumbnail=testThumbImage;
    }else if (btn.tag==40003) {
        msg.image=testImage;
        msg.link=@"http://www.baidu.com/";
        msg.desc=@"this is msg.description";
    }else if (btn.tag==40004) {
        msg.multimediaType=OSMultimediaTypeAudio;
        msg.thumbnail=testThumbImage;
        msg.link=@"http://papa.me/post/zG7t3fD0";
        msg.desc=@"this is msg.description";
    }else if (btn.tag==40005) {
        msg.multimediaType=OSMultimediaTypeVideo;
        msg.thumbnail=testThumbImage;
        msg.link=@"http://v.youku.com/v_show/id_XNTUxNDY1NDY4.html";
        msg.desc=@"this is msg.description";
    }
    switch ([(UISegmentedControl*)[panel viewWithTag:3004] selectedSegmentIndex]) {
        case 0:
            [OpenShare shareToRenrenSession:msg Success:^(OSMessage *message) {
                ULog(@"人人分享到聊天成功：\n%@",message);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"人人分享到聊天失败：\n%@\n%@",error,message);
            }];
            break;
        case 1:
            [OpenShare shareToRenrenTimeline:msg Success:^(OSMessage *message) {
                ULog(@"人人分享到新鲜事成功：\n%@",message);
            } Fail:^(OSMessage *message, NSError *error) {
                ULog(@"人人分享到新鲜事失败：\n%@\n%@",error,message);
            }];
            break;
            
        default:
            break;
    }
}
-(void)btnClicked:(UIButton *)btn{
    btn.selected=!btn.selected;
    for (int i=1; i<=icons.count; i++) {
        if (i!=btn.tag) {
            [(UIButton*)[self.view viewWithTag:i] setSelected:NO];
        }
    }
    [panel setContentOffset:CGPointMake(btn.selected? btn.tag*SCREEN_WIDTH:0, 0) animated:YES];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

#pragma mark 测试代码UI相关
- (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}
@end