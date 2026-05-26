package com.traffic.wifidirect.ui;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Toast;

public class ReceiveActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_receive);
        Toast.makeText(this, "接收文件功能开发中", Toast.LENGTH_SHORT).show();
        // TODO: 二维码扫码+WiFi Direct加网+文件接收
    }
}
