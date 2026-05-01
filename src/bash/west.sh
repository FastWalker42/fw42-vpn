#!/bin/sh
# install-west.sh — exit node (Европа)
# VLESS + Reality + XHTTP packet-up. Принимает один клиент: RU-relay.

set -eu

# ───── параметры ─────
DEST_SNI="www.microsoft.com"          # цель Reality для WEST (TLS 1.3 + везде доступен)
LISTEN_PORT=443
XHTTP_PATH="/api/v1/update"           # должен совпадать с конфигом RU

# ───── проверки ─────
[ "$(id -u)" -eq 0 ] || { echo "Запусти от root (sudo)."; exit 1; }

echo ">> Устанавливаю зависимости"
apt-get update
apt-get install -y wget unzip curl jq ufw

echo ">> Качаю Xray-core (latest)"
mkdir -p /xray && cd /xray
wget -qO xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -oq xray.zip
chmod +x xray
rm -f xray.zip

# Версия должна быть >= 25.12.8 (старые Reality палятся по NewSessionTicket)
VER=$(./xray version | head -n1 | awk '{print $2}')
echo ">> Установлен Xray $VER"

echo ">> Генерирую ключи Reality, UUID и shortId"
./xray x25519 > keys.txt
PRIVATE_KEY=$(awk -F': ' '/Private key/ {print $2}' keys.txt)
PUBLIC_KEY=$(awk -F': ' '/Public key/  {print $2}' keys.txt)

CLIENT_UUID=$(./xray uuid)
SHORT_ID=$(head -c 8 /dev/urandom | xxd -p)

# не оставляем приватник в plaintext
shred -u keys.txt 2>/dev/null || rm -f keys.txt

echo ">> Пишу config.json"
cat > /xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "in-from-ru",
      "listen": "0.0.0.0",
      "port": $LISTEN_PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "$CLIENT_UUID", "flow": "" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "$XHTTP_PATH",
          "mode": "packet-up"
        },
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DEST_SNI:443",
          "xver": 0,
          "serverNames": ["$DEST_SNI"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom",   "tag": "direct" },
    { "protocol": "blackhole", "tag": "block"  }
  ],
  "routing": {
    "rules": [
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "block" },
      { "type": "field", "network": "udp", "port": 443, "outboundTag": "block" }
    ]
  }
}
EOF

echo ">> Создаю systemd unit"
cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Service (WEST exit node)
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

echo ">> Открываю порт $LISTEN_PORT/tcp в ufw"
ufw allow $LISTEN_PORT/tcp >/dev/null 2>&1 || true

# ───── оптимизация sysctl для нагрузки ─────
cat > /etc/sysctl.d/99-xray.conf <<'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fastopen = 3
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
sysctl --system >/dev/null

# ───── вывод параметров для RU ─────
SERVER_IP=$(curl -s4 https://api.ipify.org || echo "<твой_IP>")

cat <<EOF

═══════════════════════════════════════════════════════════════════
  WEST готов. Передай эти параметры в install-ru.sh:

  WEST_ADDR=$SERVER_IP
  WEST_PORT=$LISTEN_PORT
  WEST_UUID=$CLIENT_UUID
  WEST_PBK=$PUBLIC_KEY
  WEST_SID=$SHORT_ID
  WEST_SNI=$DEST_SNI
  WEST_PATH=$XHTTP_PATH

  Версия Xray: $VER
═══════════════════════════════════════════════════════════════════
EOF
