package us.gfzj.openshare;

import static org.junit.Assert.*;
import android.content.Intent;
import android.net.Uri;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = {23, 30, 36})
public class OpenShareTest {
    @Test public void sharesUnicodeAndLinksWithoutReencoding() {
        Intent intent = OpenShare.createSendIntent(ShareMessage.text("你好 https://example.com/?a=1&b=2"));
        assertEquals(Intent.ACTION_SEND, intent.getAction());
        assertEquals("text/plain", intent.getType());
        assertEquals("你好 https://example.com/?a=1&b=2", intent.getStringExtra(Intent.EXTRA_TEXT));
        assertNull(intent.getClipData());
    }

    @Test public void grantsReadAccessToAttachmentThroughClipData() {
        Uri uri = Uri.parse("content://example.files/share/photo.png");
        Intent intent = OpenShare.createSendIntent(ShareMessage.attachment(uri, "image/png", "caption"));
        assertEquals(uri, intent.getParcelableExtra(Intent.EXTRA_STREAM));
        assertEquals(uri, intent.getClipData().getItemAt(0).getUri());
        assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, intent.getFlags());
    }

    @Test public void opensChooserFromApplicationContext() {
        assertTrue(OpenShare.share(RuntimeEnvironment.getApplication(), ShareMessage.text("hello"), "Share"));
        Intent chooser = Shadows.shadowOf(RuntimeEnvironment.getApplication()).getNextStartedActivity();
        assertEquals(Intent.ACTION_CHOOSER, chooser.getAction());
        assertTrue((chooser.getFlags() & Intent.FLAG_ACTIVITY_NEW_TASK) != 0);
        Intent send = chooser.getParcelableExtra(Intent.EXTRA_INTENT);
        assertEquals("hello", send.getStringExtra(Intent.EXTRA_TEXT));
    }

    @Test public void rejectsEmptyMessagesAndUnsafeFileUris() {
        assertThrows(IllegalArgumentException.class, () -> ShareMessage.text("  "));
        assertThrows(IllegalArgumentException.class, () -> ShareMessage.attachment(
                Uri.parse("file:///sdcard/photo.png"), "image/png", null));
        assertThrows(IllegalArgumentException.class, () -> ShareMessage.attachment(
                Uri.parse("content://files/photo"), "image", null));
    }
}
