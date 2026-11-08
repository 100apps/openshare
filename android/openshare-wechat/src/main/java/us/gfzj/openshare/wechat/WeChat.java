package us.gfzj.openshare.wechat;

import android.content.Context;
import android.content.Intent;
import android.os.Looper;
import com.tencent.mm.opensdk.modelbase.BaseReq;
import com.tencent.mm.opensdk.modelbase.BaseResp;
import com.tencent.mm.opensdk.modelmsg.SendAuth;
import com.tencent.mm.opensdk.modelmsg.SendMessageToWX;
import com.tencent.mm.opensdk.modelmsg.WXMediaMessage;
import com.tencent.mm.opensdk.modelmsg.WXTextObject;
import com.tencent.mm.opensdk.modelmsg.WXWebpageObject;
import com.tencent.mm.opensdk.openapi.IWXAPI;
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler;
import com.tencent.mm.opensdk.openapi.WXAPIFactory;
import java.util.UUID;

/** Keep one instance per app. All calls, including callbacks, belong on the main thread. */
public final class WeChat implements IWXAPIEventHandler {
    public interface Callback { void onResult(BaseResp response, String error); }
    private final IWXAPI api;
    private Callback pending;
    private String transaction;
    private String authState;
    private int responseType;

    public WeChat(Context context, String appId) {
        this(WXAPIFactory.createWXAPI(context.getApplicationContext(), appId, true));
        if (appId == null || appId.isEmpty() || !api.registerApp(appId)) {
            throw new IllegalArgumentException("WeChat app registration failed");
        }
    }

    WeChat(IWXAPI api) { this.api = api; }

    public boolean isInstalled() { return api.isWXAppInstalled(); }

    public void shareText(String text, int scene, Callback callback) {
        if (text == null || text.trim().isEmpty()) throw new IllegalArgumentException("Text is required");
        WXMediaMessage message = new WXMediaMessage(new WXTextObject(text));
        message.description = text;
        share(message, scene, callback);
    }

    public void shareLink(String url, String title, String description, int scene, Callback callback) {
        android.net.Uri uri = android.net.Uri.parse(url == null ? "" : url);
        if (!("https".equals(uri.getScheme()) || "http".equals(uri.getScheme())) || uri.getHost() == null) {
            throw new IllegalArgumentException("An HTTP(S) URL is required");
        }
        WXMediaMessage message = new WXMediaMessage(new WXWebpageObject(url));
        message.title = title;
        message.description = description;
        share(message, scene, callback);
    }

    /** Supports the official SDK's image, audio, video, file and mini-program objects. */
    public void share(WXMediaMessage message, int scene, Callback callback) {
        if (message == null || scene < 0 || scene > 2) throw new IllegalArgumentException("Invalid share request");
        SendMessageToWX.Req request = new SendMessageToWX.Req();
        request.message = message;
        request.scene = scene;
        send(request, null, callback);
    }

    /** Returns an authorization code. Exchange it on your server; never embed an app secret. */
    public void authorize(String scope, Callback callback) {
        if (scope == null || scope.isEmpty()) throw new IllegalArgumentException("Scope is required");
        SendAuth.Req request = new SendAuth.Req();
        request.scope = scope;
        request.state = UUID.randomUUID().toString();
        send(request, request.state, callback);
    }

    /** For server-signed PayReq and other official SDK requests. */
    public void send(BaseReq request, Callback callback) {
        if (request instanceof SendAuth.Req) throw new IllegalArgumentException("Use authorize for OAuth state validation");
        send(request, null, callback);
    }

    private void send(BaseReq request, String state, Callback callback) {
        requireMainThread();
        if (request == null || callback == null) throw new IllegalArgumentException("Request and callback are required");
        if (pending != null) { callback.onResult(null, "busy"); return; }
        if (!api.isWXAppInstalled()) { callback.onResult(null, "not_installed"); return; }
        request.transaction = UUID.randomUUID().toString();
        if (!request.checkArgs()) { callback.onResult(null, "invalid_request"); return; }
        pending = callback;
        transaction = request.transaction;
        authState = state;
        responseType = request.getType();
        try {
            if (!api.sendReq(request)) complete(null, "send_failed");
        } catch (RuntimeException exception) {
            complete(null, "send_failed");
        }
    }

    public boolean handleIntent(Intent intent) {
        requireMainThread();
        return intent != null && api.handleIntent(intent, this);
    }

    /** Call after an abandoned request to release callbacks; no synthetic success is reported. */
    public void cancel() { requireMainThread(); complete(null, "cancelled"); }

    @Override public void onReq(BaseReq request) { /* Unsolicited incoming requests are not handled. */ }

    @Override public void onResp(BaseResp response) {
        requireMainThread();
        if (pending == null || response == null || response.getType() != responseType) return;
        if (response instanceof SendAuth.Resp) {
            if (!authState.equals(((SendAuth.Resp) response).state)) return;
        } else if (!transaction.equals(response.transaction)) return;
        complete(response, response.errCode == BaseResp.ErrCode.ERR_OK ? null :
                response.errCode == BaseResp.ErrCode.ERR_USER_CANCEL ? "cancelled" : "wechat_error");
    }

    private void complete(BaseResp response, String error) {
        Callback callback = pending;
        pending = null;
        transaction = null;
        authState = null;
        if (callback != null) callback.onResult(response, error);
    }

    private static void requireMainThread() {
        if (Looper.myLooper() != Looper.getMainLooper()) throw new IllegalStateException("Use WeChat on the main thread");
    }
}
