# Configuração do App Flutter com Nginx

## Mudanças Realizadas

### 1. Remoção de Busca Automática
- ✅ Removida toda a funcionalidade de busca/discovery de servidores
- ✅ Removida busca por IPs na rede local
- ✅ Removida chamada ao endpoint `/whoami`
- ✅ App agora conecta diretamente ao domínio configurado

### 2. URL Padrão do Servidor
- **URL padrão**: `https://cpmais.aeromais.com.br`
- **Sem porta**: Nginx usa porta 443 (HTTPS padrão)
- **HTTPS obrigatório**: App força uso de HTTPS

### 3. Endpoints Atualizados

#### API HTTP/HTTPS
- **Antes**: `https://[IP]:5000` ou `http://[IP]:5000`
- **Agora**: `https://cpmais.aeromais.com.br/` (porta 443, não precisa especificar)

#### WebSocket (WSS)
- **Antes**: `ws://[IP]:5001` ou `wss://[IP]:5001`
- **Agora**: `wss://cpmais.aeromais.com.br/ws` (porta 443, não precisa especificar)

### 4. Configuração Manual
O usuário pode configurar a URL do servidor através de:
- **Tela de Configurações** → Campo "URL do Servidor"
- **Valor padrão**: `https://cpmais.aeromais.com.br`

## Como Funciona Agora

1. **Ao iniciar o app**:
   - Verifica se há URL salva nas configurações
   - Se não houver, usa a URL padrão: `https://cpmais.aeromais.com.br`
   - Garante que a URL usa HTTPS
   - Remove porta se especificada (Nginx usa 443 padrão)
   - Navega diretamente para o WebView

2. **No WebView**:
   - Carrega a página HTML do servidor
   - O JavaScript da página HTML configura o WebSocket para `wss://cpmais.aeromais.com.br/ws`
   - Não há mais necessidade de descobrir IPs ou portas

## Configuração do Nginx

O Nginx está configurado para:
- **Porta 80**: Redireciona para HTTPS (porta 443)
- **Porta 443**: Proxy reverso para Flask na porta 5000 (HTTP interno)
- **WebSocket**: `/ws` → Proxy para porta 5001 (WSS)

## Notas Importantes

1. **Sem busca automática**: O app não busca mais servidores na rede
2. **Domínio fixo**: Usa o domínio configurado (padrão: `cpmais.aeromais.com.br`)
3. **Sem porta na URL**: Nginx usa porta 443 padrão para HTTPS
4. **WebSocket automático**: O JavaScript do HTML configura o WebSocket via `/ws`

## Troubleshooting

### App não conecta
1. Verifique se o domínio está correto nas configurações
2. Verifique se o Nginx está rodando: `sudo systemctl status nginx`
3. Verifique se o Flask está rodando: `sudo netstat -tlnp | grep 5000`
4. Teste no navegador: `https://cpmais.aeromais.com.br`

### WebSocket não funciona
1. Verifique se o Nginx está configurado para `/ws`
2. Verifique se o Flask está escutando na porta 5001
3. Verifique logs do Nginx: `sudo tail -f /var/log/nginx/aeromais_error.log`
