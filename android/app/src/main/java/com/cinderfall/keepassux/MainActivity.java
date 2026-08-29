package com.cinderfall.keepassux;

import android.content.Intent;
import android.net.Uri;
import android.view.WindowManager;

import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.cinderfall.keepassux/saf";
    private static final int REQUEST_OPEN_DOCUMENT = 4311;
    private static final int REQUEST_CREATE_DOCUMENT = 4312;

    private MethodChannel.Result pendingDocumentResult;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("openDocument")) {
                    if (pendingDocumentResult != null) {
                        result.error("busy", "Another document request is in progress", null);
                        return;
                    }
                    pendingDocumentResult = result;
                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("*/*");
                    startActivityForResult(intent, REQUEST_OPEN_DOCUMENT);
                } else if (call.method.equals("createDocument")) {
                    if (pendingDocumentResult != null) {
                        result.error("busy", "Another document request is in progress", null);
                        return;
                    }
                    pendingDocumentResult = result;
                    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("application/octet-stream");
                    intent.putExtra(Intent.EXTRA_TITLE, (String) call.argument("fileName"));
                    startActivityForResult(intent, REQUEST_CREATE_DOCUMENT);
                } else if (call.method.equals("takePersistableUriPermission")) {
                    String uriString = call.argument("uri");
                    try {
                        Uri uri = Uri.parse(uriString);
                        int takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
                        getContentResolver().takePersistableUriPermission(uri, takeFlags);
                        result.success(true);
                    } catch (Exception e) {
                        result.success(false);
                    }
                } else if (call.method.equals("setFlagSecure")) {
                    Boolean enabled = call.argument("enabled");
                    if (enabled != null && enabled) {
                        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                    } else {
                        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                    }
                    result.success(true);
                } else {
                    result.notImplemented();
                }
            });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_OPEN_DOCUMENT || requestCode == REQUEST_CREATE_DOCUMENT) {
            MethodChannel.Result result = pendingDocumentResult;
            pendingDocumentResult = null;
            if (result == null) return;
            Uri uri = (resultCode == RESULT_OK && data != null) ? data.getData() : null;
            if (uri == null) {
                result.success(null);
                return;
            }
            try {
                getContentResolver().takePersistableUriPermission(uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            } catch (Exception ignored) {
            }
            result.success(uri.toString());
            return;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }
}
