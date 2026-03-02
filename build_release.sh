#!/bin/bash
# Script para build de release com todas as proteções habilitadas
# PTRZN-1520: Ofuscação Dart + Java

echo "🔨 Building AeroMais APK com proteções de segurança..."

# Limpar build anterior
echo "🧹 Limpando build anterior..."
flutter clean

# Obter dependências
echo "📦 Obtendo dependências..."
flutter pub get

# Build com ofuscação Dart e Java
echo "🔒 Building APK com ofuscação..."
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols

if [ $? -eq 0 ]; then
    echo "✅ Build concluído com sucesso!"
    echo "📱 APK: build/app/outputs/flutter-apk/app-release.apk"
    echo "🗺️  Símbolos: build/app/outputs/symbols/"
    echo ""
    echo "⚠️  IMPORTANTE: Guarde os arquivos em build/app/outputs/symbols/ para debug!"
else
    echo "❌ Erro no build!"
    exit 1
fi
