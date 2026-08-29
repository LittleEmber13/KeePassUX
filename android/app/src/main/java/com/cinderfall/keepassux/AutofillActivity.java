package com.cinderfall.keepassux;

import android.content.Intent;
import android.os.Bundle;
import android.view.WindowManager;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class AutofillActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.cinderfall.keepassux/autofill";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
    }

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("launchMainActivity")) {
                    Intent intent = new Intent(this, MainActivity.class);
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                            | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    startActivity(intent);
                    result.success(true);
                } else if (call.method.equals("fillDataset")) {
                    String label = call.argument("label");
                    String username = call.argument("username");
                    String password = call.argument("password");
                    String status = AutofillFiller.INSTANCE.fill(
                            this,
                            label != null ? label : "",
                            username != null ? username : "",
                            password != null ? password : "");
                    result.success(status);
                    if (AutofillFiller.RESULT_DATASET.equals(status)) {
                        finish();
                    }
                } else {
                    result.notImplemented();
                }
            });
    }

    @Override
    public String getDartEntrypointFunctionName() {
        return "autofillEntryPoint";
    }
}
