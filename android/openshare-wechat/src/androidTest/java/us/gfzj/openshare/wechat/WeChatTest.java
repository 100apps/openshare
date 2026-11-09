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
import org.junit.Rule;
import androidx.test.rule.ActivityTestRule;
import org.junit.Test;
import org.junit.runner.RunWith;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.annotation.UiThreadTest;
import us.gfzj.openshare.ShareClient;
import android.app.Activity;

@RunWith(AndroidJUnit4.class)
public class WeChatTest {
    @Rule public ActivityTestRule<TestActivity> activityRule = new ActivityTestRule<>(TestActivity.class);
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

    @Test @UiThreadTest public void validatesAuthStateAndIgnoresReplayedCallback() {
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

    @Test @UiThreadTest public void preventsOverlappingRequestsAndReportsCancellation() {
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

    @Test @UiThreadTest public void handlesMissingAppAndSendFailure() {
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

    @Test @UiThreadTest public void rejectsEmptySuccessfulAuthorizationCode() {
        wechat.authorize("snsapi_userinfo", (response, error) -> results.add(error));
        SendAuth.Resp response = new SendAuth.Resp();
        response.state = ((SendAuth.Req) sent).state;
        wechat.onResp(response);
        assertEquals(List.of("invalid_response"), results);
    }

    @Test @UiThreadTest public void coreProviderRetainsTransportAndReturnsTypedCredentials() {
        WeChatProvider provider = new WeChatProvider(wechat);
        ShareClient client = new ShareClient(provider);
        ShareClient.Request share = ShareClient.Request.share("wechat", "session", ShareClient.Content.text("hello"));
        assertEquals(ShareClient.Correlation.requestBound, client.prepare(share).capabilities.correlation);
        Activity activity = activityRule.getActivity(); // Real focused presenter; only the SDK transport is replaced.
        ShareClient.Operation old = client.execute(share, activity, ignored -> {});
        old.cancel();
        try { new ShareClient(provider).execute(share, activity, ignored -> {}); fail("Expected busy"); }
        catch (ShareClient.Failure error) { assertEquals(ShareClient.Code.busy, error.code); }
        SendMessageToWX.Resp shared = new SendMessageToWX.Resp(); shared.transaction = sent.transaction;
        wechat.onResp(shared);
        assertEquals(ShareClient.Outcome.cancelledLocally, old.result().outcome);
        ShareClient.Operation auth = client.execute(ShareClient.Request.authorize("wechat", "profile"), activity, ignored -> {});
        assertNull(auth.result());
        SendAuth.Resp response = new SendAuth.Resp(); response.state = "wrong"; response.code = "code";
        wechat.onResp(response); assertNull(auth.result());
        response.state = ((SendAuth.Req) sent).state; wechat.onResp(response); wechat.onResp(response);
        assertEquals(ShareClient.Outcome.credentialReceived, auth.result().outcome);
        assertEquals(ShareClient.Credential.Kind.authorizationCode, auth.result().credential.kind);
        assertEquals("code", auth.result().credential.value);
        try { client.prepare(ShareClient.Request.authorize("wechat", "profile", ShareClient.Credential.Kind.accessToken)); fail("Expected unsupported kind"); }
        catch (ShareClient.Failure error) { assertEquals(ShareClient.Code.unsupportedCredentialKind, error.code); }
    }
}
