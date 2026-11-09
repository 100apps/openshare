package us.gfzj.openshare.wechat;

import android.app.Activity;
import android.content.Intent;
import com.tencent.mm.opensdk.modelmsg.SendAuth;
import java.util.Collections;
import java.util.Set;
import us.gfzj.openshare.ShareClient.*;

/** Optional bridge to the official SDK. Keep this provider/client for the application's lifetime. */
public final class WeChatProvider implements Provider {
    private final String appId;
    private WeChat wechat;
    public WeChatProvider(String appId) {
        if (appId == null || appId.trim().isEmpty()) throw new Failure(Code.invalidContent);
        this.appId = appId;
    }
    WeChatProvider(WeChat wechat) { this.appId = "test"; this.wechat = wechat; }
    @Override public String id() { return "wechat"; }
    @Override public Set<String> callbackKeys() { return Collections.singleton("sdk:wechat"); }
    private int scene(String channel) {
        switch (channel) {
            case "default": case "session": return 0;
            case "timeline": return 1;
            case "favorite": return 2;
            default: throw new Failure(Code.unsupportedChannel);
        }
    }
    @Override public Capabilities prepare(Request request) {
        if (request.isAuthorization()) {
            if (request.credential != Credential.Kind.authorizationCode) throw new Failure(Code.unsupportedCredentialKind);
            return new Capabilities(Correlation.requestBound, Outcome.credentialReceived, Outcome.cancelledByUser);
        }
        scene(request.channel);
        if (request.content.kind != Content.Kind.text && request.content.kind != Content.Kind.link) throw new Failure(Code.unsupportedContent);
        return new Capabilities(Correlation.requestBound, Outcome.sdkReportedSuccess, Outcome.cancelledByUser);
    }
    @Override public void start(Request request, Activity activity, Operation operation) {
        if (!us.gfzj.openshare.ShareClient.canPresent(activity)) { operation.fail(Code.invalidPresenter); return; }
        if (wechat == null) wechat = new WeChat(activity.getApplicationContext(), appId);
        WeChat.Callback callback = (response, error) -> {
            if (error != null) {
                Outcome outcome = "cancelled".equals(error) ? Outcome.cancelledByUser : Outcome.failed;
                Code code = "busy".equals(error) ? Code.busy : "not_installed".equals(error) ? Code.providerUnavailable :
                        "invalid_response".equals(error) ? Code.invalidResponse : "send_failed".equals(error) ? Code.dispatchRejected : Code.providerError;
                operation.complete(outcome, null, outcome == Outcome.failed ? code : null, response == null ? null : response.errCode);
            } else if (request.isAuthorization()) {
                operation.authorize(new Credential(Credential.Kind.authorizationCode, ((SendAuth.Resp) response).code));
            } else operation.complete(Outcome.sdkReportedSuccess);
        };
        // Do not call the old adapter's cancel(): the core keeps the transport callback until its real response.
        if (request.isAuthorization()) wechat.authorize(request.scope, callback);
        else if (request.content.kind == Content.Kind.text) wechat.shareText(request.content.text, scene(request.channel), callback);
        else wechat.shareLink(request.content.url.toString(), request.content.title, request.content.summary, scene(request.channel), callback);
    }
    @Override public boolean handleCallback(Intent intent) { return wechat != null && wechat.handleIntent(intent); }
}
