package com.traffic.wifidirect.ui;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Toast;

public class SendActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_send);
        Toast.makeText(this, "发送文件功能开发中", Toast.LENGTH_SHORT).show();
        // TODO: 文件选择+WiFi Direct+二维码生成
    }
}
