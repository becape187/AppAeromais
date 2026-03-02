package com.berna.automais.aeromais;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.provider.Settings;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import java.lang.reflect.Method;
import java.io.IOException;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.Socket;
import java.util.Collections;
import java.util.Enumeration;
import java.util.Timer;
import java.util.TimerTask;

public class RouterMonitorService extends Service {
    private static final String TAG = "RouterMonitorService";
    private static final String CHANNEL_ID = "RouterMonitorChannel";
    private static final int NOTIFICATION_ID = 1;
    private static final int CHECK_INTERVAL = 10000; // 10 segundos
    
    private ConnectivityManager connectivityManager;
    private WifiManager wifiManager;
    private PowerManager.WakeLock wakeLock;
    private Timer timer;
    private boolean isMonitoring = false;
    private String routerIp = null;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "RouterMonitorService criado");
        
        connectivityManager = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        wifiManager = (WifiManager) getSystemService(Context.WIFI_SERVICE);
        
        // Criar wake lock para manter o dispositivo ativo
        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AeroMais:RouterMonitor");
        
        createNotificationChannel();
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "RouterMonitorService iniciado");
        
        if (!isMonitoring) {
            // Não usar foreground service para evitar restrições do Android 14+
            startMonitoring();
        }
        
        return START_STICKY; // Reinicia o serviço se for morto
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "RouterMonitorService destruído");
        stopMonitoring();
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Monitor Roteador AeroMais",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Monitora e mantém o roteador ativo");
            channel.setShowBadge(false);
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            manager.createNotificationChannel(channel);
        }
    }
    
    private Notification createNotification(String content) {
        Intent notificationIntent = new Intent();
        notificationIntent.setClassName("br.com.aeromais.app", "br.com.aeromais.app.MainActivity");
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, 
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ? PendingIntent.FLAG_IMMUTABLE : 0
        );
        
        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AeroMais - Monitor Roteador")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build();
    }
    
    private void startMonitoring() {
        if (isMonitoring) return;
        
        isMonitoring = true;
        wakeLock.acquire(10*60*1000L /*10 minutes*/);
        
        timer = new Timer();
        timer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                // Executar em thread separada para evitar ANR
                new Thread(() -> {
                    try {
                        checkRouterStatus();
                    } catch (Exception e) {
                        Log.e(TAG, "Erro no timer: " + e.getMessage());
                    }
                }).start();
            }
        }, 0, CHECK_INTERVAL);
        
        Log.d(TAG, "Monitoramento do roteador iniciado");
    }
    
    private void stopMonitoring() {
        if (!isMonitoring) return;
        
        isMonitoring = false;
        
        if (timer != null) {
            timer.cancel();
            timer = null;
        }
        
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
        
        Log.d(TAG, "Monitoramento do roteador parado");
    }
    
    private void checkRouterStatus() {
        try {
            Log.d(TAG, "Verificando status do roteador do tablet...");
            
            // Verificar se a interface swlan0 está ativa
            boolean routerActive = isRouterInterfaceActive();
            
            if (routerActive) {
                Log.d(TAG, "Roteador do tablet está ativo (interface swlan0 UP)");
                updateNotification("Roteador ativo e funcionando");
                
                // Detectar IP se necessário
                if (routerIp == null) {
                    routerIp = detectRouterIP();
                    if (routerIp != null) {
                        Log.d(TAG, "IP do roteador detectado: " + routerIp);
                    }
                }
            } else {
                Log.d(TAG, "Roteador do tablet não está ativo, tentando religar...");
                attemptRouterWakeup();
                updateNotification("Roteador desligado - religando...");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Erro ao verificar roteador: " + e.getMessage(), e);
            updateNotification("Erro no monitoramento do roteador");
        }
    }
    
    private boolean isRouterInterfaceActive() {
        try {
            // Método 1: Verificar estado do hotspot via reflexão
            boolean hotspotEnabled = isHotspotEnabled();
            if (hotspotEnabled) {
                Log.d(TAG, "Hotspot está habilitado via API");
                return true;
            }
            
            // Método 2: Verificar interfaces de rede
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            for (NetworkInterface networkInterface : Collections.list(interfaces)) {
                String interfaceName = networkInterface.getName();
                
                // Verificar se a interface swlan0 está UP
                if (interfaceName != null && interfaceName.equals("swlan0")) {
                    boolean isUp = networkInterface.isUp();
                    Log.d(TAG, "Interface swlan0 encontrada - Status: " + (isUp ? "UP" : "DOWN"));
                    return isUp;
                }
            }
            
            // Se não encontrou swlan0, procurar por outras interfaces de hotspot
            for (NetworkInterface networkInterface : Collections.list(interfaces)) {
                String interfaceName = networkInterface.getName();
                if (interfaceName != null && 
                    (interfaceName.startsWith("ap") || interfaceName.contains("hotspot") || 
                     interfaceName.startsWith("wlan1") || interfaceName.startsWith("softap"))) {
                    boolean isUp = networkInterface.isUp();
                    Log.d(TAG, "Interface hotspot alternativa encontrada: " + interfaceName + " - Status: " + (isUp ? "UP" : "DOWN"));
                    return isUp;
                }
            }
            
            Log.d(TAG, "Nenhuma interface de roteador/hotspot encontrada");
            return false;
            
        } catch (Exception e) {
            Log.e(TAG, "Erro ao verificar interface do roteador: " + e.getMessage());
            return false;
        }
    }
    
    private boolean pingRouter(String ip) {
        try {
            InetAddress address = InetAddress.getByName(ip);
            return address.isReachable(3000); // 3 segundos timeout
        } catch (IOException e) {
            Log.d(TAG, "Ping falhou para " + ip + ": " + e.getMessage());
            return false;
        }
    }
    
    private void attemptRouterWakeup() {
        try {
            Log.d(TAG, "Roteador desligado - abrindo configurações para o usuário...");
            
            // Abrir configurações de hotspot/tethering para o usuário
            try {
                Intent intent = new Intent(Settings.ACTION_WIRELESS_SETTINGS);
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(intent);
                Log.d(TAG, "Configurações de rede abertas para o usuário");
            } catch (Exception e) {
                // Tentar abrir configurações gerais se as específicas falharem
                try {
                    Intent intent = new Intent(Settings.ACTION_SETTINGS);
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(intent);
                    Log.d(TAG, "Configurações gerais abertas para o usuário");
                } catch (Exception e2) {
                    Log.d(TAG, "Falha ao abrir configurações: " + e2.getMessage());
                }
            }
            
            // Resetar o IP detectado para forçar nova detecção
            routerIp = null;
            
        } catch (Exception e) {
            Log.e(TAG, "Erro ao abrir configurações: " + e.getMessage());
        }
    }
    
    private boolean enableHotspotReflection() {
        try {
            // Método baseado no Stack Overflow para ativar hotspot via reflexão
            Method method = wifiManager.getClass().getDeclaredMethod("setWifiApEnabled", WifiConfiguration.class, boolean.class);
            method.setAccessible(true);
            
            // Criar configuração básica do hotspot
            WifiConfiguration config = new WifiConfiguration();
            config.SSID = "AeroMaisHotspot";
            config.preSharedKey = "12345678";
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK);
            config.allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN);
            
            // Tentar ativar o hotspot
            Boolean result = (Boolean) method.invoke(wifiManager, config, true);
            Log.d(TAG, "Resultado setWifiApEnabled: " + result);
            
            return result != null && result;
            
        } catch (Exception e) {
            Log.e(TAG, "Erro na reflexão para ativar hotspot: " + e.getMessage());
            return false;
        }
    }
    
    private boolean isHotspotEnabled() {
        try {
            Method method = wifiManager.getClass().getDeclaredMethod("getWifiApState");
            method.setAccessible(true);
            int state = (Integer) method.invoke(wifiManager);
            
            // Estados do hotspot: 10-desabilitado, 11-habilitando, 12-habilitado, 13-desabilitando
            Log.d(TAG, "Estado do hotspot: " + state);
            return state == 12; // WIFI_AP_STATE_ENABLED
            
        } catch (Exception e) {
            Log.e(TAG, "Erro ao verificar estado do hotspot: " + e.getMessage());
            return false;
        }
    }
    
    private void updateNotification(String content) {
        Notification notification = createNotification(content);
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        manager.notify(NOTIFICATION_ID, notification);
    }
    
    private String detectRouterIP() {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            for (NetworkInterface networkInterface : Collections.list(interfaces)) {
                String interfaceName = networkInterface.getName();
                Log.d(TAG, "Verificando interface: " + interfaceName + ", Up: " + networkInterface.isUp());
                
                // Procurar especificamente pela interface do roteador do tablet (swlan0)
                if (interfaceName != null && interfaceName.equals("swlan0") && networkInterface.isUp()) {
                    Enumeration<InetAddress> addresses = networkInterface.getInetAddresses();
                    for (InetAddress address : Collections.list(addresses)) {
                        if (!address.isLoopbackAddress() && address.getAddress().length == 4) {
                            String ip = address.getHostAddress();
                            Log.d(TAG, "Interface roteador encontrada: " + interfaceName + ", IP: " + ip);
                            return ip; // O próprio IP da interface do roteador
                        }
                    }
                }
            }
            
            // Se não encontrou swlan0, procurar por outras interfaces de hotspot
            for (NetworkInterface networkInterface : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                String interfaceName = networkInterface.getName();
                if (interfaceName != null && 
                    (interfaceName.startsWith("ap") || interfaceName.startsWith("wlan") || interfaceName.contains("hotspot")) &&
                    networkInterface.isUp()) {
                    
                    Enumeration<InetAddress> addresses = networkInterface.getInetAddresses();
                    for (InetAddress address : Collections.list(addresses)) {
                        if (!address.isLoopbackAddress() && address.getAddress().length == 4) {
                            String ip = address.getHostAddress();
                            Log.d(TAG, "Interface hotspot alternativa encontrada: " + interfaceName + ", IP: " + ip);
                            return ip;
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            Log.e(TAG, "Erro ao detectar IP do roteador: " + e.getMessage());
        }
        return null;
    }
    
    private String getGatewayFromIP(String ip) {
        try {
            // Para a maioria das redes domésticas, o gateway é o primeiro IP da sub-rede
            String[] parts = ip.split("\\.");
            if (parts.length == 4) {
                // Tentar diferentes IPs comuns de gateway
                String[] commonGateways = {
                    parts[0] + "." + parts[1] + "." + parts[2] + ".1",  // 192.168.1.1, 10.0.0.1, etc.
                    parts[0] + "." + parts[1] + "." + parts[2] + ".254", // 192.168.1.254
                    "192.168.1.1",  // Padrão comum
                    "192.168.0.1",  // Padrão comum
                    "10.0.0.1"      // Padrão comum
                };
                
                for (String gateway : commonGateways) {
                    if (pingRouter(gateway)) {
                        Log.d(TAG, "Gateway encontrado: " + gateway);
                        return gateway;
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Erro ao detectar gateway: " + e.getMessage());
        }
        return null;
    }
}
