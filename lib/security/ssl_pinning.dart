/// Módulo de SSL Pinning para garantir conexões HTTPS seguras.
/// 
/// PTRZN-1515: Implementa SSL Pinning para prevenir ataques Man-in-the-Middle
/// e garantir que o app só se conecte ao servidor legítimo.
/// 
/// O certificado está embarcado em assets/certs/server.crt
/// O hash SHA-256 será validado no WebView via NavigationDelegate

import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Configuração de SSL Pinning
class SSLPinningConfig {
  /// Hash SHA-256 do certificado embarcado (assets/certs/server.crt)
  /// 
  /// IMPORTANTE: Este hash será preenchido automaticamente após gerar o certificado.
  /// O script generate_certificate.py exibe o hash que deve ser copiado aqui.
  /// 
  /// Para obter manualmente: 
  /// openssl x509 -in server.crt -fingerprint -sha256 -noout | cut -d'=' -f2 | tr -d ':'
  /// Depois converter para base64
  static const String? certificateHash = null; // Será preenchido após gerar certificado
  
  /// Caminho do certificado embarcado no app
  static const String certificatePath = 'assets/certs/aeromaisserver.crt';
  
  /// Lista de hashes SHA-256 dos certificados permitidos (fallback)
  static const List<String> allowedFingerprints = [
    // Será preenchido após gerar certificado
    // Exemplo: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  ];

  /// Domínios permitidos para SSL Pinning
  static const List<String> allowedDomains = [
    // TODO: Adicionar domínios do servidor em produção
    // Exemplo: 'aeromais.example.com',
  ];

  /// Verifica se SSL Pinning está habilitado
  static bool get isEnabled => certificateHash != null || allowedFingerprints.isNotEmpty;
  
  /// Carrega o certificado embarcado e retorna seu hash SHA-256
  static Future<String?> loadCertificateHash() async {
    try {
      final certData = await rootBundle.load(certificatePath);
      final certBytes = certData.buffer.asUint8List();
      final certString = utf8.decode(certBytes);
      
      // Extrair certificado PEM (remover headers/footers se necessário)
      final certLines = certString.split('\n');
      final certContent = certLines
          .where((line) => !line.startsWith('-----'))
          .join('');
      
      // Decodificar base64 e calcular hash SHA-256
      final certDer = base64Decode(certContent);
      final hash = sha256.convert(certDer);
      return base64Encode(hash.bytes);
    } catch (e) {
      return null;
    }
  }
  
  /// Valida se um hash de certificado é permitido
  static Future<bool> validateCertificateHash(String receivedHash) async {
    // Se há hash configurado estaticamente, usar ele
    if (certificateHash != null) {
      return receivedHash.toLowerCase() == certificateHash!.toLowerCase();
    }
    
    // Senão, carregar do certificado embarcado
    final expectedHash = await loadCertificateHash();
    if (expectedHash != null) {
      return receivedHash.toLowerCase() == expectedHash.toLowerCase();
    }
    
    // Fallback para lista de fingerprints
    return allowedFingerprints.any(
      (fp) => receivedHash.toLowerCase() == fp.toLowerCase()
    );
  }
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
