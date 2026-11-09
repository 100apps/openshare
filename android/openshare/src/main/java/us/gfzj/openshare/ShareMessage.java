package us.gfzj.openshare;

import android.net.Uri;

/** A text/link message or one attachment. Attachments must be readable content:// URIs. */
public final class ShareMessage {
    public final String text;
    public final String title;
    public final Uri attachment;
    public final String mimeType;

    private ShareMessage(String text, String title, Uri attachment, String mimeType) {
        this.text = text;
        this.title = title;
        this.attachment = attachment;
        this.mimeType = mimeType;
    }

    public static ShareMessage text(String text) {
        if (text == null || text.trim().isEmpty()) {
            throw new IllegalArgumentException("Share text must not be empty");
        }
        return new ShareMessage(text, null, null, "text/plain");
    }

    public static ShareMessage attachment(Uri uri, String mimeType, String text) {
        if (uri == null || !"content".equals(uri.getScheme()) || uri.getAuthority() == null) {
            throw new IllegalArgumentException("Use a content:// URI from a content provider");
        }
        if (mimeType == null || !mimeType.matches("[^\\s/]+/[^\\s/]+")) {
            throw new IllegalArgumentException("An attachment needs a MIME type");
        }
        return new ShareMessage(text, null, uri, mimeType);
    }

    public ShareMessage withTitle(String title) {
        return new ShareMessage(text, title, attachment, mimeType);
    }
}
