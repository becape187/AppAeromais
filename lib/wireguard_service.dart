import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WireGuardService {
  static const MethodChannel _channel = MethodChannel('wireguard_service');
  static const String _enabledKey = 'wireguard_enabled';
  
  static bool _isConnected = false;
  static Timer? _monitoringTimer;
  static StreamSubscription<dynamic>? _statusSubscription;
  
  // Configuração padrão para cpmais.local
  static const String _defaultServer = 'cpmais.local';
  static const int _defaultPort = 51820;
  
  // Chaves do cliente WireGuard
  static const String _defaultClientPrivateKey = '2LaVTVjUSmlWOhxbEE/C5n8Vq8hgU3LDIWNY60OrGFM=';
  static const String _defaultClientPublicKey = 'uoONtWlWllUyDjFeIN6qyBXv//CRz5feyd6sJSCV6mY=';
  
  // Chave pública do servidor (deve ser configurada no servidor)
  // Esta será obtida do servidor ou configurada manualmente
  static const String _defaultServerPublicKey = ''; // Será preenchida quando disponível
  
  /// Inicia a conexão WireGuard e monitoramento automático
  static Future<bool> startConnection({
    String? server,
    int? port,
    String? publicKey, // Chave pública do servidor
    String? privateKey, // Chave privada do cliente
    String? allowedIPs,
    String? dns,
    String? serverPublicKey, // Chave pública do servidor (parâmetro específico)
  }) async {
    try {
      if (_isConnected) {
        print('WireGuardService: Já está conectado');
        return true;
      }
      
      // Usar valores padrão se não fornecidos
      final serverHost = server ?? _defaultServer;
      final serverPort = port ?? _defaultPort;
      // DNS da VPN: 10.0.0.1 resolve cpmais.aeromais.com.br -> 10.0.0.1 via Dnsmasq no servidor
      final serverDNS = dns ?? '10.0.0.1';
      final ips = allowedIPs ?? '10.0.0.0/24';
      final clientPrivateKey = privateKey ?? _defaultClientPrivateKey;
      final clientPublicKey = _defaultClientPublicKey; // Chave pública do cliente (para referência)
      final serverPubKey = serverPublicKey ?? publicKey ?? _defaultServerPublicKey; // Chave pública do servidor
      
      // Log detalhado da configuração
      print('═══════════════════════════════════════════════════════');
      print('🔌 WireGuardService: Iniciando conexão VPN');
      print('═══════════════════════════════════════════════════════');
      print('📡 Servidor: $serverHost:$serverPort');
      print('🌐 DNS: $serverDNS (resolve cpmais.aeromais.com.br)');
      print('📍 IP Cliente: 10.0.0.2/32');
      print('🔑 Chave Pública Cliente: ${clientPublicKey.substring(0, 20)}...');
      print('🔐 Chave Pública Servidor: ${serverPubKey.isNotEmpty ? serverPubKey.substring(0, 20) + "..." : "NÃO CONFIGURADA"}');
      print('📋 AllowedIPs: $ips');
      print('═══════════════════════════════════════════════════════');
      
      // Salvar configuração
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      await prefs.setString('wireguard_server', serverHost);
      await prefs.setInt('wireguard_port', serverPort);
      if (serverPubKey.isNotEmpty) {
        await prefs.setString('wireguard_server_public_key', serverPubKey);
      }
      if (privateKey != null) {
        await prefs.setString('wireguard_private_key', privateKey);
      }
      await prefs.setString('wireguard_allowed_ips', ips);
      await prefs.setString('wireguard_dns', serverDNS);
      
      // Preparar configuração para enviar ao nativo
      final config = <String, dynamic>{
        'server': serverHost,
        'port': serverPort,
        'dns': serverDNS,
        'allowedIPs': ips,
        'clientPrivateKey': clientPrivateKey,
        'clientPublicKey': clientPublicKey,
        'serverPublicKey': serverPubKey,
        'clientAddress': '10.0.0.2/32', // IP do cliente na VPN
      };
      
      // Iniciar conexão nativa
      print('🔄 WireGuardService: Enviando configuração para código nativo...');
      final result = await _channel.invokeMethod('startConnection', config);
      
      if (result == true) {
        _isConnected = true;
        _startMonitoring();
        print('✅ WireGuardService: Conexão iniciada com SUCESSO!');
        print('📊 WireGuardService: Status = CONECTADO');
        print('⏱️ WireGuardService: Monitoramento iniciado (verificação a cada 10s)');
        return true;
      } else {
        print('❌ WireGuardService: FALHA ao iniciar conexão');
        print('⚠️ WireGuardService: Verifique se o WireGuard está instalado/configurado');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ WireGuardService: ERRO ao iniciar conexão');
      print('   Erro: $e');
      print('   StackTrace: $stackTrace');
      return false;
    }
  }
  
  /// Para a conexão WireGuard
  static Future<bool> stopConnection() async {
    try {
      if (!_isConnected) {
        print('ℹ️ WireGuardService: Não está conectado (nada a fazer)');
        return true;
      }
      
      print('🛑 WireGuardService: Parando conexão VPN...');
      
      // Salvar preferência
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);
      
      // Parar conexão nativa
      final result = await _channel.invokeMethod('stopConnection');
      
      if (result == true) {
        _isConnected = false;
        _stopMonitoring();
        print('✅ WireGuardService: Conexão parada com SUCESSO');
        print('📊 WireGuardService: Status = DESCONECTADO');
        return true;
      } else {
        print('❌ WireGuardService: FALHA ao parar conexão');
        return false;
      }
    } catch (e) {
      print('❌ WireGuardService: ERRO ao parar conexão: $e');
      return false;
    }
  }
  
  /// Verifica se está conectado
  static bool get isConnected => _isConnected;
  
  /// Verifica status da conexão WireGuard
  static Future<bool> checkConnectionStatus() async {
    try {
      final result = await _channel.invokeMethod('checkStatus');
      final connected = result == true;
      final previousStatus = _isConnected;
      
      if (previousStatus != connected) {
        _isConnected = connected;
        print('═══════════════════════════════════════════════════════');
        print('🔄 WireGuardService: MUDANÇA DE STATUS DETECTADA');
        print('   Status anterior: ${previousStatus ? "CONECTADO" : "DESCONECTADO"}');
        print('   Status atual: ${connected ? "CONECTADO ✅" : "DESCONECTADO ❌"}');
        print('═══════════════════════════════════════════════════════');
        
        // Se estava conectado e agora não está, tentar reconectar
        if (!connected) {
          final prefs = await SharedPreferences.getInstance();
          final wasEnabled = prefs.getBool(_enabledKey) ?? false;
          if (wasEnabled) {
            print('🔄 WireGuardService: Tentando reconectar automaticamente...');
            final reconnected = await _reconnect();
            if (reconnected) {
              _isConnected = true;
              print('✅ WireGuardService: Reconexão bem-sucedida!');
            } else {
              print('❌ WireGuardService: Falha na reconexão. Tentará novamente em 10s.');
            }
          } else {
            print('ℹ️ WireGuardService: VPN desabilitada pelo usuário (não reconectando)');
          }
        } else {
          print('✅ WireGuardService: Conexão estabelecida com sucesso!');
        }
      } else {
        // Status não mudou - log periódico a cada 5 verificações (50 segundos)
        if (connected) {
          print('✅ WireGuardService: Status estável - CONECTADO (verificação periódica)');
        } else {
          print('❌ WireGuardService: Status estável - DESCONECTADO (verificação periódica)');
        }
      }
      
      return connected;
    } catch (e) {
      print('❌ WireGuardService: ERRO ao verificar status: $e');
      return false;
    }
  }
  
  /// Reconecta automaticamente
  static Future<bool> _reconnect() async {
    try {
      print('🔄 WireGuardService: Iniciando processo de reconexão...');
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('wireguard_server') ?? _defaultServer;
      final port = prefs.getInt('wireguard_port') ?? _defaultPort;
      final dns = prefs.getString('wireguard_dns') ?? '10.0.0.1';
      final ips = prefs.getString('wireguard_allowed_ips') ?? '10.0.0.0/24';
      final privateKey = prefs.getString('wireguard_private_key') ?? _defaultClientPrivateKey;
      final serverPubKey = prefs.getString('wireguard_server_public_key') ?? '';
      
      print('📋 WireGuardService: Configuração de reconexão:');
      print('   Servidor: $server:$port');
      print('   DNS: $dns');
      
      final result = await startConnection(
        server: server,
        port: port,
        privateKey: privateKey,
        serverPublicKey: serverPubKey,
        allowedIPs: ips,
        dns: dns,
      );
      
      if (result) {
        print('✅ WireGuardService: Reconexão bem-sucedida!');
      } else {
        print('❌ WireGuardService: Falha na reconexão');
      }
      
      return result;
    } catch (e) {
      print('❌ WireGuardService: ERRO ao reconectar: $e');
      return false;
    }
  }
  
  /// Inicia o monitoramento automático da conexão
  static void _startMonitoring() {
    _stopMonitoring(); // Garantir que não há múltiplos timers
    
    // Verificar status a cada 10 segundos
    _monitoringTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      print('🔍 WireGuardService: Verificando status da conexão...');
      await checkConnectionStatus();
    });
    
    print('✅ WireGuardService: Monitoramento automático INICIADO');
    print('   Intervalo: 10 segundos');
    print('   Ações: Verificação de status e reconexão automática');
  }
  
  /// Para o monitoramento
  static void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('🛑 WireGuardService: Monitoramento automático PARADO');
  }
  
  /// Restaura o estado de conexão salvo ou inicia com configuração padrão
  static Future<bool> restoreConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasEnabled = prefs.getBool(_enabledKey) ?? false;
      
      if (wasEnabled) {
        print('🔄 WireGuardService: Restaurando conexão WireGuard salva...');
        return await _reconnect();
      } else {
        // Se não estava habilitado, iniciar automaticamente com configuração padrão para cpmais.local
        print('🚀 WireGuardService: Iniciando conexão automática para cpmais.local...');
        print('   (Primeira execução ou configuração padrão)');
        return await startConnection(
          server: _defaultServer,
          port: _defaultPort,
          dns: '10.0.0.1',
          allowedIPs: '10.0.0.0/24',
          privateKey: _defaultClientPrivateKey,
          publicKey: _defaultClientPublicKey,
        );
      }
    } catch (e) {
      print('WireGuardService: Erro ao restaurar estado: $e');
      return false;
    }
  }
  
  /// Limpa recursos
  static void dispose() {
    _stopMonitoring();
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }
  
  /// Obtém configuração salva
  static Future<Map<String, dynamic>?> getSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final server = prefs.getString('wireguard_server');
      final port = prefs.getInt('wireguard_port');
      final dns = prefs.getString('wireguard_dns');
      final ips = prefs.getString('wireguard_allowed_ips');
      final publicKey = prefs.getString('wireguard_public_key');
      final privateKey = prefs.getString('wireguard_private_key');
      
      if (server == null) return null;
      
      return {
        'server': server,
        'port': port ?? _defaultPort,
        'dns': dns ?? '10.0.0.1',
        'allowedIPs': ips ?? '10.0.0.0/24',
        'publicKey': publicKey ?? _defaultClientPublicKey,
        'privateKey': privateKey ?? _defaultClientPrivateKey,
      };
    } catch (e) {
      print('WireGuardService: Erro ao obter configuração: $e');
      return null;
    }
  }
}
