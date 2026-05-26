package com.traffic.wifidirect.ui;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Toast;

public class PreviewActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_preview);
        Toast.makeText(this, "文件预览区(开发中)", Toast.LENGTH_SHORT).show();
    }
}
