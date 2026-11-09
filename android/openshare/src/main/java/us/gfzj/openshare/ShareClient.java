package us.gfzj.openshare;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/** Small provider registry. All calls and provider callbacks run on the main thread. */
public final class ShareClient {
    public interface Callback { void onResult(Result result); }
    public enum Code {
        invalidContent, unsupportedOperation, unsupportedContent, unsupportedField, unsupportedChannel,
        unsupportedCredentialKind, unsupportedObservation, unsupportedCorrelation, unknownProvider,
        configurationConflict, invalidPresenter, resourceUnavailable, providerUnavailable, busy,
        dispatchRejected, invalidResponse, providerError
    }
    public enum Outcome {
        handedOff, activityCompleted, notCompleted, sdkReportedSuccess, credentialReceived,
        cancelledByUser, cancelledLocally, failed, indeterminate
    }
    public enum Correlation { requestBound, serializedOnly, unknown }
    public static final class Failure extends IllegalArgumentException {
        public final Code code;
        public Failure(Code code) { super(code.name()); this.code = code; }
    }
    public static final class Credential {
        public enum Kind { authorizationCode, identityToken, accessToken }
        public final Kind kind;
        public final String value;
        public Credential(Kind kind, String value) {
            if (kind == null || blank(value)) throw new Failure(Code.invalidResponse);
            this.kind = kind; this.value = value;
        }
        @Override public String toString() { return "Credential(" + kind + ", <redacted>)"; }
    }
    public static final class Content {
        public enum Kind { text, link, images, video, file }
        public final Kind kind;
        public final String text, title, summary, mimeType;
        public final Uri url;
        public final List<Uri> assets;
        private Content(Kind kind, String text, Uri url, String title, String summary, String mime, List<Uri> assets) {
            this.kind = kind; this.text = text; this.url = url; this.title = title; this.summary = summary;
            if (assets == null) throw new Failure(Code.invalidContent);
            mimeType = mime; this.assets = Collections.unmodifiableList(new ArrayList<>(assets));
        }
        public static Content text(String text) {
            return new Content(Kind.text, text, null, null, null, "text/plain", Collections.emptyList());
        }
        public static Content link(String url) { return link(url, null, null); }
        public static Content link(String url, String title, String summary) {
            return new Content(Kind.link, null, Uri.parse(url == null ? "" : url), title, summary,
                    "text/plain", Collections.emptyList());
        }
        public static Content images(List<Uri> assets, String mime, String caption) {
            return new Content(Kind.images, caption, null, null, null, mime, assets);
        }
        public static Content video(Uri asset, String mime, String caption) {
            return new Content(Kind.video, caption, null, null, null, mime, Collections.singletonList(asset));
        }
        public static Content file(Uri asset, String mime) {
            return new Content(Kind.file, null, null, null, null, mime, Collections.singletonList(asset));
        }
        private void validate() {
            if (kind == Kind.text && blank(text)) throw new Failure(Code.invalidContent);
            if (kind == Kind.link && (!Arrays.asList("http", "https").contains(url.getScheme() == null ? null : url.getScheme().toLowerCase(Locale.ROOT)) || blank(url.getHost()))) {
                throw new Failure(Code.invalidContent);
            }
            if (kind == Kind.images || kind == Kind.video || kind == Kind.file) {
                if (assets.isEmpty() || mimeType == null || !mimeType.matches("[^\\s/]+/[^\\s/]+") ||
                        (kind == Kind.images && !mimeType.startsWith("image/")) ||
                        (kind == Kind.video && !mimeType.startsWith("video/"))) throw new Failure(Code.invalidContent);
                for (Uri uri : assets) {
                    if (uri == null || !"content".equals(uri.getScheme()) || blank(uri.getAuthority())) {
                        throw new Failure(Code.invalidContent);
                    }
                }
            }
        }
    }
    public static final class Request {
        public enum Action { share, authorize }
        public final Action action;
        public final String provider, channel, scope;
        public final Content content;
        public final Credential.Kind credential;
        private Request(Action action, String provider, String channel, Content content, String scope, Credential.Kind credential) {
            this.action = action; this.provider = provider; this.channel = channel; this.content = content;
            this.scope = scope; this.credential = credential;
        }
        public static Request share(String provider, Content content) { return share(provider, "default", content); }
        public static Request share(String provider, String channel, Content content) {
            return new Request(Action.share, provider, channel, content, null, null);
        }
        public static Request authorize(String provider, String scope) {
            return authorize(provider, scope, Credential.Kind.authorizationCode);
        }
        public static Request authorize(String provider, String scope, Credential.Kind credential) {
            return new Request(Action.authorize, provider, null, null, scope, credential);
        }
        public boolean isAuthorization() { return action == Action.authorize; }
        public void validate() {
            if (blank(provider)) throw new Failure(Code.invalidContent);
            if (isAuthorization()) {
                if (blank(scope) || credential == null) throw new Failure(Code.invalidContent);
            } else {
                if (content == null || blank(channel)) throw new Failure(Code.invalidContent);
                content.validate();
            }
        }
    }
    public static final class Capabilities {
        public final Set<Outcome> outcomes;
        public final Correlation correlation;
        public Capabilities(Correlation correlation, Outcome... outcomes) {
            EnumSet<Outcome> set = EnumSet.noneOf(Outcome.class);
            Collections.addAll(set, outcomes);
            this.outcomes = Collections.unmodifiableSet(set); this.correlation = correlation;
        }
    }
    public interface Provider {
        String id();
        default String lane() { return id(); }
        default Set<String> callbackKeys() { return Collections.emptySet(); }
        Capabilities prepare(Request request);
        void start(Request request, Activity activity, Operation operation);
        default boolean handleCallback(Intent intent) { return false; }
    }
    public static final class Plan {
        public final Request request;
        public final Capabilities capabilities;
        private final Provider provider;
        private Plan(Request request, Capabilities capabilities, Provider provider) {
            this.request = request; this.capabilities = capabilities; this.provider = provider;
        }
    }
    public static final class Result {
        public final String provider;
        public final Outcome outcome;
        public final Correlation correlation;
        public final Credential credential;
        public final Code error;
        public final Integer providerCode;
        private Result(Plan plan, Outcome outcome, Credential credential, Code error, Integer providerCode) {
            provider = plan.request.provider; correlation = plan.capabilities.correlation;
            this.outcome = outcome; this.credential = credential; this.error = error; this.providerCode = providerCode;
        }
        @Override public String toString() { return provider + ": " + outcome; }
    }
    public static final class Operation {
        private final Plan plan;
        private Callback callback;
        private Result result;
        private boolean released;
        private final Runnable timeout = this::expire;
        private Operation(Plan plan, long timeoutMillis, Callback callback) {
            this.plan = plan; this.callback = callback;
            MAIN.postDelayed(timeout, timeoutMillis);
        }
        public Result result() { requireMain(); return result; }
        public void cancel() { requireMain(); deliver(Outcome.cancelledLocally, null, null, null); }
        void expire() { requireMain(); deliver(Outcome.indeterminate, null, null, null); }
        public void complete(Outcome outcome) { complete(outcome, null, null, null); }
        public void authorize(Credential credential) { complete(Outcome.credentialReceived, credential, null, null); }
        public void fail(Code error) { complete(Outcome.failed, null, error, null); }
        public void complete(Outcome outcome, Credential credential, Code error, Integer providerCode) {
            requireMain();
            if (released) return;
            released = true;
            String lane = plan.provider.lane();
            if (ACTIVE.get(lane) == this) ACTIVE.remove(lane);
            if (outcome == Outcome.credentialReceived && (credential == null || !plan.request.isAuthorization() ||
                    credential.kind != plan.request.credential)) { outcome = Outcome.failed; error = Code.invalidResponse; }
            if (outcome != Outcome.failed && outcome != Outcome.indeterminate && !plan.capabilities.outcomes.contains(outcome)) {
                outcome = Outcome.failed; error = Code.invalidResponse;
            }
            if (outcome == Outcome.failed && error == null) error = Code.invalidResponse;
            deliver(outcome, outcome == Outcome.credentialReceived ? credential : null, error, providerCode);
        }
        private void deliver(Outcome outcome, Credential credential, Code error, Integer providerCode) {
            if (result != null) return;
            result = new Result(plan, outcome, credential, error, providerCode);
            MAIN.removeCallbacks(timeout);
            Callback completion = callback; callback = null;
            Result value = result;
            if (completion != null) MAIN.post(() -> completion.onResult(value));
        }
    }
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static final Map<String, Operation> ACTIVE = new HashMap<>();
    private static final Map<String, WeakReference<Provider>> OWNERS = new HashMap<>();
    private final Map<String, Provider> providers = new HashMap<>();
    public ShareClient(Provider... providers) {
        requireMain();
        Set<String> keys = new HashSet<>();
        for (Provider provider : providers) {
            if (blank(provider.id()) || this.providers.put(provider.id(), provider) != null) throw new Failure(Code.configurationConflict);
            for (String key : provider.callbackKeys()) {
                Provider owner = OWNERS.containsKey(key) ? OWNERS.get(key).get() : null;
                if (!keys.add(key) || (owner != null && owner != provider)) throw new Failure(Code.configurationConflict);
            }
        }
        for (Provider provider : providers) {
            for (String key : provider.callbackKeys()) OWNERS.put(key, new WeakReference<>(provider));
        }
    }
    public Plan prepare(Request request) { return prepare(request, null, false); }
    public Plan prepare(Request request, Outcome requiredOutcome, boolean requestBound) {
        requireMain(); request.validate();
        Provider provider = providers.get(request.provider);
        if (provider == null) throw new Failure(Code.unknownProvider);
        Capabilities capabilities = provider.prepare(request);
        if (requiredOutcome != null && !capabilities.outcomes.contains(requiredOutcome)) throw new Failure(Code.unsupportedObservation);
        if (requestBound && capabilities.correlation != Correlation.requestBound) throw new Failure(Code.unsupportedCorrelation);
        return new Plan(request, capabilities, provider);
    }
    public Operation execute(Request request, Activity activity, Callback callback) {
        return execute(prepare(request), activity, 300000, callback);
    }
    public Operation execute(Plan plan, Activity activity, long timeoutMillis, Callback callback) {
        requireMain();
        if (providers.get(plan.request.provider) != plan.provider) throw new Failure(Code.configurationConflict);
        if (timeoutMillis <= 0 || callback == null) throw new Failure(Code.invalidContent);
        if (activity == null || activity.isFinishing() || activity.isDestroyed()) throw new Failure(Code.invalidPresenter);
        plan.request.validate();
        Capabilities current = plan.provider.prepare(plan.request);
        if (!current.outcomes.equals(plan.capabilities.outcomes) || current.correlation != plan.capabilities.correlation) {
            throw new Failure(Code.configurationConflict);
        }
        String lane = plan.provider.lane();
        if (lane != null && ACTIVE.containsKey(lane)) throw new Failure(Code.busy);
        Operation operation = new Operation(plan, timeoutMillis, callback);
        if (lane != null) ACTIVE.put(lane, operation);
        try { plan.provider.start(plan.request, activity, operation); }
        catch (RuntimeException exception) { operation.fail(Code.providerError); }
        return operation;
    }
    /** Forward the native callback Activity's intent to its declared provider; the provider verifies it. */
    public boolean handleCallback(String providerId, Intent intent) {
        requireMain();
        Provider provider = providers.get(providerId);
        return provider != null && intent != null && provider.handleCallback(intent);
    }
    /** Built-in UI transports require the caller's visible, focused Activity. */
    public static boolean canPresent(Activity activity) {
        requireMain();
        return activity != null && !activity.isFinishing() && !activity.isDestroyed() && activity.getWindow() != null && activity.hasWindowFocus();
    }
    private static boolean blank(String value) { return value == null || value.trim().isEmpty(); }
    private static void requireMain() {
        if (Looper.myLooper() != Looper.getMainLooper()) throw new IllegalStateException("Use ShareClient on the main thread");
    }
}
