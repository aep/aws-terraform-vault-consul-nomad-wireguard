#!/bin/sh

PRIVATE_IP=$(curl --fail -s http://169.254.169.254/latest/meta-data/local-ipv4)
VPC=$(aws ec2 --region=eu-central-1 describe-instances --instance-ids $(curl --fail -s http://169.254.169.254/latest/meta-data/instance-id) | jq  -r ".Reservations[].Instances[].VpcId")
EC2_REGION=$(curl --fail -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')
NAME=$(curl --fail -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_ID=$(curl -s --fail http://169.254.169.254/latest/meta-data/instance-id)
DC=$(aws ec2 describe-tags --region $EC2_REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Consul-DC" | jq  -r '.Tags[0].Value')

mkdir -p /nomad/data/
chmod 777 /nomad/data/
mkdir -p /nomad/config/


cat > /nomad/config/config.hcl<<IOF
region = "eu"
datacenter =  "$DC"
name = "$NAME"

client {
    enabled = true
    node_class = "Linux"
    options {
        "docker.auth.helper" = "ecr-login"
    }
}
server {
    enabled = true
    bootstrap_expect = 3
}

bind_addr = "0.0.0.0"

advertise {
    http = "$PRIVATE_IP"
    rpc  = "$PRIVATE_IP"
    serf = "$PRIVATE_IP"
}

consul {
    "address" = "0.0.0.0:8500"
}

vault {
    enabled = true
    address = "http://vault:8200"
}
IOF

VAULT_TOKEN=$(cat /tmp/vaultt)
rm /tmp/vaultt

cat > /etc/systemd/system/nomad.service  <<IOF
[Unit]
Description=nomad
After=vault.service
Requires=vault.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop nomad
ExecStartPre=-/usr/bin/docker rm -f nomad
ExecStart=/usr/bin/docker run --rm \
    --name nomad \
    --net=host \
    --volume /run/docker.sock:/var/run/docker.sock \
    --env VAULT_TOKEN="$VAULT_TOKEN" \
    --env DOCKER_GID=$(getent group docker | cut -d: -f3) \
    --volume=/nomad/config/:/nomad/config \
    --volume=/nomad/data/:/nomad/data \
    --volume /tmp:/tmp \
    aaep/docker-nomad agent -config=/nomad/config/config.hcl \

[Install]
WantedBy=multi-user.target
IOF

chmod 600 /etc/systemd/system/nomad.service

systemctl enable nomad
systemctl start  nomad
