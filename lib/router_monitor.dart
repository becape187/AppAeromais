import 'dart:async';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RouterMonitor {
  static const MethodChannel _channel = MethodChannel('router_monitor');
  static const String _monitoringKey = 'router_monitoring_enabled';
  
  static bool _isMonitoring = false;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  /// Inicia o monitoramento do roteador
  static Future<bool> startMonitoring() async {
    try {
      if (_isMonitoring) {
        print('RouterMonitor: Já está monitorando');
        return true;
      }
      
      // Salvar preferência
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_monitoringKey, true);
      
      // Iniciar serviço nativo
      final result = await _channel.invokeMethod('startMonitoring');
      
      if (result == true) {
        _isMonitoring = true;
        _startConnectivityListener();
        print('RouterMonitor: Monitoramento iniciado com sucesso');
        return true;
      } else {
        print('RouterMonitor: Falha ao iniciar monitoramento');
        return false;
      }
    } catch (e) {
      print('RouterMonitor: Erro ao iniciar monitoramento: $e');
      return false;
    }
  }
  
  /// Para o monitoramento do roteador
  static Future<bool> stopMonitoring() async {
    try {
      if (!_isMonitoring) {
        print('RouterMonitor: Não está monitorando');
        return true;
      }
      
      // Salvar preferência
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_monitoringKey, false);
      
      // Parar serviço nativo
      final result = await _channel.invokeMethod('stopMonitoring');
      
      if (result == true) {
        _isMonitoring = false;
        _stopConnectivityListener();
        print('RouterMonitor: Monitoramento parado com sucesso');
        return true;
      } else {
        print('RouterMonitor: Falha ao parar monitoramento');
        return false;
      }
    } catch (e) {
      print('RouterMonitor: Erro ao parar monitoramento: $e');
      return false;
    }
  }
  
  /// Verifica se está monitorando
  static bool get isMonitoring => _isMonitoring;
  
  /// Verifica conectividade atual
  static Future<List<ConnectivityResult>> getConnectivityStatus() async {
    try {
      final connectivity = Connectivity();
      return await connectivity.checkConnectivity();
    } catch (e) {
      print('RouterMonitor: Erro ao verificar conectividade: $e');
      return [ConnectivityResult.none];
    }
  }
  
  /// Restaura o estado de monitoramento salvo
  static Future<bool> restoreMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasMonitoring = prefs.getBool(_monitoringKey) ?? false;
      
      if (wasMonitoring) {
        return await startMonitoring();
      }
      
      return true;
    } catch (e) {
      print('RouterMonitor: Erro ao restaurar estado: $e');
      return false;
    }
  }
  
  /// Inicia o listener de conectividade
  static void _startConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        print('RouterMonitor: Mudança de conectividade: $results');
        
        if (results.isEmpty || results.contains(ConnectivityResult.none)) {
          print('RouterMonitor: Sem conectividade detectada');
        } else if (results.contains(ConnectivityResult.wifi)) {
          print('RouterMonitor: WiFi conectado');
        }
      },
      onError: (error) {
        print('RouterMonitor: Erro no listener de conectividade: $error');
      },
    );
  }
  
  /// Para o listener de conectividade
  static void _stopConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  /// Limpa recursos
  static void dispose() {
    _stopConnectivityListener();
  }
}
