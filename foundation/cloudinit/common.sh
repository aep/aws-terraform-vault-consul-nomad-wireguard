#!/bin/sh

groupadd --system docker
[ -d ~ubuntu ]   && usermod -aG docker ubuntu
[ -d ~ec2-user ] && usermod -aG docker ec2-user

export DEBIAN_FRONTEND=noninteractive
apt -y update
apt -y install docker.io unzip awscli iptables-persistent jq aufs-tools


#this would allow docker containers themself to access dockerd. doesn't sound like a good idea
#and not sure if we actually want to allow docker control remotely anyway
#echo 'DOCKER_OPTS="-H tcp://0.0.0.0:4243 -H unix:///run/docker.sock"' >> /etc/default/docker

echo 'DOCKER_OPTS="-H unix:///run/docker.sock"' >> /etc/default/docker

systemctl enable docker.service
systemctl start  docker.service

