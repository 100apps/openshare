package us.gfzj.openshare.sample;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.LinearLayout;
import us.gfzj.openshare.OpenShare;
import us.gfzj.openshare.ShareMessage;

public final class MainActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setOnApplyWindowInsetsListener((view, insets) -> {
            android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            return insets;
        });
        Button share = new Button(this);
        share.setText("Share / 分享");
        share.setOnClickListener(view -> OpenShare.share(this,
                ShareMessage.text("OpenShare https://github.com/100apps/openshare"), "Share"));
        layout.addView(share);
        setContentView(layout);
    }
}
