package us.gfzj.openshare;

import static org.junit.Assert.*;
import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import android.os.Looper;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import static org.robolectric.Shadows.shadowOf;
import us.gfzj.openshare.ShareClient.*;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {23, 30, 36})
public class ShareClientTest {
    private static final class Fake implements Provider {
        final String id;
        Set<String> keys = Collections.emptySet();
        Correlation correlation = Correlation.requestBound;
        Operation pending;
        int starts;
        Fake() { this("fake-" + UUID.randomUUID()); }
        Fake(String id) { this.id = id; }
        @Override public String id() { return id; }
        @Override public Set<String> callbackKeys() { return keys; }
        @Override public Capabilities prepare(Request request) {
            return new Capabilities(correlation, request.isAuthorization() ? Outcome.credentialReceived : Outcome.handedOff);
        }
        @Override public void start(Request request, Activity activity, Operation operation) { starts++; pending = operation; }
    }
    private Activity activity() { return Robolectric.buildActivity(Activity.class).setup().get(); }
    private void error(Code expected, Runnable action) {
        assertEquals(expected, assertThrows(Failure.class, action::run).code);
    }
    @Test public void sharedContractFixturesAndEncoding() throws Exception {
        PublicLinkProvider telegram = new PublicLinkProvider(PublicLinkProvider.Service.telegram);
        PublicLinkProvider whatsapp = new PublicLinkProvider(PublicLinkProvider.Service.whatsapp);
        ShareClient client = new ShareClient(new SystemShareProvider(), telegram, whatsapp);
        String json;
        try (InputStream input = getClass().getClassLoader().getResourceAsStream("contracts.json")) {
            assertNotNull(input); json = new String(input.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
        }
        JSONArray cases = new JSONArray(json);
        for (int i = 0; i < cases.length(); i++) {
            JSONObject c = cases.getJSONObject(i);
            String provider = c.getString("provider");
            Content content = "link".equals(c.optString("kind")) ?
                    Content.link(c.getString("url"), c.optString("title", null), c.optString("summary", null)) : Content.text(c.optString("text", null));
            Request request = c.optBoolean("auth") ? Request.authorize(provider, c.getString("scope")) :
                    Request.share(provider, c.optString("channel", "default"), content);
            if (c.has("error")) error(Code.valueOf(c.getString("error")), () -> client.prepare(request));
            else {
                assertTrue(c.getString("name"), client.prepare(request).capabilities.outcomes.contains(Outcome.valueOf(c.getString("androidOutcome"))));
                if (!"system".equals(provider)) {
                    Uri url = ("telegram".equals(provider) ? telegram : whatsapp).link(request);
                    assertEquals("link".equals(c.optString("kind")) ? c.getString("url") : c.getString("text"),
                            url.getQueryParameter("telegram".equals(provider) ? "url" : "text"));
                }
            }
        }
    }
    @Test public void cancellationAndTimeoutRetainLaneUntilRealResponse() {
        for (boolean timeout : new boolean[]{false, true}) {
            Fake provider = new Fake(); ShareClient first = new ShareClient(provider), second = new ShareClient(provider);
            Request request = Request.share(provider.id, Content.text("hello"));
            List<Result> results = new ArrayList<>();
            Activity activity = activity();
            Operation old = first.execute(request, activity, results::add);
            if (timeout) old.expire(); else old.cancel();
            assertEquals(timeout ? Outcome.indeterminate : Outcome.cancelledLocally, old.result().outcome);
            error(Code.busy, () -> second.execute(request, activity, results::add));
            old.complete(Outcome.handedOff);
            Operation next = second.execute(request, activity, results::add);
            old.fail(Code.providerError);
            assertNull(next.result());
            next.complete(Outcome.handedOff);
            shadowOf(Looper.getMainLooper()).idle();
            assertEquals(2, results.size());
            assertEquals(old.result(), results.get(0));
        }
    }
    @Test public void credentialTypesAndSensitiveDiagnostics() {
        Fake provider = new Fake(); ShareClient client = new ShareClient(provider);
        Request request = Request.authorize(provider.id, "profile");
        Operation wrong = client.execute(request, activity(), ignored -> {});
        wrong.authorize(new Credential(Credential.Kind.accessToken, "private-token"));
        assertEquals(Code.invalidResponse, wrong.result().error);
        Operation valid = client.execute(request, activity(), ignored -> {});
        Credential credential = new Credential(Credential.Kind.authorizationCode, "private-code");
        valid.authorize(credential);
        assertEquals(Outcome.credentialReceived, valid.result().outcome);
        assertSame(credential, valid.result().credential);
        assertFalse(credential.toString().contains("private-code"));
        assertFalse(valid.result().toString().contains("private-code"));
        error(Code.invalidResponse, () -> new Credential(Credential.Kind.identityToken, " "));
    }
    @Test public void registryIsAtomicAndCallbacksHaveOneOwner() {
        Fake one = new Fake(), two = new Fake();
        one.keys = Collections.singleton("scheme:" + UUID.randomUUID()); two.keys = one.keys;
        error(Code.configurationConflict, () -> new ShareClient(one, two));
        ShareClient owner = new ShareClient(one);
        assertNotNull(owner.prepare(Request.share(one.id, Content.text("a"))));
        error(Code.configurationConflict, () -> new ShareClient(two));
        assertNotNull(new ShareClient(one));
        error(Code.configurationConflict, () -> new ShareClient(one, one));
        assertFalse(owner.handleCallback("unknown", new Intent()));
    }
    @Test public void plansCannotChangeOwnerOrStrengthenGuarantees() {
        Fake provider = new Fake(); ShareClient client = new ShareClient(provider);
        Request request = Request.share(provider.id, Content.text("hello"));
        error(Code.unsupportedObservation, () -> client.prepare(request, Outcome.sdkReportedSuccess, false));
        provider.correlation = Correlation.serializedOnly;
        error(Code.unsupportedCorrelation, () -> client.prepare(request, null, true));
        Plan plan = client.prepare(request);
        ShareClient foreign = new ShareClient(new Fake(provider.id));
        error(Code.configurationConflict, () -> foreign.execute(plan, activity(), 100, ignored -> {}));
        provider.correlation = Correlation.requestBound;
        error(Code.configurationConflict, () -> client.execute(plan, activity(), 100, ignored -> {}));
        assertEquals(0, provider.starts);
    }
    @Test public void invisiblePresenterFailsBeforeDispatch() {
        ShareClient client = new ShareClient(new SystemShareProvider());
        Activity hidden = Robolectric.buildActivity(Activity.class).create().get();
        assertFalse(hidden.hasWindowFocus());
        Operation op = client.execute(Request.share("system", Content.text("hello")), hidden, ignored -> {});
        assertEquals(Code.invalidPresenter, op.result().error);
        assertNull(shadowOf(hidden).getNextStartedActivity());
    }
    @Test public void attachmentsAreImmutableAndGrantedReadOnly() {
        List<Uri> source = new ArrayList<>(); source.add(Uri.parse("content://test/one"));
        source.add(Uri.parse("content://test/two"));
        Content content = Content.images(source, "image/png", "caption"); source.clear();
        Request request = Request.share("system", content);
        new ShareClient(new SystemShareProvider()).prepare(request);
        Intent intent = new SystemShareProvider().createIntent(content);
        assertEquals(Intent.ACTION_SEND_MULTIPLE, intent.getAction());
        assertEquals(2, intent.getClipData().getItemCount());
        assertEquals("caption", intent.getStringExtra(Intent.EXTRA_TEXT));
        assertTrue((intent.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION) != 0);
        assertEquals(0, intent.getFlags() & Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        assertThrows(UnsupportedOperationException.class, () -> content.assets.clear());
        error(Code.invalidContent, () -> new ShareClient(new SystemShareProvider()).prepare(
                Request.share("system", Content.file(Uri.parse("file:///private/data"), "application/pdf"))));
        error(Code.invalidContent, () -> new ShareClient(new SystemShareProvider()).prepare(
                Request.share("system", Content.images(Collections.emptyList(), "image/png", null))));
    }
}
