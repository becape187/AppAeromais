# AeroMais - Monitor WiFi Automático

## Funcionalidade

O app AeroMais agora inclui um sistema de monitoramento automático do WiFi que:

- **Monitora continuamente** o status do WiFi do tablet
- **Religa automaticamente** o WiFi quando ele é desligado
- **Funciona em background** mesmo quando o app não está em uso
- **Inicia automaticamente** após o boot do dispositivo
- **Mantém o roteador sempre ativo** para garantir conectividade

## Como Funciona

### 1. Serviço em Background
- Um serviço Android nativo (`WifiMonitorService`) roda continuamente
- Verifica o status do WiFi a cada 10 segundos
- Se o WiFi estiver desligado, liga automaticamente
- Se não estiver conectado, força uma nova busca por redes

### 2. Inicialização Automática
- O serviço inicia automaticamente após o boot do dispositivo
- Um `BootReceiver` detecta quando o sistema inicia e inicia o monitoramento
- O estado de monitoramento é salvo e restaurado automaticamente

### 3. Interface de Controle
- Controles na tela de Configurações para ligar/desligar o monitoramento
- Status em tempo real do WiFi e do monitoramento
- Controle manual do WiFi quando necessário

## Instalação

### 1. Compilar o App
```bash
cd appaeromais
flutter pub get
flutter build apk --release
```

### 2. Instalar via ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### 3. Configurar Permissões
O app solicitará as seguintes permissões automaticamente:
- Acesso ao WiFi
- Modificar configurações do WiFi
- Executar em background
- Iniciar após o boot

### 4. Ativar Monitoramento
1. Abra o app AeroMais
2. Vá em Configurações (menu lateral)
3. Ative "Monitoramento Automático WiFi"
4. O monitoramento começará imediatamente

## Configurações

### Tela de Configurações
- **Monitoramento Automático WiFi**: Liga/desliga o monitoramento contínuo
- **WiFi Habilitado**: Controle manual do WiFi
- **Timeout de Descoberta**: Tempo limite para ping (100-2000ms)
- **Timeout de Conexão**: Tempo limite para HTTP (500-5000ms)

### Comportamento Padrão
- Monitoramento ativado automaticamente na primeira execução
- Verificação a cada 10 segundos
- Notificação persistente mostrando status
- Reinício automático do serviço se for morto pelo sistema

## Solução de Problemas

### WiFi não liga automaticamente
1. Verifique se o monitoramento está ativo nas configurações
2. Reinicie o app
3. Verifique as permissões do sistema

### Serviço para de funcionar
1. O serviço é configurado para reiniciar automaticamente
2. Se persistir, reinstale o app
3. Verifique se o tablet não está em modo de economia de energia

### Notificação não aparece
1. Verifique as configurações de notificação do app
2. Certifique-se de que o app não está sendo otimizado pelo sistema
3. Adicione o app à lista de exceções de economia de energia

## Logs e Debug

### Visualizar Logs
```bash
adb logcat | grep -E "(WifiMonitor|AeroMais)"
```

### Logs Importantes
- `WifiMonitorService`: Logs do serviço de monitoramento
- `WifiMonitorPlugin`: Logs da comunicação Flutter-Android
- `BootReceiver`: Logs de inicialização automática

## Arquivos Modificados

### Android
- `AndroidManifest.xml`: Permissões e serviços
- `WifiMonitorService.java`: Serviço de monitoramento
- `BootReceiver.java`: Inicialização automática
- `WifiMonitorPlugin.java`: Plugin Flutter
- `MainActivity.kt`: Registro do plugin

### Flutter
- `pubspec.yaml`: Dependências adicionadas
- `main.dart`: Inicialização do monitoramento
- `wifi_monitor.dart`: Classe de controle WiFi
- `settings_screen.dart`: Interface de configuração

## Dependências Adicionadas

- `wifi_iot`: Controle do WiFi
- `connectivity_plus`: Monitoramento de conectividade
- `workmanager`: Tarefas em background
- `flutter_local_notifications`: Notificações

## Compatibilidade

- **Android**: 5.0+ (API 21+)
- **Flutter**: 3.2.6+
- **Tablets**: Testado em tablets Android com WiFi

## Segurança

- O app só controla o WiFi do próprio dispositivo
- Não acessa dados de rede externos
- Permissões mínimas necessárias
- Código aberto e auditável
