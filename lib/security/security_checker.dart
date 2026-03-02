/// Módulo de verificação de segurança do dispositivo Android.
/// 
/// PTRZN-1517, 1518, 1520: Implementa detecção de root, emulação e verificação
/// de integridade do APK para proteger contra ambientes comprometidos.

import 'dart:io';
import 'package:flutter/services.dart';

/// Resultado da verificação de segurança
class SecurityCheckResult {
  final bool isSecure;
  final List<String> issues;
  final bool isRooted;
  final bool isEmulator;
  final bool isTampered;

  SecurityCheckResult({
    required this.isSecure,
    required this.issues,
    required this.isRooted,
    required this.isEmulator,
    required this.isTampered,
  });

  @override
  String toString() {
    return 'SecurityCheckResult(isSecure: $isSecure, issues: $issues, '
        'isRooted: $isRooted, isEmulator: $isEmulator, isTampered: $isTampered)';
  }
}

/// Classe para verificar segurança do dispositivo Android
class SecurityChecker {
  static const MethodChannel _channel = MethodChannel('br.com.aeromais.app/security');

  /// Verifica se o dispositivo está seguro para executar o app
  /// 
  /// PTRZN-1517: Detecta dispositivos rooteados
  /// PTRZN-1518: Detecta emuladores
  /// PTRZN-1520: Verifica integridade do APK
  static Future<SecurityCheckResult> checkDeviceSecurity() async {
    if (!Platform.isAndroid) {
      // Em outras plataformas, considera seguro
      return SecurityCheckResult(
        isSecure: true,
        issues: [],
        isRooted: false,
        isEmulator: false,
        isTampered: false,
      );
    }

    List<String> issues = [];
    bool isRooted = false;
    bool isEmulator = false;
    bool isTampered = false;

    try {
      // PTRZN-1517: Verificar root
      isRooted = await _checkRoot();
      if (isRooted) {
        issues.add('Dispositivo rooteado detectado');
      }

      // PTRZN-1518: Verificar emulação
      isEmulator = await _checkEmulator();
      if (isEmulator) {
        issues.add('Emulador detectado');
      }

      // PTRZN-1520: Verificar integridade do APK (assinatura, checksum, debugger)
      isTampered = await _checkApkIntegrity();
      if (isTampered) {
        // Verifica qual tipo de adulteração foi detectada
        final hasDebugger = await checkDebugger();
        final hasInvalidChecksum = await checkApkChecksum();
        
        if (hasDebugger) {
          issues.add('Debugger conectado detectado (possível engenharia reversa)');
        }
        if (hasInvalidChecksum) {
          issues.add('Checksum do APK inválido (APK modificado)');
        } else {
          issues.add('Assinatura do APK inválida (APK adulterado)');
        }
      }
    } catch (e) {
      // Em caso de erro, considera inseguro por precaução
      issues.add('Erro ao verificar segurança: $e');
      return SecurityCheckResult(
        isSecure: false,
        issues: issues,
        isRooted: true, // Assume root em caso de erro
        isEmulator: false,
        isTampered: true, // Assume adulterado em caso de erro
      );
    }

    return SecurityCheckResult(
      isSecure: issues.isEmpty,
      issues: issues,
      isRooted: isRooted,
      isEmulator: isEmulator,
      isTampered: isTampered,
    );
  }

  /// PTRZN-1517: Verifica se o dispositivo está rooteado
  static Future<bool> _checkRoot() async {
    try {
      // Verifica via método nativo
      final result = await _channel.invokeMethod<bool>('checkRoot');
      return result ?? false;
    } catch (e) {
      // Se o método nativo não estiver disponível, tenta verificação básica
      return await _checkRootBasic();
    }
  }

  /// Verificação básica de root (sem método nativo)
  static Future<bool> _checkRootBasic() async {
    // Lista de indicadores comuns de root
    final rootIndicators = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];

    for (final path in rootIndicators) {
      final file = File(path);
      if (await file.exists()) {
        return true;
      }
    }

    return false;
  }

  /// PTRZN-1518: Verifica se está rodando em emulador
  static Future<bool> _checkEmulator() async {
    try {
      // Verifica via método nativo
      final result = await _channel.invokeMethod<bool>('checkEmulator');
      return result ?? false;
    } catch (e) {
      // Se o método nativo não estiver disponível, tenta verificação básica
      return await _checkEmulatorBasic();
    }
  }

  /// Verificação básica de emulador (sem método nativo)
  static Future<bool> _checkEmulatorBasic() async {
    // Verifica variáveis de ambiente comuns em emuladores
    final emulatorIndicators = [
      'ANDROID_EMULATOR',
      'ANDROID_SERIAL',
    ];

    // Verifica propriedades do sistema (via método nativo se disponível)
    try {
      final buildModel = await _channel.invokeMethod<String>('getBuildModel');
      final buildManufacturer = await _channel.invokeMethod<String>('getBuildManufacturer');
      final buildHardware = await _channel.invokeMethod<String>('getBuildHardware');
      final buildFingerprint = await _channel.invokeMethod<String>('getBuildFingerprint');

      // Lista de indicadores de emulador
      final emulatorModels = ['sdk', 'google_sdk', 'Emulator', 'Android SDK'];
      final emulatorManufacturers = ['Genymotion', 'unknown'];
      final emulatorHardware = ['goldfish', 'ranchu', 'vbox86'];

      if (buildModel != null && emulatorModels.any((m) => buildModel.toLowerCase().contains(m.toLowerCase()))) {
        return true;
      }

      if (buildManufacturer != null && emulatorManufacturers.any((m) => buildManufacturer.toLowerCase().contains(m.toLowerCase()))) {
        return true;
      }

      if (buildHardware != null && emulatorHardware.any((h) => buildHardware.toLowerCase().contains(h.toLowerCase()))) {
        return true;
      }

      if (buildFingerprint != null) {
        final fingerprintLower = buildFingerprint.toLowerCase();
        if (fingerprintLower.contains('generic') || 
            fingerprintLower.contains('unknown') ||
            fingerprintLower.contains('sdk')) {
          return true;
        }
      }
    } catch (e) {
      // Se não conseguir verificar, assume que não é emulador
      // (melhor false negative que false positive)
    }

    return false;
  }

  /// PTRZN-1520: Verifica integridade do APK (assinatura e checksum)
  static Future<bool> _checkApkIntegrity() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Verifica assinatura do APK
      final signatureResult = await _channel.invokeMethod<bool>('checkApkSignature');
      if (signatureResult == true) {
        return true; // Assinatura inválida = adulterado
      }
      
      // Verifica checksum do APK (hash do arquivo)
      final checksumResult = await _channel.invokeMethod<bool>('checkApkChecksum');
      if (checksumResult == true) {
        return true; // Checksum inválido = adulterado
      }
      
      // Verifica se debugger está conectado (indica engenharia reversa)
      final debuggerResult = await _channel.invokeMethod<bool>('checkDebugger');
      if (debuggerResult == true) {
        return true; // Debugger conectado = possível engenharia reversa
      }
      
      return false; // APK parece válido
    } catch (e) {
      // Se o método nativo não estiver disponível, retorna false
      // (assume que não está adulterado se não conseguir verificar)
      return false;
    }
  }
  
  /// Verifica se debugger está conectado (indica engenharia reversa)
  static Future<bool> checkDebugger() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('checkDebugger');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica checksum do APK para detectar modificações
  static Future<bool> checkApkChecksum() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>('checkApkChecksum');
      return result ?? false;
    } catch (e) {
      return false; // Em caso de erro, assume não adulterado
    }
  }

  /// Obtém hash SHA-256 da assinatura do APK (para configuração em produção)
  static Future<String> getApkSignatureHash() async {
    if (!Platform.isAndroid) {
      return '';
    }

    try {
      final result = await _channel.invokeMethod<String>('getApkSignatureHash');
      return result ?? '';
    } catch (e) {
      return '';
    }
  }

  /// Verifica se deve bloquear funcionalidades sensíveis
  static Future<bool> shouldBlockSensitiveFeatures() async {
    final result = await checkDeviceSecurity();
    return !result.isSecure;
  }
}
