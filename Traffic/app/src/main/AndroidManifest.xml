package com.traffic.wifidirect;

import android.content.Intent;
import android.os.Bundle;
import android.widget.Button;
import androidx.appcompat.app.AppCompatActivity;
import com.traffic.wifidirect.ui.*;

public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        
        Button btnSend = findViewById(R.id.btn_send);
        Button btnReceive = findViewById(R.id.btn_receive);
        
        btnSend.setOnClickListener(v -> {
            Intent intent = new Intent(this, SendActivity.class);
            startActivity(intent);
        });
        
        btnReceive.setOnClickListener(v -> {
            Intent intent = new Intent(this, ReceiveActivity.class);
            startActivity(intent);
        });
    }
}