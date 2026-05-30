package com.traffic.wifidirect.ui;

import android.os.Bundle;
import android.widget.Button;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import com.traffic.wifidirect.R;
import com.traffic.wifidirect.WiFiDirectManager;

public class ReceiveActivity extends AppCompatActivity {
    private WiFiDirectManager wifiManager;
    private TextView statusText;
    private Button receiveButton;
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_receive);
        
        wifiManager = new WiFiDirectManager(this);
        statusText = findViewById(R.id.status);
        receiveButton = findViewById(R.id.btn_receive);
        
        receiveButton.setOnClickListener(v -> {
            wifiManager.discoverPeers();
            statusText.setText("等待发送方连接...");
            // TODO: 启动接收服务
        });
    }
}