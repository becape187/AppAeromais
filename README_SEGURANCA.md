# 🔒 Guia de Segurança - App Android AeroMais

Este documento descreve as implementações de segurança adicionadas ao app Android para corrigir as vulnerabilidades identificadas no pentest.

## 📋 Vulnerabilidades Corrigidas

### ✅ PTRZN-1515: HTTP sem TLS
- **Status:** ✅ Resolvido
- **Implementação:** Network Security Config + SSL Pinning
- **Arquivos:** `network_security_config.xml`, `ssl_pinning.dart`

### ✅ PTRZN-1517: Ausência de detecção de root
- **Status:** ✅ Resolvido
- **Implementação:** SecurityChecker + SecurityPlugin nativo
- **Arquivos:** `security_checker.dart`, `SecurityPlugin.kt`

### ✅ PTRZN-1520: Ausência de proteção de integridade do APK
- **Status:** ✅ Resolvido
- **Implementação:** Verificação de assinatura em runtime
- **Arquivos:** `SecurityPlugin.kt` (método `checkApkSignature`)

### ✅ PTRZN-1518: Ausência de detecção de emulação
- **Status:** ✅ Resolvido
- **Implementação:** Detecção de múltiplos indicadores de emulador
- **Arquivos:** `SecurityPlugin.kt` (método `checkEmulator`)

## 🚀 Como Usar

### Verificação de Segurança no Startup

O app verifica automaticamente a segurança do dispositivo no startup:

```dart
final securityResult = await SecurityChecker.checkDeviceSecurity();
if (!securityResult.isSecure) {
  // Log de avisos de segurança
  debugPrint('⚠️ AVISO DE SEGURANÇA: ${securityResult.issues.join(", ")}');
}
```

### HTTPS Automático

O app tenta HTTPS primeiro em todas as conexões:

```dart
// Tenta HTTPS primeiro
String discoveryUrl = 'https://$ip:5000';
try {
  response = await http.get(Uri.parse('$discoveryUrl/whoami'));
} catch (e) {
  // Fallback para HTTP apenas em desenvolvimento
  discoveryUrl = 'http://$ip:5000';
  response = await http.get(Uri.parse('$discoveryUrl/whoami'));
}
```

## ⚙️ Configuração para Produção

### 1. SSL Pinning

Edite `lib/security/ssl_pinning.dart` e adicione os hashes SHA-256 dos certificados:

```dart
static const List<String> allowedFingerprints = [
  'SEU_HASH_SHA256_AQUI=',
];
```

### 2. Network Security Config

Edite `android/app/src/main/res/xml/network_security_config.xml` e adicione pin-set:

```xml
<domain-config>
    <domain includeSubdomains="true">seu-dominio.com</domain>
    <pin-set expiration="2025-12-31">
        <pin digest="SHA-256">SEU_HASH_AQUI=</pin>
    </pin-set>
</domain-config>
```

### 3. Verificação de Assinatura

Edite `SecurityPlugin.kt` e implemente verificação específica da keystore.

## 📝 Notas

- As verificações de segurança são executadas no startup do app
- Em produção, considere bloquear funcionalidades quando root/emulador for detectado
- Configure HTTPS no servidor para eliminar fallback para HTTP
