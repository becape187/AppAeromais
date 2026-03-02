import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_settings.dart';
import 'router_monitor.dart';

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
  List<String> _networkInterfaces = [];
  Timer? _interfaceUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadNetworkInterfaces();
    _startInterfaceUpdateTimer();
  }

  @override
  void dispose() {
    _interfaceUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final pingTimeout = await _appSettings.getPingTimeout();
    final httpTimeout = await _appSettings.getHttpTimeout();
    setState(() {
      _pingTimeout = pingTimeout.toDouble();
      _httpTimeout = httpTimeout.toDouble();
      _routerMonitoringEnabled = RouterMonitor.isMonitoring;
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
                            bool isWlan0 = interface.startsWith('wlan0');
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
                
                // Seção Timeouts
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
