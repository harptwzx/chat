package com.traffic.wifidirect.ui;

import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import com.traffic.wifidirect.R;
import com.traffic.wifidirect.WiFiDirectManager;

public class SendActivity extends AppCompatActivity {
    private WiFiDirectManager wifiManager;
    private TextView statusText;
    private Button scanButton;
    private Button sendButton;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_send);
        
        wifiManager = new WiFiDirectManager(this);
        statusText = findViewById(R.id.status);
        scanButton = findViewById(R.id.btn_scan);
        sendButton = findViewById(R.id.btn_send);
        
        scanButton.setOnClickListener(v -> {
            wifiManager.discoverPeers();
            statusText.setText("正在扫描设备...");
        });
        
        sendButton.setOnClickListener(v -> {
            // TODO: 选择文件并发送
            statusText.setText("准备发送文件...");
        });
    }
}