#!/bin/sh

PUBLIC_IP=$(curl --fail -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl --fail -s http://169.254.169.254/latest/meta-data/local-ipv4)
VPC=$(aws ec2 --region=eu-central-1 describe-instances --instance-ids $(curl --fail -s http://169.254.169.254/latest/meta-data/instance-id) | jq  -r ".Reservations[].Instances[].VpcId")
EC2_REGION=$(curl --fail -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')
NAME=$(curl --fail -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_ID=$(curl -s --fail http://169.254.169.254/latest/meta-data/instance-id)
DC=$(aws ec2 describe-tags --region $EC2_REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Consul-DC" | jq  -r '.Tags[0].Value')

mkdir -p /opt/consul/config
cat > /opt/consul/config/agent.json <<IOF
{
  "datacenter": "$DC",
  "data_dir": "/opt/consul/data/",
  "node_name": "$NAME",
  "client_addr": "0.0.0.0",
  "node_meta" : {
    "availability_zone": "$(curl --fail -s http://169.254.169.254/latest/meta-data/placement/availability-zone)",
    "instance_type": "$(curl --fail -s http://169.254.169.254/latest/meta-data/instance-type)",
    "public_ipv4": "${PUBLIC_IP}"
  },
  "bind_addr": "0.0.0.0",
  "advertise_addr":  "$PRIVATE_IP",
  "advertise_addr_wan": "$PRIVATE_IP",
  "disable_remote_exec": true,
  "leave_on_terminate": true,
  "retry_join_ec2": {
    "tag_key": "Consul-DC",
    "tag_value": "$DC"
  },
  "raft_protocol": 3,
  "autopilot": {
    "cleanup_dead_servers": true
  },
  "ui":     true,
  "server": true,
  "bootstrap_expect" : 3
}
IOF

cat > /etc/systemd/system/consul.service  <<IOF
[Unit]
Description=consul
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
ExecStartPre=-/usr/bin/docker stop consul
ExecStartPre=-/usr/bin/docker rm -f consul
ExecStart=/usr/bin/docker run --rm --name consul \
    --volume=/opt/consul/config:/consul/config \
    --net=host \
    consul:0.8.4 \
    agent

[Install]
WantedBy=multi-user.target
IOF

systemctl enable consul
systemctl start  consul

#dnsmasq will proxy all queries on this host and forward .consul to consul
#and all others to the aws dns
DEBIAN_FRONTEND=noninteractive apt -y install dnsmasq
echo "server=/consul/127.0.0.1#8600" > /etc/dnsmasq.d/consul

#as well as resolve consul and dockerhost to the fixed bip
echo "172.17.0.1 dockerhost" >> /etc/hosts
echo "172.17.0.1 consul" >> /etc/hosts
echo "172.17.0.1 consul.service.consul" >> /etc/hosts
echo 'search service.consul' >> /etc/resolvconf/resolv.conf.d/head
echo 'search service.consul' >> /etc/resolvconf/resolv.conf.d/tail

systemctl enable    dnsmasq
systemctl restart   dnsmasq
systemctl start     dnsmasq

#set a fixed bip as well as set dns resolver to the hosts dnsmasq
#google dns is only here if dnsmasq is failing for whatever reason
cat > /etc/docker/daemon.json << EOF
{
    "bip": "172.17.0.1/16",
    "dns": ["172.17.0.1", "8.8.8.8", "8.8.4.4"],
    "dns-search":["service.consul"],
    "cluster-advertise": "$PRIVATE_IP:2376",
    "cluster-store": "consul://consul:8500"
}
EOF

systemctl restart docker
