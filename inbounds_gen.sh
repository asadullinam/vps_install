#!/bin/bash

# Generate values
UUID=$(uuidgen)

# Wait until the xray binary is available inside the running container
echo "Waiting for xray binary inside 3x-ui container..."
XRAY_BIN=""
for i in $(seq 1 15); do
    for candidate in "/app/bin/xray-linux-amd64" "/app/bin/xray" "/usr/local/bin/xray"; do
        if docker exec 3x-ui test -f "$candidate" 2>/dev/null; then
            XRAY_BIN="$candidate"
            break 2
        fi
    done
    echo "  not ready yet ($i/15), waiting 2s..."
    sleep 2
done

if [ -z "$XRAY_BIN" ]; then
    echo "ERROR: xray binary not found inside 3x-ui after 30s — keys will be empty"
    PRIVATE_KEY=""
    PUBLIC_KEY=""
else
    output=$(docker exec 3x-ui sh -c "$XRAY_BIN x25519" 2>/dev/null)
    PRIVATE_KEY=$(echo "$output" | awk -F': ' '/Private key/ {print $2}')
    PUBLIC_KEY=$(echo "$output" | awk -F': ' '/Public key/ {print $2}')
fi

echo "Private key: $PRIVATE_KEY"
echo "Public key: $PUBLIC_KEY"

# Create inbounds.sql
cat > inbounds.sql << EOF
BEGIN TRANSACTION;
DROP TABLE IF EXISTS "inbounds";
CREATE TABLE IF NOT EXISTS "inbounds" (
    "id"    integer,
    "user_id"   integer,
    "up"    integer,
    "down"  integer,
    "total" integer,
    "remark"    text,
    "enable"    numeric,
    "expiry_time"   integer,
    "listen"    text,
    "port"  integer UNIQUE,
    "protocol"  text,
    "settings"  text,
    "stream_settings" text,
    "tag"   text UNIQUE,
    "sniffing"  text,
    PRIMARY KEY("id")
);
INSERT INTO "inbounds" VALUES (1,1,0,0,0,'',1,0,'',443,'vless','{
  "clients": [
    {
      "id": "$UUID",
      "flow": "xtls-rprx-vision",
      "email": "default418",
      "limitIp": 0,
      "totalGB": 0,
      "expiryTime": 0,
      "enable": true,
      "tgId": "",
      "subId": ""
    }
  ],
  "decryption": "none",
  "fallbacks": []
}','{
  "network": "tcp",
  "security": "reality",
  "realitySettings": {
    "show": false,
    "xver": 0,
    "dest": "www.microsoft.com:443",
    "serverNames": [
      "www.microsoft.com",
      "microsoft.com"
    ],
    "privateKey": "$PRIVATE_KEY",
    "minClient": "",
    "maxClient": "",
    "maxTimediff": 0,
    "shortIds": [
      "deced1f3"
    ],
    "settings": {
      "publicKey": "$PUBLIC_KEY",
      "fingerprint": "safari",
      "serverName": "",
      "spiderX": "/"
    }
  },
  "tcpSettings": {
    "acceptProxyProtocol": false,
    "header": {
      "type": "none"
    }
  }
}','inbound-443','{
  "enabled": true,
  "destOverride": [
    "http",
    "tls",
    "quic",
    "fakedns"
  ]
}');
COMMIT;
EOF

