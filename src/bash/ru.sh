#!/bin/sh
# install-ru.sh — RU relay (вход для клиентов, чейнит трафик в WEST)
# Inbound: VLESS + Reality + Vision (TCP), SNI vkvideo.ru — белый домен.
# Outbound: VLESS + Reality + XHTTP packet-up в сторону WEST.

set -eu

# ───── параметры WEST (передать через env или захардкодить) ─────
: "${WEST_ADDR:?Укажи WEST_ADDR=ip.вестa}"
: "${WEST_UUID:?Укажи WEST_UUID=...}"
: "${WEST_PBK:?Укажи WEST_PBK=...}"
: "${WEST_SID:?Укажи WEST_SID=...}"
WEST_PORT="${WEST_PORT:-443}"
WEST_SNI="${WEST_SNI:-www.microsoft.com}"
WEST_PATH="${WEST_PATH:-/api/v1/update}"

# ───── параметры RU ─────
LISTEN_PORT=443
RU_DEST_SNI="vkvideo.ru"              # «белый» домен внутри РФ
NUM_CLIENTS=100

[ "$(id -u)" -eq 0 ] || { echo "Запусти от root (sudo)."; exit 1; }

echo ">> Устанавливаю зависимости"
apt-get update
apt-get install -y wget unzip curl jq python3 ufw

echo ">> Качаю Xray-core (latest)"
mkdir -p /xray && cd /xray
wget -qO xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -oq xray.zip
chmod +x xray
rm -f xray.zip

VER=$(./xray version | head -n1 | awk '{print $2}')
echo ">> Установлен Xray $VER"

echo ">> Генерирую ключи Reality для RU"
./xray x25519 > keys.txt
RU_PRIVATE=$(awk -F': ' '/Private key/ {print $2}' keys.txt)
RU_PUBLIC=$(awk -F': ' '/Public key/  {print $2}' keys.txt)
shred -u keys.txt 2>/dev/null || rm -f keys.txt

RU_SHORT_ID=$(head -c 8 /dev/urandom | xxd -p)

echo ">> Генерирую $NUM_CLIENTS UUID для клиентов"
CLIENTS_JSON=$(python3 -c "
import json, uuid
arr = [{'id': str(uuid.uuid4()), 'flow': 'xtls-rprx-vision', 'email': f'user{i:03d}@ru'} for i in range($NUM_CLIENTS)]
print(json.dumps(arr, indent=2))
")
# сохраним список UUID отдельно — пригодится для раздачи
echo "$CLIENTS_JSON" > /xray/clients.json
chmod 600 /xray/clients.json

echo ">> Пишу config.json"
cat > /xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "in-clients",
      "listen": "0.0.0.0",
      "port": $LISTEN_PORT,
      "protocol": "vless",
      "settings": {
        "clients": $CLIENTS_JSON,
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$RU_DEST_SNI:443",
          "xver": 0,
          "serverNames": ["$RU_DEST_SNI"],
          "privateKey": "$RU_PRIVATE",
          "shortIds": ["$RU_SHORT_ID"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "tag": "chain-to-west",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$WEST_ADDR",
            "port": $WEST_PORT,
            "users": [
              {
                "id": "$WEST_UUID",
                "flow": "",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "$WEST_PATH",
          "mode": "packet-up"
        },
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "serverName": "$WEST_SNI",
          "publicKey": "$WEST_PBK",
          "shortId": "$WEST_SID"
        }
      }
    },
    { "protocol": "freedom",   "tag": "direct" },
    { "protocol": "blackhole", "tag": "block"  }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "block" },
      { "type": "field", "network": "udp", "port": 443, "outboundTag": "block" },

      { "type": "field", "outboundTag": "direct",
        "domain": [
          "geosite:category-ru",
          "geosite:yandex",
          "regexp:\\\\.ru$",
          "full:cp.cloudflare.com"
        ]
      },
      { "type": "field", "outboundTag": "direct", "ip": ["geoip:ru"] },

      { "type": "field", "inboundTag": ["in-clients"], "outboundTag": "chain-to-west" }
    ]
  }
}
EOF

echo ">> Проверяю конфиг"
./xray test -config /xray/config.json

echo ">> Создаю systemd unit"
cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service (RU relay)
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/xray/xray run -config /xray/config.json
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now xray
sleep 2
systemctl --no-pager status xray | head -n 15

echo ">> Открываю порт $LISTEN_PORT/tcp"
ufw allow $LISTEN_PORT/tcp >/dev/null 2>&1 || true

cat > /etc/sysctl.d/99-xray.conf <<'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl --system >/dev/null

# ───── генерим vless:// ссылки для всех клиентов ─────
RU_IP=$(curl -s4 https://api.ipify.org || echo "<RU_IP>")
LINKS_FILE=/xray/client-links.txt
: > "$LINKS_FILE"

python3 - <<PY > "$LINKS_FILE"
import json, urllib.parse
clients = json.load(open('/xray/clients.json'))
for i, c in enumerate(clients):
    params = {
        "type": "tcp",
        "security": "reality",
        "pbk": "$RU_PUBLIC",
        "fp": "chrome",
        "sni": "$RU_DEST_SNI",
        "sid": "$RU_SHORT_ID",
        "flow": "xtls-rprx-vision",
    }
    qs = urllib.parse.urlencode(params)
    print(f"vless://{c['id']}@$RU_IP:$LISTEN_PORT?{qs}#ru-relay-{i:03d}")
PY
chmod 600 "$LINKS_FILE"

cat <<EOF

═══════════════════════════════════════════════════════════════════
  RU relay готов.

  Адрес для клиентов:  $RU_IP:$LISTEN_PORT
  SNI (RU):            $RU_DEST_SNI
  Public key (RU):     $RU_PUBLIC
  Short ID (RU):       $RU_SHORT_ID
  Клиентов сгенерено:  $NUM_CLIENTS

  vless:// ссылки:     $LINKS_FILE
  Список UUID:         /xray/clients.json
  Версия Xray:         $VER

  Чейн в WEST: $WEST_ADDR:$WEST_PORT (SNI: $WEST_SNI)
═══════════════════════════════════════════════════════════════════
EOF
