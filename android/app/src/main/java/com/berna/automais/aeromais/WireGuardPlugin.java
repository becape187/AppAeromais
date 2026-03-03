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
import java.util.Map;

public class WireGuardPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "WireGuardPlugin";
    private static final String CHANNEL_NAME = "wireguard_service";
    
    private MethodChannel channel;
    private Context context;
    
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
        context = flutterPluginBinding.getApplicationContext();
        Log.d(TAG, "WireGuardPlugin anexado ao engine");
    }    
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        Log.d(TAG, "Método chamado: " + call.method);
        switch (call.method) {
            case "startConnection":
                startConnection(call, result);
                break;
            case "stopConnection":
                stopConnection(result);
                break;
            case "checkStatus":
                checkStatus(result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }    
    @SuppressWarnings("unchecked")
    private void startConnection(MethodCall call, Result result) {
        try {
            Map<String, Object> config = (Map<String, Object>) call.arguments;
            if (config == null) {
                result.error("INVALID_CONFIG", "Configuração não fornecida", null);
                return;
            }
            Intent serviceIntent = new Intent(context, WireGuardService.class);
            serviceIntent.putExtra("server", (String) config.get("server"));
            serviceIntent.putExtra("port", config.get("port") != null ? 
                ((Number) config.get("port")).intValue() : 51820);
            serviceIntent.putExtra("dns", (String) config.get("dns"));
            serviceIntent.putExtra("allowedIPs", (String) config.get("allowedIPs"));
            serviceIntent.putExtra("clientPrivateKey", (String) config.get("clientPrivateKey"));
            serviceIntent.putExtra("clientPublicKey", (String) config.get("clientPublicKey"));
            serviceIntent.putExtra("serverPublicKey", (String) config.get("serverPublicKey"));
            serviceIntent.putExtra("clientAddress", (String) config.get("clientAddress"));
            
            // Usar startForegroundService para Android 8.0+ ou startService para versões anteriores
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent);
            } else {
                context.startService(serviceIntent);
            }
            
            Log.d(TAG, "Serviço WireGuard iniciado");
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Erro ao iniciar conexão WireGuard: " + e.getMessage(), e);
            result.error("START_CONNECTION_ERROR", e.getMessage(), null);
        }
    }    
    private void stopConnection(Result result) {
        try {
            Intent serviceIntent = new Intent(context, WireGuardService.class);
            context.stopService(serviceIntent);
            Log.d(TAG, "Serviço WireGuard parado");
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Erro ao parar conexão WireGuard: " + e.getMessage(), e);
            result.error("STOP_CONNECTION_ERROR", e.getMessage(), null);
        }
    }    
    private void checkStatus(Result result) {
        try {
            boolean isConnected = WireGuardService.isConnected();
            Log.d(TAG, "Status da conexão WireGuard: " + (isConnected ? "conectado" : "desconectado"));
            result.success(isConnected);
        } catch (Exception e) {
            Log.e(TAG, "Erro ao verificar status: " + e.getMessage(), e);
            result.error("CHECK_STATUS_ERROR", e.getMessage(), null);
        }
    }    
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        Log.d(TAG, "WireGuardPlugin desanexado do engine");
    }
}
