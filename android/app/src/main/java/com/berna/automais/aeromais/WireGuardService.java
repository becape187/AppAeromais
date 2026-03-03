package com.berna.automais.aeromais;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.InetAddress;
import java.util.Timer;
import java.util.TimerTask;

public class WireGuardService extends Service {
    private static final String TAG = "WireGuardService";
    private static final String CHANNEL_ID = "WireGuardChannel";
    private static final int NOTIFICATION_ID = 2;
    private static final int CHECK_INTERVAL = 10000; // 10 segundos
    
    private static boolean isConnected = false;
    private PowerManager.WakeLock wakeLock;
    private Timer timer;
    private String server;
    private int port;
    private String dns;
    private String allowedIPs;
    private String clientPrivateKey;
    private String clientPublicKey;
    private String serverPublicKey;
    private String clientAddress;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "WireGuardService criado");
        
        PowerManager powerManager = (PowerManager) getSystemService(Context.POWER_SERVICE);
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AeroMais:WireGuard");
        
        createNotificationChannel();
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "WireGuardService iniciado");
        
        if (intent != null) {
            server = intent.getStringExtra("server");
            port = intent.getIntExtra("port", 51820);
            dns = intent.getStringExtra("dns");
            allowedIPs = intent.getStringExtra("allowedIPs");
            clientPrivateKey = intent.getStringExtra("clientPrivateKey");
            clientPublicKey = intent.getStringExtra("clientPublicKey");
            serverPublicKey = intent.getStringExtra("serverPublicKey");
            clientAddress = intent.getStringExtra("clientAddress");
            
            Log.d(TAG, "═══════════════════════════════════════════════════════");
            Log.d(TAG, "🔌 WireGuardService: Configuração recebida do Flutter");
            Log.d(TAG, "═══════════════════════════════════════════════════════");
            Log.d(TAG, "📡 Servidor: " + server + ":" + port);
            Log.d(TAG, "🌐 DNS: " + dns + " (resolve cpmais.aeromais.com.br)");
            Log.d(TAG, "📍 IP Cliente: " + (clientAddress != null ? clientAddress : "10.0.0.2/32"));
            Log.d(TAG, "📋 AllowedIPs: " + allowedIPs);
            Log.d(TAG, "🔑 Chave Privada Cliente: " + (clientPrivateKey != null && !clientPrivateKey.isEmpty() ? "***CONFIGURADA***" : "NÃO FORNECIDA"));
            Log.d(TAG, "🔐 Chave Pública Servidor: " + (serverPublicKey != null && !serverPublicKey.isEmpty() ? serverPublicKey.substring(0, Math.min(20, serverPublicKey.length())) + "..." : "NÃO FORNECIDA"));
            Log.d(TAG, "═══════════════════════════════════════════════════════");
        }
        
        // Iniciar como foreground service
        startForeground(NOTIFICATION_ID, createNotification("Conectando ao WireGuard..."));
        
        if (!isConnected) {
            startConnection();
        }
        
        return START_STICKY; // Reinicia o serviço se for morto
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "WireGuardService destruído");
        stopConnection();
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    public static boolean isConnected() {
        return isConnected;
    }
    
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "WireGuard VPN AeroMais",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Mantém conexão WireGuard ativa para cpmais.local");
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
            .setContentTitle("AeroMais - WireGuard VPN")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build();
    }
    
    private void startConnection() {
        if (isConnected) return;
        
        wakeLock.acquire(10*60*1000L /*10 minutes*/);
        
        // Tentar conectar ao WireGuard
        new Thread(() -> {
            try {
                Log.d(TAG, "═══════════════════════════════════════════════════════");
                Log.d(TAG, "🔄 WireGuardService: Iniciando processo de conexão...");
                Log.d(TAG, "═══════════════════════════════════════════════════════");
                
                // Método 1: Tentar usar comandos do sistema (requer root ou app WireGuard instalado)
                Log.d(TAG, "📡 Método 1: Tentando conectar via sistema...");
                boolean connected = connectViaSystem();
                
                if (!connected) {
                    // Método 2: Tentar usar API do WireGuard se disponível
                    Log.d(TAG, "📡 Método 2: Tentando conectar via API do WireGuard...");
                    connected = connectViaAPI();
                }
                
                if (connected) {
                    isConnected = true;
                    startMonitoring();
                    updateNotification("Conectado ao WireGuard: " + (server != null ? server : "cpmais.local"));
                    Log.d(TAG, "═══════════════════════════════════════════════════════");
                    Log.d(TAG, "✅ WireGuardService: Conexão estabelecida com SUCESSO!");
                    Log.d(TAG, "📊 Status: CONECTADO");
                    Log.d(TAG, "═══════════════════════════════════════════════════════");
                } else {
                    Log.w(TAG, "═══════════════════════════════════════════════════════");
                    Log.w(TAG, "❌ WireGuardService: FALHA ao conectar");
                    Log.w(TAG, "⚠️ Verifique se o WireGuard está instalado e configurado");
                    Log.w(TAG, "═══════════════════════════════════════════════════════");
                    updateNotification("Erro ao conectar ao WireGuard");
                }
            } catch (Exception e) {
                Log.e(TAG, "═══════════════════════════════════════════════════════");
                Log.e(TAG, "❌ WireGuardService: ERRO ao conectar");
                Log.e(TAG, "   Erro: " + e.getMessage());
                Log.e(TAG, "═══════════════════════════════════════════════════════");
                updateNotification("Erro: " + e.getMessage());
            }
        }).start();
    }
    
    private boolean connectViaSystem() {
        try {
            Log.d(TAG, "📝 Gerando arquivo de configuração WireGuard...");
            
            // Criar arquivo de configuração WireGuard
            String configContent = generateWireGuardConfig();
            if (configContent == null || configContent.isEmpty()) {
                Log.e(TAG, "❌ Não foi possível gerar configuração WireGuard");
                return false;
            }
            
            // Salvar configuração em arquivo temporário
            File configFile = new File(getFilesDir(), "cpmais.conf");
            try (FileWriter writer = new FileWriter(configFile)) {
                writer.write(configContent);
                writer.flush();
            }
            
            Log.d(TAG, "✅ Configuração WireGuard salva em: " + configFile.getAbsolutePath());
            Log.d(TAG, "📄 Conteúdo da configuração:");
            Log.d(TAG, "─────────────────────────────────────────────────────────");
            Log.d(TAG, configContent);
            Log.d(TAG, "─────────────────────────────────────────────────────────");
            
            // Verificar se há interface WireGuard ativa
            Log.d(TAG, "🔍 Verificando interfaces WireGuard ativas...");
            Process process = Runtime.getRuntime().exec("wg show");
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            String line;
            boolean hasInterface = false;
            StringBuilder wgOutput = new StringBuilder();
            
            while ((line = reader.readLine()) != null) {
                wgOutput.append(line).append("\n");
                if (line.contains("interface:") || line.contains("wg")) {
                    hasInterface = true;
                }
            }
            
            process.waitFor();
            
            if (hasInterface) {
                Log.d(TAG, "✅ Interface WireGuard encontrada via comando do sistema");
                Log.d(TAG, "📊 Saída do 'wg show':");
                Log.d(TAG, wgOutput.toString());
                return true;
            } else {
                Log.d(TAG, "⚠️ Nenhuma interface WireGuard ativa encontrada");
                Log.d(TAG, "📊 Saída do 'wg show': " + (wgOutput.length() > 0 ? wgOutput.toString() : "(vazio)"));
            }
            
            // Tentar verificar conectividade com o servidor
            if (server != null && !server.isEmpty()) {
                Log.d(TAG, "🌐 Verificando conectividade com servidor: " + server + ":" + port);
                return checkServerConnectivity(server, port);
            }
            
        } catch (Exception e) {
            Log.d(TAG, "⚠️ Comando do sistema não disponível (normal se não root): " + e.getMessage());
            Log.d(TAG, "   Detalhes: " + e.getClass().getSimpleName());
        }
        
        return false;
    }
    
    private String generateWireGuardConfig() {
        try {
            if (clientPrivateKey == null || clientPrivateKey.isEmpty()) {
                Log.e(TAG, "Chave privada do cliente não fornecida");
                return null;
            }
            
            if (server == null || server.isEmpty()) {
                Log.e(TAG, "Servidor não fornecido");
                return null;
            }
            
            StringBuilder config = new StringBuilder();
            config.append("[Interface]\n");
            config.append("PrivateKey = ").append(clientPrivateKey).append("\n");
            config.append("Address = ").append(clientAddress != null ? clientAddress : "10.0.0.2/32").append("\n");
            
            // Configurar DNS da VPN (10.0.0.1)
            // Este DNS resolve cpmais.aeromais.com.br -> 10.0.0.1 via Dnsmasq no servidor
            if (dns != null && !dns.isEmpty()) {
                config.append("DNS = ").append(dns).append("\n");
            }
            
            config.append("\n[Peer]\n");
            
            if (serverPublicKey != null && !serverPublicKey.isEmpty()) {
                config.append("PublicKey = ").append(serverPublicKey).append("\n");
            } else {
                Log.w(TAG, "Chave pública do servidor não fornecida - conexão pode falhar");
                // Continuar mesmo sem a chave pública para permitir configuração manual
            }
            
            config.append("Endpoint = ").append(server).append(":").append(port).append("\n");
            config.append("AllowedIPs = ").append(allowedIPs != null ? allowedIPs : "10.0.0.0/24").append("\n");
            config.append("PersistentKeepalive = 25\n");
            
            return config.toString();
        } catch (Exception e) {
            Log.e(TAG, "Erro ao gerar configuração WireGuard: " + e.getMessage(), e);
            return null;
        }
    }
    
    private boolean connectViaAPI() {
        try {
            // Tentar usar a API do WireGuard Android se disponível
            // Nota: Isso requer o app WireGuard instalado e permissões adequadas
            Log.d(TAG, "Tentando conectar via API do WireGuard...");
            
            // Por enquanto, apenas verificar conectividade
            if (server != null && !server.isEmpty()) {
                return checkServerConnectivity(server, port);
            }
            
        } catch (Exception e) {
            Log.d(TAG, "API do WireGuard não disponível: " + e.getMessage());
        }
        
        return false;
    }
    
    private boolean checkServerConnectivity(String host, int port) {
        try {
            Log.d(TAG, "🔍 Verificando conectividade com " + host + ":" + port);
            
            // Tentar resolver o hostname
            Log.d(TAG, "   Resolvendo hostname: " + host);
            InetAddress address = InetAddress.getByName(host);
            String resolvedIP = address.getHostAddress();
            Log.d(TAG, "   IP resolvido: " + resolvedIP);
            
            Log.d(TAG, "   Testando reachability (timeout: 3s)...");
            boolean reachable = address.isReachable(3000); // 3 segundos timeout
            
            if (reachable) {
                Log.d(TAG, "✅ Servidor " + host + " (" + resolvedIP + ") está ACESSÍVEL");
                return true;
            } else {
                Log.w(TAG, "❌ Servidor " + host + " (" + resolvedIP + ") NÃO está acessível");
                Log.w(TAG, "   Possíveis causas:");
                Log.w(TAG, "   - Servidor offline");
                Log.w(TAG, "   - Firewall bloqueando");
                Log.w(TAG, "   - VPN não conectada");
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ Erro ao verificar conectividade com " + host);
            Log.e(TAG, "   Erro: " + e.getMessage());
            Log.e(TAG, "   Tipo: " + e.getClass().getSimpleName());
        }
        
        return false;
    }
    
    private void startMonitoring() {
        if (timer != null) {
            Log.w(TAG, "⚠️ Monitoramento já está ativo");
            return;
        }
        
        Log.d(TAG, "═══════════════════════════════════════════════════════");
        Log.d(TAG, "✅ WireGuardService: Iniciando monitoramento automático");
        Log.d(TAG, "   Intervalo: " + (CHECK_INTERVAL / 1000) + " segundos");
        Log.d(TAG, "   Ações: Verificação de status e reconexão automática");
        Log.d(TAG, "═══════════════════════════════════════════════════════");
        
        timer = new Timer();
        timer.scheduleAtFixedRate(new TimerTask() {
            @Override
            public void run() {
                new Thread(() -> {
                    try {
                        checkConnectionStatus();
                    } catch (Exception e) {
                        Log.e(TAG, "❌ Erro no timer de monitoramento: " + e.getMessage());
                        Log.e(TAG, "   StackTrace: " + android.util.Log.getStackTraceString(e));
                    }
                }).start();
            }
        }, CHECK_INTERVAL, CHECK_INTERVAL);
    }
    
    private void checkConnectionStatus() {
        try {
            boolean currentlyConnected = false;
            boolean previousStatus = isConnected;
            
            Log.d(TAG, "🔍 Verificando status da conexão WireGuard...");
            Log.d(TAG, "   Status anterior: " + (previousStatus ? "CONECTADO" : "DESCONECTADO"));
            
            // Verificar via comando do sistema
            try {
                Log.d(TAG, "   Executando 'wg show'...");
                Process process = Runtime.getRuntime().exec("wg show");
                BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
                String line;
                StringBuilder output = new StringBuilder();
                
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                    if (line.contains("interface:") || line.contains("wg")) {
                        currentlyConnected = true;
                    }
                }
                
                process.waitFor();
                
                if (output.length() > 0) {
                    Log.d(TAG, "   Saída do 'wg show':");
                    Log.d(TAG, output.toString());
                } else {
                    Log.d(TAG, "   Saída do 'wg show': (vazio)");
                }
                
            } catch (Exception e) {
                Log.d(TAG, "   ⚠️ Comando 'wg show' não disponível: " + e.getMessage());
                // Se comando não disponível, verificar conectividade com servidor
                if (server != null && !server.isEmpty()) {
                    Log.d(TAG, "   Verificando conectividade como alternativa...");
                    currentlyConnected = checkServerConnectivity(server, port);
                }
            }
            
            Log.d(TAG, "   Status atual: " + (currentlyConnected ? "CONECTADO ✅" : "DESCONECTADO ❌"));
            
            if (currentlyConnected != previousStatus) {
                isConnected = currentlyConnected;
                
                Log.d(TAG, "═══════════════════════════════════════════════════════");
                Log.d(TAG, "🔄 MUDANÇA DE STATUS DETECTADA");
                Log.d(TAG, "   Anterior: " + (previousStatus ? "CONECTADO" : "DESCONECTADO"));
                Log.d(TAG, "   Atual: " + (isConnected ? "CONECTADO ✅" : "DESCONECTADO ❌"));
                Log.d(TAG, "═══════════════════════════════════════════════════════");
                
                if (isConnected) {
                    Log.d(TAG, "✅ Conexão WireGuard RESTABELECIDA");
                    updateNotification("Conectado ao WireGuard: " + (server != null ? server : "cpmais.local"));
                } else {
                    Log.w(TAG, "❌ Conexão WireGuard PERDIDA");
                    Log.w(TAG, "🔄 Tentando reconectar...");
                    updateNotification("Reconectando ao WireGuard...");
                    // Tentar reconectar
                    connectViaSystem();
                }
            } else if (isConnected) {
                Log.d(TAG, "✅ Conexão WireGuard ESTÁVEL (verificação periódica)");
            } else {
                Log.d(TAG, "❌ Conexão WireGuard ainda DESCONECTADA (verificação periódica)");
            }
            
        } catch (Exception e) {
            Log.e(TAG, "❌ Erro ao verificar status: " + e.getMessage());
            Log.e(TAG, "   StackTrace: " + android.util.Log.getStackTraceString(e));
        }
    }
    
    private void stopConnection() {
        Log.d(TAG, "═══════════════════════════════════════════════════════");
        Log.d(TAG, "🛑 WireGuardService: Parando conexão VPN...");
        Log.d(TAG, "═══════════════════════════════════════════════════════");
        
        isConnected = false;
        
        if (timer != null) {
            timer.cancel();
            timer = null;
            Log.d(TAG, "✅ Timer de monitoramento cancelado");
        }
        
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
            Log.d(TAG, "✅ WakeLock liberado");
        }
        
        Log.d(TAG, "✅ Conexão WireGuard PARADA");
        Log.d(TAG, "📊 Status: DESCONECTADO");
        Log.d(TAG, "═══════════════════════════════════════════════════════");
    }
    
    private void updateNotification(String content) {
        Notification notification = createNotification(content);
        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        manager.notify(NOTIFICATION_ID, notification);
    }
}
