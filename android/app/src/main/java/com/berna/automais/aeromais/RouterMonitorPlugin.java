package com.berna.automais.aeromais;

import android.content.Context;
import android.content.Intent;
import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class RouterMonitorPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "RouterMonitorPlugin";
    private static final String CHANNEL_NAME = "router_monitor";
    
    private MethodChannel channel;
    private Context context;
    
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        
        Log.d(TAG, "RouterMonitorPlugin anexado ao engine");
    }
    
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        Log.d(TAG, "Método chamado: " + call.method);
        
        switch (call.method) {
            case "startMonitoring":
                startMonitoring(result);
                break;
            case "stopMonitoring":
                stopMonitoring(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }
    
    private void startMonitoring(Result result) {
        try {
            Intent serviceIntent = new Intent(context, RouterMonitorService.class);
            
            // Usar startService em vez de startForegroundService
            context.startService(serviceIntent);
            
            Log.d(TAG, "Serviço de monitoramento do roteador iniciado");
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Erro ao iniciar monitoramento: " + e.getMessage());
            result.error("START_MONITORING_ERROR", e.getMessage(), null);
        }
    }
    
    private void stopMonitoring(Result result) {
        try {
            Intent serviceIntent = new Intent(context, RouterMonitorService.class);
            context.stopService(serviceIntent);
            
            Log.d(TAG, "Serviço de monitoramento do roteador parado");
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Erro ao parar monitoramento: " + e.getMessage());
            result.error("STOP_MONITORING_ERROR", e.getMessage(), null);
        }
    }
    
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        Log.d(TAG, "RouterMonitorPlugin desanexado do engine");
    }
}
