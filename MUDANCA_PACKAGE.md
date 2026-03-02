# 📦 Mudança de Package Name - Android

## Alteração Realizada

**Package antigo:** `com.example.appaeromais`  
**Package novo:** `br.com.aeromais.app`

---

## Arquivos Modificados

### 1. Configuração do Build
- ✅ `android/app/build.gradle`
  - `namespace`: `com.example.appaeromais` → `br.com.aeromais.app`
  - `applicationId`: `com.example.appaeromais` → `br.com.aeromais.app`

### 2. Arquivos Kotlin/Java
- ✅ `android/app/src/main/kotlin/br/com/aeromais/app/MainActivity.kt`
  - Package: `br.com.aeromais.app`
  - Import atualizado: `import br.com.aeromais.app.SecurityPlugin`

- ✅ `android/app/src/main/java/br/com/aeromais/app/SecurityPlugin.kt`
  - Package: `br.com.aeromais.app`
  - Channel name: `br.com.aeromais.app/security`

- ✅ `android/app/src/main/java/com/berna/automais/aeromais/RouterMonitorService.java`
  - Referência atualizada: `br.com.aeromais.app.MainActivity`

### 3. Arquivos Dart
- ✅ `lib/security/security_checker.dart`
  - Channel name: `br.com.aeromais.app/security`

### 4. Estrutura de Diretórios
- ✅ Arquivos movidos de:
  - `java/com/example/appaeromais/` → `java/br/com/aeromais/app/`
  - `kotlin/com/example/appaeromais/` → `kotlin/br/com/aeromais/app/`

---

## Próximos Passos

1. **Limpar build cache:**
   ```bash
   cd appaeromais
   flutter clean
   ```

2. **Recompilar o projeto:**
   ```bash
   flutter pub get
   flutter build apk
   ```

3. **Verificar se tudo está funcionando:**
   - Os arquivos em `build/` serão regenerados automaticamente com o novo package name
   - Testar a instalação do APK em um dispositivo

---

## Notas Importantes

- ⚠️ **Desinstalar versão antiga:** Se o app já estiver instalado com o package antigo, será necessário desinstalá-lo antes de instalar a nova versão (package names diferentes são tratados como apps diferentes)
- ✅ **AndroidManifest.xml:** Usa `.MainActivity` (relativo), então não precisa de alteração
- ✅ **Arquivos em build/:** Serão regenerados automaticamente na próxima compilação

---

**Data da alteração:** $(Get-Date -Format "dd/MM/yyyy HH:mm")
