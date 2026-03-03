import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'settings_screen.dart';
import 'router_monitor.dart';
// PTRZN-1517, 1518, 1520: Módulos de segurança
import 'security/security_checker.dart';
import 'security/ssl_pinning.dart';

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
  final AppSettings _appSettings = AppSettings();
  bool isSearching = false;
  String? serverUrl;
  Map<String, dynamic>? _serverInfo;
  String statusMessage = 'Verificando servidor anterior...';
  List<NetworkInterface> interfaces = [];
  NetworkInterface? selectedInterface;
  bool showInterfaceList = false;
  bool isCancelled = false;
  int _pingTimeout = 500;
  int _httpTimeout = 1000;
  Timer? _interfaceUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndStart();
  }

  @override
  void dispose() {
    debugPrint('🛑 DISPOSE - Cancelando timer de interfaces');
    _interfaceUpdateTimer?.cancel();
    _interfaceUpdateTimer = null;
    super.dispose();
  }

  Future<void> _loadSettingsAndStart() async {
    _pingTimeout = await _appSettings.getPingTimeout();
    _httpTimeout = await _appSettings.getHttpTimeout();
    await checkSavedServer();
  }

  Future<void> checkSavedServer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_url');
      
      if (savedUrl != null) {
        setState(() {
          statusMessage = 'Tentando conectar ao servidor anterior...';
        });
        
        try {
          final savedUri = Uri.parse(savedUrl);
          final savedIp = savedUri.host;
          
          // PTRZN-1515: Tentar HTTPS primeiro, fallback para HTTP apenas em desenvolvimento
          String discoveryUrl = 'https://$savedIp:5000';
          if (!SecureHttpClient.isSecureUrl(savedUrl)) {
            // Se a URL salva é HTTP, tentar HTTPS primeiro
            final httpsUrl = SecureHttpClient.convertToHttps(savedUrl);
            if (httpsUrl != null) {
              discoveryUrl = 'https://${Uri.parse(httpsUrl).host}:5000';
            } else {
              discoveryUrl = 'http://$savedIp:5000';
              debugPrint('⚠️ AVISO: Usando HTTP (não seguro). Configure HTTPS no servidor.');
            }
          }
          
          debugPrint('Verificando servidor salvo no IP: $savedIp (porta de descoberta 5000)');

          http.Response? response;
          try {
            response = await http.get(
              Uri.parse('$discoveryUrl/whoami'),
            ).timeout(Duration(milliseconds: _httpTimeout));
          } catch (e) {
            // Se HTTPS falhar, tentar HTTP apenas em desenvolvimento
            if (discoveryUrl.startsWith('https://')) {
              debugPrint('HTTPS falhou, tentando HTTP: $e');
              discoveryUrl = 'http://$savedIp:5000';
              response = await http.get(
                Uri.parse('$discoveryUrl/whoami'),
              ).timeout(Duration(milliseconds: _httpTimeout));
            } else {
              rethrow;
            }
          }

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['modelo'] == 'AeroMais Server') {
              String finalUrl = savedUrl; 
              debugPrint('URL salva: $savedUrl');
              debugPrint('Resposta do servidor: $data');
              
              if (data.containsKey('url') && data['url'] != null && data['url'].toString().isNotEmpty) {
                finalUrl = data['url'].toString();
                debugPrint('URL retornada pelo servidor: $finalUrl');
              } else {
                debugPrint('Servidor não retornou URL customizada, usando URL salva: $finalUrl');
              }
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('server_url', finalUrl);
              debugPrint('Nova URL salva: $finalUrl');
              
              if (mounted) {
                debugPrint('--> NAVEGANDO PARA A TELA WEBVIEW COM URL: $finalUrl');
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => WebViewApp(
                      serverUrl: finalUrl,
                      serverInfo: data,
                    ),
                  ),
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('Erro ao tentar servidor anterior: $e');
        }
        
        if (mounted) {
          setState(() {
            statusMessage = 'Não foi possível conectar ao servidor anterior.\nDeseja tentar novamente ou fazer nova busca?';
          });
        }
      } else {
        startNewSearch();
      }
    } catch (e) {
      debugPrint('Erro ao verificar servidor salvo: $e');
      startNewSearch();
    }
  }

  void startNewSearch() {
    setState(() {
      showInterfaceList = true;
      statusMessage = 'Selecione uma interface para procurar o servidor';
    });
    
    // FORÇAR CARREGAMENTO INICIAL
    loadInterfaces();
    
    // CANCELAR TIMER ANTERIOR E CRIAR NOVO
    _interfaceUpdateTimer?.cancel();
    _interfaceUpdateTimer = null;
    
    // INICIAR NOVO TIMER FORÇADAMENTE
    _startInterfaceUpdateTimer();
    
    debugPrint('🎯 startNewSearch EXECUTADO - Timer: ${_interfaceUpdateTimer != null}');
  }

  Future<void> loadInterfaces() async {
    try {
      final List<NetworkInterface> availableInterfaces = await NetworkInterface.list();
      
      // DEBUG: Mostrar TODAS as interfaces encontradas
      debugPrint('🔍 TODAS AS INTERFACES ENCONTRADAS:');
      for (var interface in availableInterfaces) {
        debugPrint('  - ${interface.name}');
      }
      
      // FILTRO SUPER SIMPLES E RIGOROSO
      List<NetworkInterface> filteredInterfaces = [];
      
      for (var interface in availableInterfaces) {
        String name = interface.name;
        debugPrint('🔍 Verificando interface: $name');
        
        if (name == 'wlan0') {
          debugPrint('✅ WLAN0 ENCONTRADO - ADICIONANDO');
          filteredInterfaces.add(interface);
        } else if (name == 'swlan0') {
          debugPrint('✅ SWLAN0 ENCONTRADO - ADICIONANDO');
          filteredInterfaces.add(interface);
        } else {
          debugPrint('❌ $name - IGNORANDO');
        }
      }
      
      setState(() {
        interfaces = filteredInterfaces;
      });
      
      debugPrint('🎯 INTERFACES FILTRADAS: ${interfaces.map((i) => i.name).toList()}');
      
      // Iniciar timer de atualização se ainda não estiver rodando
      if (_interfaceUpdateTimer == null && showInterfaceList) {
        _startInterfaceUpdateTimer();
      }
    } catch (e) {
      debugPrint('Erro ao carregar interfaces: $e');
      setState(() {
        statusMessage = 'Erro ao carregar interfaces de rede';
      });
    }
  }

  void _startInterfaceUpdateTimer() {
    debugPrint('🚀 INICIANDO TIMER DE ATUALIZAÇÃO - a cada 1 segundo');
    _interfaceUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (showInterfaceList && mounted) {
        debugPrint('🔄 Timer executando - atualizando lista de interfaces...');
        _forceReloadInterfaces();
      } else {
        debugPrint('⏹️ Parando timer - showInterfaceList: $showInterfaceList, mounted: $mounted');
        timer.cancel();
        _interfaceUpdateTimer = null;
      }
    });
  }
  
  void _forceReloadInterfaces() {
    debugPrint('💀 FORÇA BRUTA - Recarregando interfaces');
    NetworkInterface.list().then((allInterfaces) {
      List<NetworkInterface> found = [];
      
      for (var iface in allInterfaces) {
        if (iface.name == 'wlan0' || iface.name == 'swlan0') {
          found.add(iface);
          debugPrint('💚 ENCONTRADO: ${iface.name}');
        } else {
          debugPrint('💔 IGNORADO: ${iface.name}');
        }
      }
      
      if (mounted) {
        setState(() {
          interfaces = found;
        });
        debugPrint('🎯 LISTA ATUALIZADA: ${found.map((i) => i.name).toList()}');
      }
    });
  }

  Future<bool> pingHost(String host) async {
    try {
      final socket = await Socket.connect(host, 5000, 
        timeout: Duration(milliseconds: 2000)); // 2 segundos
      await socket.close();
      return true;
    } catch (e) {
      return false; // Não logar para não poluir com 254 falhas
    }
  }

  Future<void> searchForServer() async {
    if (selectedInterface == null) return;
    
    setState(() {
      isSearching = true;
      isCancelled = false;
      statusMessage = 'Procurando servidor...';
    });

    try {
      final ipv4Address = selectedInterface!.addresses
          .firstWhere((addr) => addr.type == InternetAddressType.IPv4);
      final parts = ipv4Address.address.split('.');
      final baseIp = '${parts[0]}.${parts[1]}.${parts[2]}';

      debugPrint('Procurando na rede: $baseIp.* com varredura paralela');

      // Criar lista de IPs para testar
      List<String> ipsToTest = [];
      for (int i = 1; i <= 254; i++) {
        ipsToTest.add('$baseIp.$i');
      }

      // Dividir em lotes de 50 para não sobrecarregar
      const int batchSize = 50;
      int testedCount = 0;
      
      for (int batchStart = 0; batchStart < ipsToTest.length; batchStart += batchSize) {
        if (!mounted || isCancelled) return;
        
        int batchEnd = math.min(batchStart + batchSize, ipsToTest.length);
        List<String> batch = ipsToTest.sublist(batchStart, batchEnd);
        
        setState(() {
          statusMessage = 'Procurando servidor...\nLote ${(batchStart ~/ batchSize) + 1}/6\nTestando ${batch.length} IPs simultaneamente...';
        });
        
        debugPrint('🚀 Testando lote ${(batchStart ~/ batchSize) + 1}: IPs ${batchStart + 1}-${batchEnd}');
        
        // Testar todos os IPs do lote em paralelo
        List<Future<bool>> pingFutures = batch.map((ip) => pingHost(ip)).toList();
        List<bool> results = await Future.wait(pingFutures);
        
        // Verificar quais IPs responderam
        List<String> responsiveIPs = [];
        for (int i = 0; i < batch.length; i++) {
          if (results[i]) {
            responsiveIPs.add(batch[i]);
            debugPrint('✅ IP responsivo: ${batch[i]}');
          }
        }
        
        testedCount += batch.length;
        debugPrint('📊 Lote concluído: ${responsiveIPs.length}/${batch.length} IPs responsivos');
        
        // Testar HTTP nos IPs que responderam ao ping
        for (String ip in responsiveIPs) {
          if (!mounted || isCancelled) return;
          
          setState(() {
            statusMessage = 'Servidor encontrado em $ip\nVerificando compatibilidade...';
          });
          
          try {
            // PTRZN-1515: Tentar HTTPS primeiro
            String discoveryUrl = 'https://$ip:5000';
            http.Response? response;
            
            try {
              response = await http.get(
                Uri.parse('$discoveryUrl/whoami'),
              ).timeout(Duration(milliseconds: _httpTimeout));
            } catch (e) {
              // Se HTTPS falhar, tentar HTTP apenas em desenvolvimento
              debugPrint('HTTPS falhou para $ip, tentando HTTP: $e');
              discoveryUrl = 'http://$ip:5000';
              response = await http.get(
                Uri.parse('$discoveryUrl/whoami'),
              ).timeout(Duration(milliseconds: _httpTimeout));
            }

            if (response != null) {
              debugPrint('Resposta de $ip: ${response.statusCode} - ${response.body}');

              if (response.statusCode == 200) {
              final data = json.decode(response.body);
              if (data['modelo'] == 'AeroMais Server') {
                // PTRZN-1515: Usar HTTPS se disponível, senão HTTP (com aviso)
                String finalUrl = discoveryUrl.startsWith('https://') 
                    ? 'https://$ip:5000' 
                    : 'http://$ip:5000';
                
                if (!finalUrl.startsWith('https://')) {
                  debugPrint('⚠️ AVISO: Servidor usando HTTP (não seguro). Configure HTTPS.');
                }
                debugPrint('URL padrão: $finalUrl');
                debugPrint('Resposta do servidor: $data');
                debugPrint('Propriedade display: ${data['display']}');
                debugPrint('Tipo de device: ${data['tipo_device']}');
                
                if (data.containsKey('url') && data['url'] != null && data['url'].toString().isNotEmpty) {
                  finalUrl = data['url'].toString();
                  debugPrint('URL retornada pelo servidor: $finalUrl');
                } else {
                  debugPrint('Usando URL padrão (porta de descoberta): $finalUrl');
                }
                
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('server_url', finalUrl);
                
                if (mounted) {
                   debugPrint('--> NAVEGANDO PARA A TELA WEBVIEW COM URL: $finalUrl');
                   Navigator.of(context).pushReplacement(
                     MaterialPageRoute(
                       builder: (context) => WebViewApp(
                         serverUrl: finalUrl,
                         serverInfo: data,
                       ),
                     ),
                   );
                 }
                 return;
                }
              }
            }
          } catch (e) {
            debugPrint('Erro HTTP para $ip: $e');
          }
        }
        
        // Pequena pausa entre lotes para não sobrecarregar
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() {
          statusMessage = 'Servidor não encontrado.\nTente outra interface ou toque para procurar novamente.';
          isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Erro na busca: $e');
      if (mounted) {
        setState(() {
          statusMessage = 'Erro ao procurar servidor.\nToque para tentar novamente.';
          isSearching = false;
        });
      }
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
        child: showInterfaceList ? buildInterfaceList() : buildInitialScreen(),
      ),
    );
  }

  Widget buildInitialScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSearching)
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isSearching ? null : checkSavedServer,
                  child: const Text('Tentar Novamente'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: isSearching ? null : startNewSearch,
                  child: const Text('Nova Busca'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInterfaceList() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                'Interfaces de Rede',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: interfaces.isEmpty
            ? Center(
                child: Text(
                  'Nenhuma interface de rede encontrada',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: interfaces.length,
                itemBuilder: (context, index) {
                  final interface = interfaces[index];
                  final isSelected = selectedInterface == interface;

                  bool isWlan0 = interface.name == 'wlan0';
                  bool isSwlan0 = interface.name == 'swlan0';
                  
                  // Buscar IP válido ou mostrar status
                  String ipText = 'Sem IP';
                  bool hasValidIp = false;
                  
                  try {
                    final ipv4 = interface.addresses.firstWhere(
                      (addr) => addr.type == InternetAddressType.IPv4 && 
                                !addr.address.startsWith('127.') &&
                                !addr.address.startsWith('169.254')
                    );
                    ipText = ipv4.address;
                    hasValidIp = true;
                  } catch (e) {
                    // Interface sem IP válido
                    ipText = 'Sem IP';
                    hasValidIp = false;
                  }
                  
                  return Card(
                    elevation: isSelected ? 4 : 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isSelected 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : null,
                    child: ListTile(
                      leading: Icon(
                        isSwlan0 ? Icons.router : Icons.wifi,
                        color: hasValidIp ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        isSwlan0 ? 'Roteador (${interface.name})' : 'WiFi (${interface.name})',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      subtitle: Text('IP: $ipText'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasValidIp ? Icons.check_circle : Icons.cancel,
                            color: hasValidIp ? Colors.green : Colors.red,
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle, 
                              color: Theme.of(context).colorScheme.primary
                            ),
                          ],
                        ],
                      ),
                      onTap: isSearching 
                        ? null 
                        : () {
                            setState(() {
                              selectedInterface = interface;
                            });
                            searchForServer();
                          },
                    ),
                  );
                },
              ),
        ),
        if (isSearching)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isCancelled = true;
                      isSearching = false;
                      statusMessage = 'Busca cancelada.\nSelecione uma interface para tentar novamente.';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancelar Busca'),
                ),
              ],
            ),
          ),
      ],
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
    
    // PTRZN-1515: Certificado está embarcado em assets/certs/server.crt
    // Será instalado automaticamente via código nativo no primeiro uso
    // O network_security_config.xml aceita certificados de usuário para IPs privados
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.serverUrl));
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
  
  bool _isTabletDevice() {
    // Verificar se é um tablet baseado no tamanho da tela
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    
    debugPrint('Tamanho da tela: ${size.width}x${size.height}');
    debugPrint('Diagonal: ${diagonal.toStringAsFixed(0)}px');
    debugPrint('Threshold: 1120px (7 polegadas)');
    
    // Tablets geralmente têm diagonal > 7 polegadas
    // 7 polegadas = ~177mm, considerando ~160 DPI = ~1120px diagonal
    final isTablet = diagonal > 1120;
    debugPrint('Resultado: ${isTablet ? "TABLET" : "SMARTPHONE"}');
    
    return isTablet;
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
