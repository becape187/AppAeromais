# Configuração WireGuard para AeroMais

## Chaves Configuradas

### Cliente (App Android)
- **Chave Privada do Cliente**: `2LaVTVjUSmlWOhxbEE/C5n8Vq8hgU3LDIWNY60OrGFM=`
- **Chave Pública do Cliente**: `uoONtWlWllUyDjFeIN6qyBXv//CRz5feyd6sJSCV6mY=`

### Servidor (cpmais.local)
- **Chave Pública do Servidor**: (obter com `cat /etc/wireguard/server_public.key` no servidor)
- **Servidor**: `cpmais.local`
- **Porta**: `51820`
- **IP do Cliente na VPN**: `10.0.0.2/32`
- **DNS**: `10.0.0.1`
- **AllowedIPs**: `10.0.0.0/24`

## Como Obter a Chave Pública do Servidor

No servidor cpmais.local, execute:

```bash
cat /etc/wireguard/server_public.key
```

Copie a chave pública exibida.

## Configuração no Servidor

Certifique-se de que o servidor WireGuard está configurado com o peer (cliente) correto:

```bash
# No servidor, edite /etc/wireguard/wg0.conf
sudo nano /etc/wireguard/wg0.conf
```

Adicione a seguinte seção `[Peer]`:

```
[Peer]
PublicKey = uoONtWlWllUyDjFeIN6qyBXv//CRz5feyd6sJSCV6mY=
AllowedIPs = 10.0.0.2/32
```

Depois, recarregue a configuração:

```bash
sudo wg syncconf wg0 <(wg-quick strip wg0)
```

Ou reinicie o serviço:

```bash
sudo systemctl restart wg-quick@wg0
```

## Configuração no App

O app já está configurado com as chaves do cliente. A chave pública do servidor pode ser:

1. **Configurada automaticamente** se o servidor fornecer via API
2. **Configurada manualmente** através da tela de configurações do app
3. **Obtida do servidor** e adicionada ao código se necessário

## Arquivo de Configuração Gerado

O app gera automaticamente um arquivo de configuração WireGuard no formato padrão:

```
[Interface]
PrivateKey = 2LaVTVjUSmlWOhxbEE/C5n8Vq8hgU3LDIWNY60OrGFM=
Address = 10.0.0.2/32
DNS = 10.0.0.1

[Peer]
PublicKey = <CHAVE_PUBLICA_DO_SERVIDOR>
Endpoint = cpmais.local:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```

Este arquivo é salvo em: `/data/data/br.com.aeromais.app/files/cpmais.conf`

## Resolução DNS via VPN

**Importante**: A resolução do nome `cpmais.aeromais.com.br` → `10.0.0.1` é feita pela própria VPN:

1. **Conexão inicial**: O app conecta à VPN usando `cpmais.local:51820` (via mDNS)
2. **DNS da VPN**: Após conectar, o DNS `10.0.0.1` é configurado automaticamente na interface WireGuard
3. **Resolução**: O Dnsmasq no servidor (rodando na interface `wg0`) resolve `cpmais.aeromais.com.br` → `10.0.0.1`
4. **Acesso**: O app acessa `https://cpmais.aeromais.com.br`, que é resolvido pelo DNS da VPN

Isso significa que:
- ✅ Não é necessário configurar DNS externo para resolver o domínio
- ✅ A resolução funciona automaticamente quando conectado à VPN
- ✅ O domínio só é acessível quando a VPN está ativa

## Funcionamento Automático

O app:
1. ✅ Inicia automaticamente a conexão WireGuard ao abrir
2. ✅ Monitora a conexão a cada 10 segundos
3. ✅ Reconecta automaticamente se a conexão cair
4. ✅ Mantém a conexão ativa enquanto o app estiver em execução
5. ✅ Salva e restaura o estado da conexão
6. ✅ Usa o DNS da VPN (10.0.0.1) para resolver cpmais.aeromais.com.br

## Troubleshooting

### Verificar Status no Servidor

```bash
# Verificar status do WireGuard
sudo wg show

# Verificar logs
sudo journalctl -u wg-quick@wg0 -f
```

### Verificar Conectividade

```bash
# No servidor, pingar o cliente
ping 10.0.0.2

# No cliente, pingar o servidor
ping 10.0.0.1
```

### Verificar Configuração do Cliente

No app Android, vá em **Configurações > WireGuard VPN** para ver o status da conexão.
