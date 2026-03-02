package br.com.aeromais.app

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Plugin nativo para verificação de segurança do dispositivo Android.
 * 
 * PTRZN-1517: Detecção de root
 * PTRZN-1518: Detecção de emulador
 * PTRZN-1520: Verificação de integridade do APK
 */
class SecurityPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "br.com.aeromais.app/security")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkRoot" -> {
                result.success(checkRoot())
            }
            "checkEmulator" -> {
                result.success(checkEmulator())
            }
            "checkApkSignature" -> {
                result.success(checkApkSignature())
            }
            "getBuildModel" -> {
                result.success(Build.MODEL)
            }
            "getBuildManufacturer" -> {
                result.success(Build.MANUFACTURER)
            }
            "getBuildHardware" -> {
                result.success(Build.HARDWARE)
            }
            "getBuildFingerprint" -> {
                result.success(Build.FINGERPRINT)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * PTRZN-1517: Verifica se o dispositivo está rooteado
     */
    private fun checkRoot(): Boolean {
        val rootIndicators = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/xbin/daemonsu",
            "/system/etc/init.d/99SuperSUDaemon",
            "/dev/com.koushikdutta.superuser.daemon/",
            "/system/xbin/busybox",
            "/system/bin/busybox",
            "/data/local/busybox",
            "/data/local/tmp/busybox",
            "/system/sd/xbin/busybox",
            "/system/bin/failsafe/busybox",
            "/data/local/tmp/busybox"
        )

        // Verifica arquivos de root
        for (path in rootIndicators) {
            if (File(path).exists()) {
                return true
            }
        }

        // Verifica se o comando 'su' está disponível
        try {
            val process = Runtime.getRuntime().exec("su")
            process.outputStream.close()
            process.waitFor()
            return true
        } catch (e: Exception) {
            // Se não conseguir executar 'su', provavelmente não está rooteado
        }

        // Verifica propriedades do sistema
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        return false
    }

    /**
     * PTRZN-1518: Verifica se está rodando em emulador
     */
    private fun checkEmulator(): Boolean {
        val buildModel = Build.MODEL.toLowerCase()
        val buildManufacturer = Build.MANUFACTURER.toLowerCase()
        val buildHardware = Build.HARDWARE.toLowerCase()
        val buildFingerprint = Build.FINGERPRINT.toLowerCase()
        val buildProduct = Build.PRODUCT.toLowerCase()
        val buildDevice = Build.DEVICE.toLowerCase()
        val buildBrand = Build.BRAND.toLowerCase()

        // Lista de indicadores de emulador
        val emulatorModels = arrayOf("sdk", "google_sdk", "emulator", "android sdk", "droid4x", "genymotion")
        val emulatorManufacturers = arrayOf("genymotion", "unknown", "google")
        val emulatorHardware = arrayOf("goldfish", "ranchu", "vbox86", "generic")
        val emulatorProducts = arrayOf("sdk", "google_sdk", "emulator", "sdk_google", "sdk_x86")
        val emulatorDevices = arrayOf("generic", "generic_x86", "generic_x86_64", "sdk", "sdk_google", "sdk_x86")
        val emulatorBrands = arrayOf("generic", "unknown", "google")

        // Verifica modelo
        if (emulatorModels.any { buildModel.contains(it) }) {
            return true
        }

        // Verifica fabricante
        if (emulatorManufacturers.any { buildManufacturer.contains(it) }) {
            return true
        }

        // Verifica hardware
        if (emulatorHardware.any { buildHardware.contains(it) }) {
            return true
        }

        // Verifica fingerprint
        if (buildFingerprint.contains("generic") || 
            buildFingerprint.contains("unknown") ||
            buildFingerprint.contains("sdk") ||
            buildFingerprint.contains("test-keys")) {
            return true
        }

        // Verifica product
        if (emulatorProducts.any { buildProduct.contains(it) }) {
            return true
        }

        // Verifica device
        if (emulatorDevices.any { buildDevice.contains(it) }) {
            return true
        }

        // Verifica brand
        if (emulatorBrands.any { buildBrand.contains(it) }) {
            return true
        }

        // Verifica características específicas de emuladores
        if (Build.FINGERPRINT.startsWith("generic") ||
            Build.FINGERPRINT.startsWith("unknown") ||
            Build.MODEL.contains("google_sdk") ||
            Build.MODEL.contains("Emulator") ||
            Build.MODEL.contains("Android SDK built for x86") ||
            Build.MANUFACTURER.contains("Genymotion") ||
            Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic") ||
            "google_sdk" == Build.PRODUCT) {
            return true
        }

        return false
    }

    /**
     * PTRZN-1520: Verifica integridade do APK (assinatura)
     */
    private fun checkApkSignature(): Boolean {
        val ctx = context ?: return false
        
        try {
            val packageManager = ctx.packageManager
            val packageName = ctx.packageName
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
            }

            // Verifica se o app foi assinado
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signingInfo = packageInfo.signingInfo
                if (signingInfo == null || signingInfo.apkContentsSigners.isEmpty()) {
                    return true // APK não assinado = adulterado
                }
            } else {
                @Suppress("DEPRECATION")
                val signatures = packageInfo.signatures
                if (signatures == null || signatures.isEmpty()) {
                    return true // APK não assinado = adulterado
                }
            }

            // Em produção, você deve verificar se a assinatura corresponde
            // à keystore esperada. Por enquanto, apenas verifica se está assinado.
            // TODO: Implementar verificação de assinatura específica
            
            return false // APK parece válido
        } catch (e: Exception) {
            // Se não conseguir verificar, assume adulterado por precaução
            return true
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
