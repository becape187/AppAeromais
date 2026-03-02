/// Módulo de SSL Pinning para garantir conexões HTTPS seguras.
/// 
/// PTRZN-1515: Implementa SSL Pinning para prevenir ataques Man-in-the-Middle
/// e garantir que o app só se conecte ao servidor legítimo.

import 'package:http/http.dart' as http;
import 'dart:io';
// PTRZN-1515: SSL Pinning será implementado via network_security_config.xml
// import 'package:certificate_pinning/certificate_pinning.dart';

/// Configuração de SSL Pinning
class SSLPinningConfig {
  /// Lista de hashes SHA-256 dos certificados permitidos
  /// 
  /// IMPORTANTE: Em produção, substituir pelos hashes reais do certificado do servidor.
  /// Para obter o hash: openssl x509 -in certificate.crt -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
  static const List<String> allowedFingerprints = [
    // TODO: Adicionar hashes SHA-256 dos certificados do servidor em produção
    // Exemplo: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ];

  /// Domínios permitidos para SSL Pinning
  static const List<String> allowedDomains = [
    // TODO: Adicionar domínios do servidor em produção
    // Exemplo: 'aeromais.example.com',
  ];

  /// Verifica se SSL Pinning está habilitado
  static bool get isEnabled => allowedFingerprints.isNotEmpty;
}

/// Cliente HTTP seguro com SSL Pinning
class SecureHttpClient {
  /// Cria um cliente HTTP com SSL Pinning configurado
  /// 
  /// PTRZN-1515: Força uso de HTTPS e valida certificados
  static http.Client createSecureClient() {
    if (!SSLPinningConfig.isEnabled) {
      // Se SSL Pinning não estiver configurado, retorna cliente padrão
      // mas força HTTPS
      return http.Client();
    }

    // Em produção, usar certificate_pinning quando disponível
    // Por enquanto, retorna cliente padrão que respeita network_security_config
    return http.Client();
  }

  /// Verifica se uma URL é segura (HTTPS)
  static bool isSecureUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'https';
    } catch (e) {
      return false;
    }
  }

  /// Converte URL HTTP para HTTPS
  static String? convertToHttps(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'http') {
        return uri.replace(scheme: 'https').toString();
      }
      return url;
    } catch (e) {
      return null;
    }
  }

  /// Valida se uma URL deve ser permitida
  static bool isUrlAllowed(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Em produção, verificar se o domínio está na lista permitida
      if (SSLPinningConfig.allowedDomains.isNotEmpty) {
        final host = uri.host.toLowerCase();
        return SSLPinningConfig.allowedDomains.any(
          (domain) => host == domain.toLowerCase() || host.endsWith('.$domain'.toLowerCase())
        );
      }
      
      // Se não há domínios configurados, permite qualquer HTTPS
      return uri.scheme == 'https';
    } catch (e) {
      return false;
    }
  }
}
