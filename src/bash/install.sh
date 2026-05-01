#!/bin/sh
set -e

apt-get update && apt-get install -y wget unzip python3

mkdir -p /xray && cd /xray

wget -O xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
unzip -o xray.zip
chmod +x xray

# Генерация ключей Reality
./xray x25519 > keys.txt
PRIVATE_KEY=$(grep "Private key:" keys.txt | awk '{print $3}')
PUBLIC_KEY=$(grep "Public key:" keys.txt | awk '{print $3}')

# Генерация short ID
SHORT_ID=$(openssl rand -hex 8)

# Генерация UUID (10, не 10000!)
CLIENTS=$(python3 -c "import json, uuid; print(json.dumps([{'id': str(uuid.uuid4()), 'flow': 'xtls-rprx-vision'} for _ in range(100)]))")

cat > /xray/config.json << EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443,
    "protocol": "vless",
    "settings": { "clients": $CLIENTS, "decryption": "none" },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "www.samsung.com:443",
        "xver": 0,
        "serverNames": ["www.samsung.com", "samsung.com"],
        "privateKey": "$PRIVATE_KEY",
        "shortIds": ["$SHORT_ID"],
        "spiderX": ""
      }
    }
  }],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ],
  "routing": {
    "rules": [
      { "type": "field", "network": "udp", "port": 443, "outboundTag": "block" }
    ]
  }
}
EOF

echo "PUBLIC KEY (для клиента): $PUBLIC_KEY"
echo "SHORT ID (для клиента): $SHORT_ID"