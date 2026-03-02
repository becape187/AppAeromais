@echo off
REM Script para build de release com todas as proteções habilitadas
REM PTRZN-1520: Ofuscação Dart + Java

echo 🔨 Building AeroMais APK com proteções de segurança...

REM Limpar build anterior
echo 🧹 Limpando build anterior...
flutter clean

REM Obter dependências
echo 📦 Obtendo dependências...
flutter pub get

REM Build com ofuscação Dart e Java
echo 🔒 Building APK com ofuscação...
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

if %ERRORLEVEL% EQU 0 (
    echo ✅ Build concluído com sucesso!
    echo 📱 APK: build/app/outputs/flutter-apk/app-release.apk
    echo 🗺️  Símbolos: build/app/outputs/symbols/
    echo.
    echo ⚠️  IMPORTANTE: Guarde os arquivos em build/app/outputs/symbols/ para debug!
) else (
    echo ❌ Erro no build!
    exit /b 1
)
