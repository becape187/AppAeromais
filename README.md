# AeroMais - App Flutter

Aplicativo Flutter para o sistema AeroMais.

## 🛡️ Proteções de Segurança Implementadas

Este projeto inclui várias camadas de proteção contra engenharia reversa e adulteração:

| Proteção | Status | Documentação |
|----------|--------|---------------|
| **Ofuscação Dart** | ✅ | `PROTECAO_APK.md` |
| **Ofuscação Java/Kotlin (ProGuard/R8)** | ✅ | `PROTECAO_APK.md` |
| **Anti-tampering (Verificação de assinatura)** | ✅ | `PROTECAO_APK.md` |
| **Certificate Pinning (SSL)** | ✅ | `README_SEGURANCA.md` |
| **Detecção de Root** | ✅ | `CORRECOES_SEGURANCA_ANDROID.md` |
| **Detecção de Emulador** | ✅ | `CORRECOES_SEGURANCA_ANDROID.md` |

📖 **Documentação completa:** Veja `STATUS_PROTECAO.md` para detalhes.

---

## 🚀 Build de Produção

### Build com todas as proteções habilitadas:

**Windows:**
```bash
build_release.bat
```

**Linux/Mac:**
```bash
chmod +x build_release.sh
./build_release.sh
```

**Manual:**
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

⚠️ **IMPORTANTE:** Guarde os arquivos em `build/app/outputs/symbols/` para debug de crashes em produção!

---

## 📚 Documentação

- `PROTECAO_APK.md` - Proteções contra descompilação e alteração
- `STATUS_PROTECAO.md` - Status de todas as proteções
- `CORRECOES_SEGURANCA_ANDROID.md` - Correções de segurança Android
- `README_SEGURANCA.md` - Guia de segurança
- `MUDANCA_PACKAGE.md` - Mudança de package name

---

## 🔧 Desenvolvimento

```bash
# Instalar dependências
flutter pub get

# Executar em modo debug
flutter run

# Build de release (sem ofuscação, para testes)
flutter build apk --release
```

---

## 📖 Recursos Flutter

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Documentação Flutter](https://docs.flutter.dev/)
