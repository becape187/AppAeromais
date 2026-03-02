package com.berna.automais.aeromais;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "BootReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        Log.d(TAG, "BootReceiver recebeu ação: " + action);
        
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) ||
            Intent.ACTION_MY_PACKAGE_REPLACED.equals(action) ||
            Intent.ACTION_PACKAGE_REPLACED.equals(action)) {
            
            Log.d(TAG, "Iniciando RouterMonitorService após boot/atualização");
            
            Intent serviceIntent = new Intent(context, RouterMonitorService.class);
            
            // Usar startService em vez de startForegroundService
            context.startService(serviceIntent);
        }
    }
}
