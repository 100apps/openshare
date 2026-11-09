package us.gfzj.openshare.sample;

import static org.junit.Assert.*;
import android.content.Intent;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.Until;
import org.junit.Test;
import org.junit.runner.RunWith;
import us.gfzj.openshare.ShareClient;
import us.gfzj.openshare.SystemShareProvider;

@RunWith(AndroidJUnit4.class)
public class ShareSheetTest {
    @Test public void opensRealSystemShareSheet() {
        UiDevice device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        try (ActivityScenario<MainActivity> scenario = ActivityScenario.launch(MainActivity.class)) {
            String[] resolverPackage = new String[1];
            scenario.onActivity(activity -> {
                Intent chooser = Intent.createChooser(new SystemShareProvider().createIntent(ShareClient.Content.text("你好 OpenShare")), "Share");
                resolverPackage[0] = chooser.resolveActivity(activity.getPackageManager()).getPackageName();
            });
            device.waitForIdle();
            androidx.test.uiautomator.UiObject2 button = device.wait(Until.findObject(By.res("android", "button1")), 10000);
            assertNotNull("Visible sample share button", button);
            button.click();
            assertTrue("System Sharesheet did not appear", device.wait(Until.hasObject(By.pkg(resolverPackage[0])), 10000));
            device.pressBack();
        }
    }
}
