# 🛡️ Proteção contra Descompilação e Alteração do APK

## PTRZN-1520: Proteção de Integridade do APK

Este documento descreve as proteções implementadas contra descompilação, alteração e recompilação do APK.

---

## ✅ Proteções Implementadas

### 1. **Ofuscação de Código Dart**

**Como usar:**
```bash
# Build com ofuscação Dart
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

**O que faz:**
- ✅ Ofusca nomes de classes, métodos e variáveis no código Dart
- ✅ Reduz tamanho do APK
- ✅ Dificulta engenharia reversa do código Dart
- ✅ Gera arquivos de símbolos para debug (guardar para produção!)

**Arquivos gerados:**
- `build/app/outputs/symbols/` - Arquivos de símbolos para debug
- **IMPORTANTE:** Guarde esses arquivos! Você precisará deles para fazer debug de crashes em produção.

**Scripts de build:**
- `build_release.sh` (Linux/Mac)
- `build_release.bat` (Windows)

---

### 2. **Ofuscação de Código Java/Kotlin (ProGuard/R8)**

**Arquivo:** `android/app/proguard-rules.pro`

- ✅ Minificação e ofuscação habilitadas em release
- ✅ Remoção de código não utilizado
- ✅ Ofuscação de nomes de classes e métodos
- ✅ Remoção de logs em produção
- ✅ Proteção de classes críticas de segurança

**Configuração:**
```gradle
buildTypes {
    release {
        minifyEnabled = true
        shrinkResources = true
        proguardFiles('proguard-rules.pro')
    }
}
```

---

### 3. **Verificação de Assinatura do APK**

**Implementação:** `SecurityPlugin.kt` - método `checkApkSignature()`

- ✅ Verifica se o APK está assinado
- ✅ Calcula hash SHA-256 da assinatura
- ✅ Compara com hash esperado (configurável)
- ✅ Detecta APKs não assinados ou recompilados

**Como funciona:**
1. Obtém a assinatura do APK instalado via `PackageManager`
2. Calcula hash SHA-256 da assinatura
3. Compara com hash esperado configurado
4. Retorna `true` se a assinatura não corresponder

---

### 4. **Verificação de Checksum do APK**

**Implementação:** `SecurityPlugin.kt` - método `checkApkChecksum()`

- ✅ Calcula hash SHA-256 do arquivo APK completo
- ✅ Compara com hash esperado (configurável)
- ✅ Detecta modificações no arquivo APK

**Como funciona:**
1. Obtém o caminho do arquivo APK instalado
2. Calcula hash SHA-256 de todo o arquivo
3. Compara com hash esperado configurado
4. Retorna `true` se o checksum não corresponder

---

### 5. **Detecção de Debugger**

**Implementação:** `SecurityPlugin.kt` - método `checkDebugger()`

- ✅ Detecta se debugger está conectado
- ✅ Indica possível engenharia reversa em andamento
- ✅ Executado em runtime

**Como funciona:**
- Usa `android.os.Debug.isDebuggerConnected()`
- Retorna `true` se debugger estiver conectado

---

### 6. **Verificação em Runtime**

**Implementação:** `SecurityChecker.checkDeviceSecurity()`

- ✅ Executa todas as verificações no startup do app
- ✅ Verifica assinatura, checksum e debugger
- ✅ Loga avisos de segurança
- ✅ Pode bloquear funcionalidades se adulteração for detectada

---

## 🔧 Configuração para Produção

### Passo 1: Obter Hash da Assinatura

Após assinar o APK com sua keystore de produção, execute:

```bash
# Obter hash SHA-256 da assinatura
keytool -list -v -keystore sua-keystore.jks -alias seu-alias
```

Procure por "SHA256:" na saída e copie o hash.

### Passo 2: Obter Hash do APK

Após compilar o APK de produção, execute:

```bash
# Windows PowerShell
$hash = Get-FileHash -Path "app-release.apk" -Algorithm SHA256
$hash.Hash

# Linux/Mac
sha256sum app-release.apk
```

### Passo 3: Configurar no Código

Edite `SecurityPlugin.kt` e configure os hashes:

```kotlin
// Linha ~242: Configure o hash da assinatura
val EXPECTED_SIGNATURE_HASH = "SEU_HASH_SHA256_DA_ASSINATURA_AQUI"

// Linha ~348: Configure o hash do APK
val EXPECTED_APK_HASH = "SEU_HASH_SHA256_DO_APK_AQUI"
```

### Passo 4: Testar

1. Compile o APK de produção
2. Instale e execute o app
3. O app deve funcionar normalmente
4. Tente modificar o APK e reinstalar
5. O app deve detectar a adulteração

---

## 📋 Verificação Automática de Hash

Para facilitar a configuração, você pode usar o método `getApkSignatureHash()`:

```dart
// No código Dart, durante desenvolvimento
final hash = await SecurityChecker.getApkSignatureHash();
print('Hash da assinatura: $hash');
```

Execute o app uma vez e copie o hash exibido no log.

---

## 🚨 Ações quando Adulteração é Detectada

Atualmente, o app apenas loga avisos. Em produção, considere implementar:

### Opção 1: Bloquear Funcionalidades Sensíveis

```dart
if (securityResult.isTampered) {
  // Desabilitar funcionalidades críticas
  disableSensitiveFeatures();
}
```

### Opção 2: Encerrar o App

```dart
if (securityResult.isTampered) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Aplicativo Comprometido'),
      content: Text('Este aplicativo foi modificado e não pode ser executado.'),
      actions: [
        TextButton(
          onPressed: () => SystemNavigator.pop(),
          child: Text('Sair'),
        ),
      ],
    ),
  );
}
```

### Opção 3: Enviar Alerta para Servidor

```dart
if (securityResult.isTampered) {
  await sendSecurityAlertToServer(securityResult);
}
```

---

## 🔒 Proteções Adicionais Recomendadas

### 1. **Assinatura com V2/V3 Scheme**

Certifique-se de que o APK está assinado com o scheme mais recente:

```bash
apksigner verify --verbose app-release.apk
```

### 2. **Verificação de Certificado Público**

Em vez de apenas hash, você pode verificar o certificado completo:

```kotlin
// Comparar certificado completo
val certificate = signatures[0].toByteArray()
// Comparar com certificado esperado
```

### 3. **Anti-Tampering em Múltiplos Pontos**

Adicione verificações em pontos críticos do código:

```dart
// Antes de operações sensíveis
if (await SecurityChecker.checkApkChecksum()) {
  throw SecurityException('APK foi modificado');
}
```

### 4. **Obfuscação de Strings Sensíveis**

Use ofuscação adicional para strings importantes:

```kotlin
// Em vez de strings literais, use recursos ofuscados
val secret = deobfuscate(getObfuscatedSecret())
```

---

## ⚠️ Limitações

1. **Ofuscação não é criptografia**: Código ofuscado ainda pode ser analisado, apenas fica mais difícil
2. **Verificação de hash**: Requer configuração manual dos hashes esperados
3. **Debugger**: Pode ser bypassado por ferramentas avançadas
4. **Root**: Usuários com root podem modificar verificações em runtime

**Nenhuma proteção é 100% à prova de engenharia reversa**, mas essas medidas tornam significativamente mais difícil e demorado.

---

## 📝 Checklist de Produção

- [ ] **Ofuscação Dart habilitada** (`--obfuscate` no build)
- [ ] **Arquivos de símbolos guardados** (em local seguro para debug)
- [ ] ProGuard/R8 habilitado e configurado
- [ ] APK assinado com keystore de produção
- [ ] Hash da assinatura configurado em `SecurityPlugin.kt`
- [ ] Hash do APK configurado em `SecurityPlugin.kt`
- [ ] Testado com APK original (deve funcionar)
- [ ] Testado com APK modificado (deve detectar adulteração)
- [ ] Ações de bloqueio implementadas (se necessário)
- [ ] Logs de segurança configurados para produção

---

**Data de implementação:** $(Get-Date -Format "dd/MM/yyyy HH:mm")
