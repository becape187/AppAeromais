package br.com.aeromais.app

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.security.NoSuchAlgorithmException

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
            "checkApkChecksum" -> {
                result.success(checkApkChecksum())
            }
            "checkDebugger" -> {
                result.success(checkDebugger())
            }
            "getApkSignatureHash" -> {
                result.success(getApkSignatureHash())
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
     * 
     * Verifica se o APK foi assinado e se a assinatura corresponde à esperada.
     * Em produção, configure EXPECTED_SIGNATURE_HASH com o hash SHA-256 da sua keystore.
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
            val signatures: Array<Signature>
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signingInfo = packageInfo.signingInfo
                if (signingInfo == null || signingInfo.apkContentsSigners.isEmpty()) {
                    return true // APK não assinado = adulterado
                }
                signatures = signingInfo.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                val sigs = packageInfo.signatures
                if (sigs == null || sigs.isEmpty()) {
                    return true // APK não assinado = adulterado
                }
                signatures = sigs
            }

            // Calcula hash SHA-256 da primeira assinatura
            val signatureHash = getSignatureHash(signatures[0])
            
            // TODO: Em produção, substituir pelo hash esperado da sua keystore
            // Para obter o hash: keytool -list -v -keystore sua-keystore.jks
            val EXPECTED_SIGNATURE_HASH = "" // Configure em produção
            
            // Se não há hash esperado configurado, apenas verifica se está assinado
            if (EXPECTED_SIGNATURE_HASH.isEmpty()) {
                return false // APK está assinado, mas não há verificação específica
            }
            
            // Compara com hash esperado
            return signatureHash != EXPECTED_SIGNATURE_HASH
            
        } catch (e: Exception) {
            // Se não conseguir verificar, assume adulterado por precaução
            return true
        }
    }
    
    /**
     * Calcula hash SHA-256 de uma assinatura
     */
    private fun getSignatureHash(signature: Signature): String {
        return try {
            val md = MessageDigest.getInstance("SHA-256")
            val hashBytes = md.digest(signature.toByteArray())
            hashBytes.joinToString("") { "%02x".format(it) }
        } catch (e: NoSuchAlgorithmException) {
            ""
        }
    }
    
    /**
     * Retorna o hash SHA-256 da assinatura atual (para configuração)
     */
    private fun getApkSignatureHash(): String {
        val ctx = context ?: return ""
        
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

            val signatures: Array<Signature>
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signingInfo = packageInfo.signingInfo
                if (signingInfo == null || signingInfo.apkContentsSigners.isEmpty()) {
                    return ""
                }
                signatures = signingInfo.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                val sigs = packageInfo.signatures
                if (sigs == null || sigs.isEmpty()) {
                    return ""
                }
                signatures = sigs
            }

            return getSignatureHash(signatures[0])
        } catch (e: Exception) {
            return ""
        }
    }
    
    /**
     * Verifica checksum do APK para detectar modificações
     */
    private fun checkApkChecksum(): Boolean {
        val ctx = context ?: return true
        
        try {
            val packageManager = ctx.packageManager
            val packageName = ctx.packageName
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            
            // Obtém caminho do APK
            val apkPath = packageInfo.applicationInfo.sourceDir
            val apkFile = File(apkPath)
            
            if (!apkFile.exists()) {
                return true // APK não encontrado = suspeito
            }
            
            // Calcula hash SHA-256 do arquivo APK
            val md = MessageDigest.getInstance("SHA-256")
            val fis = java.io.FileInputStream(apkFile)
            val buffer = ByteArray(8192)
            var bytesRead: Int
            
            while (fis.read(buffer).also { bytesRead = it } != -1) {
                md.update(buffer, 0, bytesRead)
            }
            fis.close()
            
            val apkHash = md.digest().joinToString("") { "%02x".format(it) }
            
            // TODO: Em produção, configure EXPECTED_APK_HASH com o hash do APK original
            val EXPECTED_APK_HASH = "" // Configure em produção
            
            // Se não há hash esperado, retorna false (não detectou adulteração)
            if (EXPECTED_APK_HASH.isEmpty()) {
                return false
            }
            
            // Compara com hash esperado
            return apkHash != EXPECTED_APK_HASH
            
        } catch (e: Exception) {
            return true // Em caso de erro, assume adulterado
        }
    }
    
    /**
     * Verifica se debugger está conectado (indica engenharia reversa)
     */
    private fun checkDebugger(): Boolean {
        return android.os.Debug.isDebuggerConnected()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
