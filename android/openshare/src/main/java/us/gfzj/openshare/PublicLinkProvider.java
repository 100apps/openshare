package us.gfzj.openshare;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import us.gfzj.openshare.ShareClient.*;

/** Official HTTPS entry points; opening a browser/app is only handoff. */
public final class PublicLinkProvider implements Provider {
    public enum Service { telegram, whatsapp }
    private final Service service;
    public PublicLinkProvider(Service service) { this.service = service; }
    @Override public String id() { return service.name(); }
    @Override public String lane() { return null; }
    public Uri link(Request request) {
        request.validate();
        if (request.isAuthorization()) throw new Failure(Code.unsupportedOperation);
        if (!"default".equals(request.channel)) throw new Failure(Code.unsupportedChannel);
        Content content = request.content;
        String name, value;
        if (content.kind == Content.Kind.link) {
            if (content.title != null || content.summary != null) throw new Failure(Code.unsupportedField);
            name = service == Service.telegram ? "url" : "text"; value = content.url.toString();
        } else if (service == Service.whatsapp && content.kind == Content.Kind.text) {
            name = "text"; value = content.text;
        } else throw new Failure(Code.unsupportedContent);
        return Uri.parse(service == Service.telegram ? "https://t.me/share/url" : "https://wa.me/")
                .buildUpon().appendQueryParameter(name, value).build();
    }
    @Override public Capabilities prepare(Request request) {
        link(request); return new Capabilities(Correlation.requestBound, Outcome.handedOff);
    }
    @Override public void start(Request request, Activity activity, Operation operation) {
        if (!us.gfzj.openshare.ShareClient.canPresent(activity)) { operation.fail(Code.invalidPresenter); return; }
        try {
            activity.startActivity(new Intent(Intent.ACTION_VIEW, link(request)));
            operation.complete(Outcome.handedOff);
        } catch (ActivityNotFoundException | SecurityException exception) { operation.fail(Code.dispatchRejected); }
    }
}
