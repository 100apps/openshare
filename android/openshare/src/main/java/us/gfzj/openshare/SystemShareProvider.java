package us.gfzj.openshare;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Intent;
import android.content.res.AssetFileDescriptor;
import android.net.Uri;
import java.io.IOException;
import java.util.ArrayList;
import us.gfzj.openshare.ShareClient.*;

/** Uses only system APIs. The caller must retain files after handoff. */
public final class SystemShareProvider implements Provider {
    @Override public String id() { return "system"; }
    @Override public String lane() { return null; }
    @Override public Capabilities prepare(Request request) {
        if (request.isAuthorization()) throw new Failure(Code.unsupportedOperation);
        if (!"default".equals(request.channel)) throw new Failure(Code.unsupportedChannel);
        return new Capabilities(Correlation.requestBound, Outcome.handedOff);
    }
    public Intent createIntent(Content content) {
        Intent intent = new Intent(content.assets.size() > 1 ? Intent.ACTION_SEND_MULTIPLE : Intent.ACTION_SEND)
                .setType(content.mimeType);
        if (content.kind == Content.Kind.link) {
            intent.putExtra(Intent.EXTRA_TEXT, content.summary == null ? content.url.toString() : content.summary + "\n" + content.url);
            if (content.title != null) intent.putExtra(Intent.EXTRA_SUBJECT, content.title).putExtra(Intent.EXTRA_TITLE, content.title);
        } else if (content.text != null) intent.putExtra(Intent.EXTRA_TEXT, content.text);
        if (!content.assets.isEmpty()) {
            if (content.assets.size() == 1) intent.putExtra(Intent.EXTRA_STREAM, content.assets.get(0));
            else intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, new ArrayList<>(content.assets));
            ClipData clip = ClipData.newRawUri("attachment", content.assets.get(0));
            for (int i = 1; i < content.assets.size(); i++) clip.addItem(new ClipData.Item(content.assets.get(i)));
            intent.setClipData(clip); intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        }
        return intent;
    }
    @Override public void start(Request request, Activity activity, Operation operation) {
        if (!us.gfzj.openshare.ShareClient.canPresent(activity)) { operation.fail(Code.invalidPresenter); return; }
        for (Uri uri : request.content.assets) {
            try (AssetFileDescriptor file = activity.getContentResolver().openAssetFileDescriptor(uri, "r")) {
                if (file == null) { operation.fail(Code.resourceUnavailable); return; }
            } catch (IOException | SecurityException exception) { operation.fail(Code.resourceUnavailable); return; }
        }
        try {
            activity.startActivity(Intent.createChooser(createIntent(request.content), null));
            operation.complete(Outcome.handedOff);
        } catch (ActivityNotFoundException | SecurityException exception) { operation.fail(Code.dispatchRejected); }
    }
}
