package com.traffic.wifidirect.ui;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Toast;

public class QRCodeActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Toast.makeText(this, "二维码生成页面(开发中)", Toast.LENGTH_SHORT).show();
    }
}
