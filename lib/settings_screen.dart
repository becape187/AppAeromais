import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'router_monitor.dart';
import 'wireguard_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettings _appSettings = AppSettings();
  double _pingTimeout = 500;
  double _httpTimeout = 1000;
  bool _isLoading = true;
  bool _routerMonitoringEnabled = false;
  bool _wireguardEnabled = false;
  bool _wireguardConnected = false;
  List<String> _networkInterfaces = [];
  Timer? _interfaceUpdateTimer;
  Timer? _wireguardStatusTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadNetworkInterfaces();
    _startInterfaceUpdateTimer();
    _startWireGuardStatusTimer();
  }

  @override
  void dispose() {
    _interfaceUpdateTimer?.cancel();
    _wireguardStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final pingTimeout = await _appSettings.getPingTimeout();
    final httpTimeout = await _appSettings.getHttpTimeout();
    final prefs = await SharedPreferences.getInstance();
    final wireguardEnabled = prefs.getBool('wireguard_enabled') ?? false;
    final wireguardConnected = await WireGuardService.checkConnectionStatus();
    
    setState(() {
      _pingTimeout = pingTimeout.toDouble();
      _httpTimeout = httpTimeout.toDouble();
      _routerMonitoringEnabled = RouterMonitor.isMonitoring;
      _wireguardEnabled = wireguardEnabled;
      _wireguardConnected = wireguardConnected;
      _isLoading = false;
    });
  }

  Future<void> _savePingTimeout(double value) async {
    setState(() {
      _pingTimeout = value;
    });
    await _appSettings.setPingTimeout(value.toInt());
  }

  Future<void> _saveHttpTimeout(double value) async {
    setState(() {
      _httpTimeout = value;
    });
    await _appSettings.setHttpTimeout(value.toInt());
  }

  Future<void> _toggleRouterMonitoring(bool enabled) async {
    setState(() {
      _routerMonitoringEnabled = enabled;
    });
    
    if (enabled) {
      await RouterMonitor.startMonitoring();
    } else {
      await RouterMonitor.stopMonitoring();
    }
  }

  Future<void> _toggleWireGuard(bool enabled) async {
    setState(() {
      _wireguardEnabled = enabled;
    });
    
    if (enabled) {
      // Conectar ao WireGuard com configuração padrão para cpmais.local
      // As chaves do cliente já estão configuradas no WireGuardService
      final connected = await WireGuardService.startConnection(
        server: 'cpmais.local',
        port: 51820,
        dns: '10.0.0.1',
        allowedIPs: '10.0.0.0/24',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(connected 
              ? 'WireGuard conectado ao cpmais.local' 
              : 'Erro ao conectar ao WireGuard'),
            backgroundColor: connected ? Colors.green : Colors.red,
          ),
        );
      }
    } else {
      await WireGuardService.stopConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WireGuard desconectado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    
    // Atualizar status
    if (mounted) {
      setState(() {
        _wireguardConnected = enabled && WireGuardService.isConnected;
      });
    }
  }

  void _startWireGuardStatusTimer() {
    _wireguardStatusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        final connected = await WireGuardService.checkConnectionStatus();
        setState(() {
          _wireguardConnected = connected;
        });
      }
    });
  }

  Future<void> _loadNetworkInterfaces() async {
    try {
      List<String> interfaces = [];
      
      // Buscar apenas wlan0 e swlan0
      for (NetworkInterface interface in await NetworkInterface.list()) {
        String name = interface.name;
        if (name == 'wlan0' || name == 'swlan0') {
          String status = interface.addresses.isNotEmpty ? 'UP' : 'DOWN';
          String ip = interface.addresses.isNotEmpty 
              ? interface.addresses.first.address 
              : 'Sem IP';
          interfaces.add('$name - $status ($ip)');
        }
      }
      
      setState(() {
        _networkInterfaces = interfaces;
      });
    } catch (e) {
      print('Erro ao carregar interfaces de rede: $e');
    }
  }

  void _startInterfaceUpdateTimer() {
    _interfaceUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadNetworkInterfaces();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Seção Roteador
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Controle Roteador',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Monitoramento Automático Roteador'),
                          subtitle: const Text('Monitora o roteador e tenta religá-lo se desligar'),
                          value: _routerMonitoringEnabled,
                          onChanged: _toggleRouterMonitoring,
                          secondary: const Icon(Icons.router),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Seção WireGuard VPN
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WireGuard VPN',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Conexão automática com cpmais.local',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Conexão WireGuard Automática'),
                          subtitle: Text(
                            _wireguardConnected 
                              ? 'Conectado ao cpmais.local' 
                              : 'Desconectado',
                            style: TextStyle(
                              color: _wireguardConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: _wireguardEnabled,
                          onChanged: _toggleWireGuard,
                          secondary: Icon(
                            _wireguardConnected ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                            color: _wireguardConnected ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (_wireguardEnabled)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Servidor: cpmais.local:51820',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'DNS: 10.0.0.1',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'Status: ${_wireguardConnected ? "Conectado" : "Reconectando..."}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _wireguardConnected ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Seção Interfaces de Rede
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interfaces de Rede',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Atualizado a cada 5 segundos',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_networkInterfaces.isEmpty)
                          const ListTile(
                            leading: Icon(Icons.wifi_off),
                            title: Text('Nenhuma interface encontrada'),
                            subtitle: Text('wlan0 e swlan0 não detectadas'),
                          )
                        else
                          ..._networkInterfaces.map((interface) {
                            bool isSwlan0 = interface.startsWith('swlan0');
                            bool isUp = interface.contains('UP');
                            
                            return ListTile(
                              leading: Icon(
                                isSwlan0 ? Icons.router : Icons.wifi,
                                color: isUp ? Colors.green : Colors.red,
                              ),
                              title: Text(
                                isSwlan0 ? 'Roteador (swlan0)' : 'WiFi (wlan0)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isUp ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                              subtitle: Text(interface),
                              trailing: Icon(
                                isUp ? Icons.check_circle : Icons.cancel,
                                color: isUp ? Colors.green : Colors.red,
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Seção URL do Servidor
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'URL do Servidor',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure a URL do servidor (ex: https://cpmais.aeromais.com.br)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<String?>(
                          future: SharedPreferences.getInstance().then((prefs) => prefs.getString('server_url')),
                          builder: (context, snapshot) {
                            final TextEditingController controller = TextEditingController(
                              text: snapshot.data ?? 'https://cpmais.aeromais.com.br'
                            );
                            return TextField(
                              controller: controller,
                              decoration: const InputDecoration(
                                labelText: 'URL do Servidor',
                                hintText: 'https://cpmais.aeromais.com.br',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.link),
                              ),
                              keyboardType: TextInputType.url,
                              onSubmitted: (value) async {
                                if (value.isNotEmpty) {
                                  String url = value.trim();
                                  
                                  // Garantir que usa HTTPS
                                  if (!url.startsWith('http://') && !url.startsWith('https://')) {
                                    url = 'https://$url';
                                  }
                                  if (url.startsWith('http://')) {
                                    url = url.replaceFirst('http://', 'https://');
                                  }
                                  
                                  // Remover porta se especificada (Nginx usa 443 padrão)
                                  final uri = Uri.parse(url);
                                  if (uri.hasPort && uri.port != 443) {
                                    url = 'https://${uri.host}${uri.path}';
                                  }
                                  
                                  // Se for IP, sugerir migração para domínio
                                  final isIP = RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host);
                                  if (isIP) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('⚠️ Use o domínio cpmais.aeromais.com.br em vez de IP'),
                                          backgroundColor: Colors.orange,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  }
                                  
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('server_url', url);
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('URL salva: $url'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nota: O WebSocket será acessado via wss://[domínio]/ws automaticamente.',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Seção Timeouts (mantida para compatibilidade, mas não mais usado para busca)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configurações de Rede',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Essas configurações não são mais usadas (busca automática removida)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTimeoutSlider(
                          label: 'Timeout de Descoberta (Ping)',
                          value: _pingTimeout,
                          min: 100,
                          max: 2000,
                          divisions: 19,
                          onChanged: (value) {
                            setState(() {
                              _pingTimeout = value;
                            });
                          },
                          onChangeEnd: _savePingTimeout,
                        ),
                        const SizedBox(height: 24),
                        _buildTimeoutSlider(
                          label: 'Timeout de Conexão (HTTP)',
                          value: _httpTimeout,
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          onChanged: (value) {
                            setState(() {
                              _httpTimeout = value;
                            });
                          },
                          onChangeEnd: _saveHttpTimeout,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Seção Limpar Cache
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gerenciamento de Cache',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.clear_all, color: Colors.orange),
                          title: const Text('Limpar Cache e Voltar ao Início'),
                          subtitle: const Text('Remove dados salvos e volta para tela de busca'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () async {
                            // Mostrar diálogo de confirmação
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Limpar Cache'),
                                  content: const Text(
                                    'Isso irá remover todos os dados salvos e voltar para a tela de busca de servidor. Deseja continuar?'
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Limpar', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                );
                              },
                            );
                            
                            if (confirm == true) {
                              await _clearCacheAndRestart();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
  
  Future<void> _clearCacheAndRestart() async {
    try {
      // Limpar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Parar monitoramento do roteador
      await RouterMonitor.stopMonitoring();
      
      // Navegar de volta para a tela principal
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao limpar cache: $e')),
        );
      }
    }
  }

  Widget _buildTimeoutSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toInt()} ms',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toInt()} ms',
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${min.toInt()} ms', style: Theme.of(context).textTheme.bodySmall),
              Text('${max.toInt()} ms', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        )
      ],
    );
  }
}
