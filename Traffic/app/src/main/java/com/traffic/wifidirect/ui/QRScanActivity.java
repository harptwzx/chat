package com.traffic.wifidirect.ui;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Toast;

public class QRScanActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Toast.makeText(this, "二维码扫码页面(开发中)", Toast.LENGTH_SHORT).show();
    }
}
