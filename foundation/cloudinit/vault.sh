#!/bin/sh


mkdir -p /vault/config/
cat > /vault/config/config.json <<IOF
storage "consul" {
  address = "consul:8500"
  path    = "vault/"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

disable_mlock = true
IOF

cat > /etc/systemd/system/vault.service  <<IOF
[Unit]
Description=vault
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop vault
ExecStartPre=-/usr/bin/docker rm -f vault
ExecStart=/usr/bin/docker run --rm \
    --name vault \
    -p 8200:8200 \
    -p 8201:8201 \
    -e "SKIP_SETCAP=1" \
    -v /vault/config:/vault/config \
    vault:0.7.3 \
    server

[Install]
WantedBy=multi-user.target
IOF

chmod 600 /etc/systemd/system/vault.service

systemctl enable vault
systemctl start  vault
