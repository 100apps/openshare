package us.gfzj.openshare.sample;

import android.app.Activity;
import android.os.Bundle;
import android.os.Build;
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
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars());
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom);
            } else {
                view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(),
                        insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            }
            return insets;
        });
        Button share = new Button(this);
        share.setText(R.string.share);
        share.setOnClickListener(view -> OpenShare.share(this,
                ShareMessage.text("OpenShare https://github.com/100apps/openshare"), getString(R.string.share)));
        layout.addView(share);
        setContentView(layout);
    }
}
