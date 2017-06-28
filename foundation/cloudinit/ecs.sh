#!/bin/sh

#to allow the port proxy to route traffic using loopback addresses.
echo 'net.ipv4.conf.all.route_localnet = 1' >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

systemctl enable netfilter-persistent
systemctl start  netfilter-persistent

#Run the following commands on your container instance to enable IAM roles for tasks. For more information, see IAM Roles for Tasks.
iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
iptables-save > /etc/iptables/rules.v4

mkdir -p /etc/ecs
cat > /etc/ecs/ecs.config <<EOF
ECS_DATADIR=/data
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_LOGFILE=/log/ecs-agent.log
ECS_AVAILABLE_LOGGING_DRIVERS=["awslogs"]
DOCKER_HOST=unix:////run/docker.sock
ECS_CLUSTER=mid
ECS_LOGLEVEL=info
EOF

cat > /etc/logrotate.d/ecs <<EOF
/var/log/ecs/* {
  rotate 12
  monthly
  compress
  missingok
  notifempty
}
EOF

docker run \
    --restart=always \
    --name ecs-agent \
    --detach=true \
    --volume=/run/docker.sock:/run/docker.sock \
    --volume=/var/log/ecs/:/log \
    --volume=/var/lib/ecs/data:/data \
    --volume=/etc/ecs:/etc/ecs \
    --net=host \
    --env-file=/etc/ecs/ecs.config \
    amazon/amazon-ecs-agent:latest

PRIVATE_IP=$(curl --fail -s http://169.254.169.254/latest/meta-data/local-ipv4)

docker run \
    --restart=always  \
    --detach=true \
    --name=registrator \
    --net=host \
    --volume=/run/docker.sock:/tmp/docker.sock \
    gliderlabs/registrator:latest \
    consulkv://localhost:8500/registrator \



mkdir -p /opt/consul/config/
cat > /opt/consul/config/docker.json <<IOF
{
  "service": {
    "name": "docker",
    "tags": [],
    "port": 4243
  }
}
IOF

cat > /opt/consul/config/ecs.json <<IOF
{
  "service": {
    "name": "ecs"
  }
}
IOF

killall -HUP consul
