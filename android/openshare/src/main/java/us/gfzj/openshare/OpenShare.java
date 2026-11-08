package us.gfzj.openshare;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;

/** System Sharesheet. Opening the chooser does not confirm that a recipient published anything. */
public final class OpenShare {
    private OpenShare() {}

    public static Intent createSendIntent(ShareMessage message) {
        if (message == null) throw new IllegalArgumentException("Message is required");
        Intent intent = new Intent(Intent.ACTION_SEND).setType(message.mimeType);
        if (message.text != null) intent.putExtra(Intent.EXTRA_TEXT, message.text);
        if (message.title != null) intent.putExtra(Intent.EXTRA_SUBJECT, message.title);
        if (message.attachment != null) {
            intent.putExtra(Intent.EXTRA_STREAM, message.attachment);
            intent.setClipData(ClipData.newRawUri("attachment", message.attachment));
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        }
        return intent;
    }

    /** @return false if there is no activity capable of showing the chooser. */
    public static boolean share(Context context, ShareMessage message, CharSequence chooserTitle) {
        Intent chooser = Intent.createChooser(createSendIntent(message), chooserTitle);
        if (!(context instanceof Activity)) chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        // Do not preflight resolveActivity: Android package visibility may hide valid recipients.
        try {
            context.startActivity(chooser);
            return true;
        } catch (ActivityNotFoundException exception) {
            return false;
        }
    }
}
