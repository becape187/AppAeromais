# ProGuard Rules para AeroMais
# PTRZN-1520: Proteção contra descompilação e alteração do APK

# ============================================================
# Flutter Engine
# ============================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ============================================================
# Classes de Segurança (NÃO ofuscar - precisam ser verificadas)
# ============================================================
-keep class br.com.aeromais.app.SecurityPlugin { *; }
-keep class br.com.aeromais.app.MainActivity { *; }

# ============================================================
# Router Monitor (manter para funcionamento)
# ============================================================
-keep class com.berna.automais.aeromais.** { *; }

# ============================================================
# Ofuscação agressiva para outras classes
# ============================================================
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

# Remover logs em produção
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# ============================================================
# Proteção contra engenharia reversa
# ============================================================
# Ofuscar nomes de classes e métodos
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Não ofuscar classes nativas
-keepclasseswithmembernames class * {
    native <methods>;
}

# Manter construtores de Activities, Services, etc.
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}

-keepclassmembers class * extends android.app.Service {
    public <init>();
}

-keepclassmembers class * extends android.content.BroadcastReceiver {
    public <init>();
}

# ============================================================
# Proteção adicional
# ============================================================
# Remover informações de debug
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
