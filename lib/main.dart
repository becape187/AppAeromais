import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';
import 'router_monitor.dart';
import 'wireguard_service.dart';
// PTRZN-1517, 1518, 1520: Módulos de segurança
import 'security/security_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // PTRZN-1517, 1518, 1520: Verificar segurança do dispositivo
  final securityResult = await SecurityChecker.checkDeviceSecurity();
  if (!securityResult.isSecure) {
    debugPrint('⚠️ AVISO DE SEGURANÇA: ${securityResult.issues.join(", ")}');
    
    // PTRZN-1520: Se APK foi adulterado, considerar bloquear funcionalidades
    if (securityResult.isTampered) {
      debugPrint('🚨 APK ADULTERADO DETECTADO! O app pode ter sido modificado.');
      // Em produção, você pode querer:
      // - Bloquear funcionalidades sensíveis
      // - Encerrar o app
      // - Enviar alerta para servidor
    }
    
    // Em produção, você pode querer bloquear o app ou mostrar aviso
    // Por enquanto, apenas loga o aviso
  }
  
  // Forçar orientação paisagem
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // CONFIGURAR FULLSCREEN AGRESSIVO
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Future.delayed(const Duration(milliseconds: 100));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  await Future.delayed(const Duration(milliseconds: 100));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Inicializar monitoramento do roteador
  await RouterMonitor.restoreMonitoringState();
  
  // Inicializar conexão WireGuard automática para cpmais.local
  await WireGuardService.restoreConnectionState();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroMais',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF35006e),
          primary: const Color(0xFF35006e),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF35006e),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        useMaterial3: true,
      ),
      home: const ServerSearchScreen(),
    );
  }
}

class ServerSearchScreen extends StatefulWidget {
  const ServerSearchScreen({super.key});

  @override
  State<ServerSearchScreen> createState() => _ServerSearchScreenState();
}

class _ServerSearchScreenState extends State<ServerSearchScreen> {
  // URL padrão do servidor via Nginx
  static const String _defaultServerUrl = 'https://cpmais.aeromais.com.br';
  String statusMessage = 'Conectando ao servidor...';

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? serverUrl = prefs.getString('server_url');
      
      // Se não houver URL salva, usar a padrão do Nginx
      if (serverUrl == null || serverUrl.isEmpty) {
        serverUrl = _defaultServerUrl;
        await prefs.setString('server_url', serverUrl);
        debugPrint('Usando URL padrão do Nginx: $serverUrl');
      } else {
        debugPrint('Usando servidor salvo: $serverUrl');
      }
      
      // Normalizar URL: sempre usar domínio do Nginx e HTTPS
      final uri = Uri.parse(serverUrl);
      
      // Se for um IP (URL antiga), migrar para o domínio do Nginx
      final isIP = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host);
      if (isIP || uri.host != 'cpmais.aeromais.com.br') {
        debugPrint('URL antiga detectada (IP ou domínio diferente), migrando para domínio do Nginx');
        serverUrl = _defaultServerUrl;
        await prefs.setString('server_url', serverUrl);
      }
      
      // Garantir que sempre usa HTTPS
      if (!serverUrl.startsWith('https://')) {
        serverUrl = serverUrl.replaceFirst(RegExp(r'^https?://'), 'https://');
        await prefs.setString('server_url', serverUrl);
        debugPrint('URL corrigida para HTTPS: $serverUrl');
      }
      
      // Remover porta se especificada (Nginx usa porta 443 padrão)
      final finalUri = Uri.parse(serverUrl);
      if (finalUri.hasPort && finalUri.port != 443) {
        serverUrl = 'https://${finalUri.host}${finalUri.path}';
        await prefs.setString('server_url', serverUrl);
        debugPrint('Porta removida da URL (Nginx usa 443): $serverUrl');
      }
      
      // Garantir que não termina com barra (exceto se for apenas domínio)
      if (serverUrl.endsWith('/') && serverUrl != 'https://cpmais.aeromais.com.br/') {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
        await prefs.setString('server_url', serverUrl);
      }
      
      setState(() {
        statusMessage = 'Conectando ao servidor...';
      });
      
      // Navegar diretamente para o WebView
      if (mounted) {
        debugPrint('--> NAVEGANDO PARA A TELA WEBVIEW COM URL: $serverUrl');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WebViewApp(
              serverUrl: serverUrl!,
              serverInfo: null,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao conectar ao servidor: $e');
      setState(() {
        statusMessage = 'Erro ao conectar ao servidor.\nVerifique as configurações.';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AeroMais'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebViewApp extends StatefulWidget {
  final String serverUrl;
  final Map<String, dynamic>? serverInfo;
  
  const WebViewApp({
    super.key, 
    required this.serverUrl,
    this.serverInfo,
  });

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    
    debugPrint('Server Info recebido: ${widget.serverInfo}');
    _configureDisplayMode();
    
    debugPrint('WebViewApp - Carregando URL: ${widget.serverUrl}');
    
    // URL usando HTTPS com certificado válido do Let's Encrypt via Nginx
    final uri = Uri.parse(widget.serverUrl);
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onHttpError: (HttpResponseError error) {
            debugPrint('❌ Erro HTTP no WebView: ${error.response?.statusCode}');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ Erro de recurso no WebView: ${error.description}');
            debugPrint('   Código: ${error.errorCode}, Tipo: ${error.errorType}');
            debugPrint('   URL: ${error.url}');
            // Código -2 = SSL_ERROR, -6 = HOST_LOOKUP_ERROR, -8 = TIMEOUT
            if (error.errorCode == -2) {
              debugPrint('🚨 ERRO SSL DETECTADO');
              debugPrint('   Verifique se o certificado Let\'s Encrypt está válido');
              debugPrint('   URL com erro SSL: ${error.url}');
            }
          },
          onPageStarted: (String url) {
            debugPrint('📄 Página iniciando: $url');
          },
          onPageFinished: (String url) {
            debugPrint('✅ Página carregada: $url');
          },
        ),
      )
      ..loadRequest(uri);
  }
  
  void _configureDisplayMode() {
    // FORÇAR FULLSCREEN SEMPRE para tablets industriais
    debugPrint('🖥️ CONFIGURANDO FULLSCREEN IMERSIVO');
    
    // Método 1: Fullscreen imersivo sticky
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    
    // Método 2: Esconder barra de status e navegação
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    
    debugPrint('✅ FULLSCREEN IMERSIVO CONFIGURADO');
  }
  
  bool _shouldUseFullscreen() {
    debugPrint('=== DETECÇÃO DE FULLSCREEN ===');
    debugPrint('Server Info: ${widget.serverInfo}');
    
    // FORÇAR FULLSCREEN SEMPRE - Tablets industriais devem ser fullscreen
    debugPrint('✅ FULLSCREEN: Forçado para tablets industriais');
    return true;
  }
  
  
  void _resetApp() {
    // Garante que a UI do sistema volte ao normal
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    // Reinicia a navegação para a tela de busca
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ServerSearchScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFullscreen = _shouldUseFullscreen();
    
    return Scaffold(
      appBar: isFullscreen ? null : AppBar(
        title: Text(widget.serverInfo?['nome'] ?? 'AeroMais'),
        centerTitle: true,
        automaticallyImplyLeading: true, // Força mostrar o botão do menu
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: isFullscreen ? null : _buildDrawer(),
      body: Stack(
        children: [
          WebViewWidget(
            controller: controller,
          ),
          // Botão de configurações flutuante para fullscreen
          if (isFullscreen)
            Positioned(
              bottom: 20,
              left: 20,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
                child: const Icon(Icons.settings),
              ),
            ),
        ],
      ),
    );
  }
  
  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'AeroMais Menu',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context); // Fecha o drawer
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Limpar Cache e Reiniciar'),
            onTap: () async {
              Navigator.pop(context); // Fecha o drawer
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('server_url');
              debugPrint('Configurações salvas limpas');
              _resetApp();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Sair'),
            onTap: () {
              SystemNavigator.pop(); // Fecha o aplicativo
            },
          ),
        ],
      ),
    );
  }
}
