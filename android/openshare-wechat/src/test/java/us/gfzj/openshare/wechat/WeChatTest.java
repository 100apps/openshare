package us.gfzj.openshare.wechat;

import static org.junit.Assert.*;
import com.tencent.mm.opensdk.modelbase.BaseReq;
import com.tencent.mm.opensdk.modelmsg.SendAuth;
import com.tencent.mm.opensdk.modelmsg.SendMessageToWX;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 36)
public class WeChatTest {
    private WeChat wechat;
    private BaseReq sent;
    private boolean installed;
    private boolean sendAccepted;
    private List<String> results;

    @Before public void setup() {
        installed = true;
        sendAccepted = true;
        results = new ArrayList<>();
        IWXAPI api = (IWXAPI) Proxy.newProxyInstance(IWXAPI.class.getClassLoader(), new Class<?>[]{IWXAPI.class},
                (proxy, method, args) -> {
                    if (method.getName().equals("isWXAppInstalled")) return installed;
                    if (method.getName().equals("sendReq")) { sent = (BaseReq) args[0]; return sendAccepted; }
                    if (method.getReturnType() == boolean.class) return true;
                    if (method.getReturnType() == int.class) return 0;
                    return null;
                });
        wechat = new WeChat(api);
    }

    @Test public void validatesAuthStateAndIgnoresReplayedCallback() {
        wechat.authorize("snsapi_userinfo", (response, error) -> results.add(error == null ? "ok" : error));
        SendAuth.Resp response = new SendAuth.Resp();
        response.state = "wrong";
        wechat.onResp(response);
        assertTrue(results.isEmpty());
        response.state = ((SendAuth.Req) sent).state;
        response.code = "server-exchange-code";
        wechat.onResp(response);
        wechat.onResp(response);
        assertEquals(List.of("ok"), results);
    }

    @Test public void preventsOverlappingRequestsAndReportsCancellation() {
        wechat.shareText("hello", 0, (response, error) -> results.add(error));
        wechat.shareText("other", 0, (response, error) -> results.add(error));
        assertEquals(List.of("busy"), results);
        SendMessageToWX.Resp response = new SendMessageToWX.Resp();
        response.transaction = "unrelated";
        wechat.onResp(response);
        assertEquals(1, results.size());
        response.transaction = sent.transaction;
        response.errCode = -2;
        wechat.onResp(response);
        assertEquals(List.of("busy", "cancelled"), results);
        wechat.cancel();
        assertEquals(2, results.size());
    }

    @Test public void handlesMissingAppAndSendFailure() {
        installed = false;
        wechat.shareText("hello", 0, (response, error) -> results.add(error));
        installed = true;
        sendAccepted = false;
        wechat.shareText("hello", 0, (response, error) -> results.add(error));
        sendAccepted = true;
        wechat.shareText("hello", 0, (response, error) -> results.add(error));
        wechat.cancel();
        assertEquals(List.of("not_installed", "send_failed", "cancelled"), results);
    }
}
