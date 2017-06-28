resource "aws_instance" "border" {
    ami           = "${data.aws_ami.ubuntu.id}"
    instance_type = "t2.nano"

    tags {
        Name        = "${terraform.env}-border"
        Stage       = "${terraform.env}"
        Consul-DC   = "${terraform.env}-${var.datacenter}"
    }
    user_data = "${data.template_cloudinit_config.border.rendered}"
    subnet_id = "${aws_subnet.main-public.0.id}"
    vpc_security_group_ids = [
        "${aws_security_group.border.id}",
        "${aws_security_group.consul.id}",
        "${aws_security_group.egress.id}",
        "${aws_security_group.cluster-wan.id}"
    ]
    iam_instance_profile  = "${aws_iam_instance_profile.border-instance-profile.id}"
    source_dest_check = false
}

resource "random_id" "border-gw-key" {
    byte_length = 32
}

data "external" "border-gw-key" {
  program = ["${path.module}/wg-keys.sh"]
  query = {
    seed = "${random_id.border-gw-key.hex}"
  }
}

resource "random_id" "border-dev-key" {
    byte_length = 32
}

data "external" "border-dev-key" {
  program = ["${path.module}/wg-keys.sh"]
  query = {
    seed = "${random_id.border-dev-key.hex}"
  }
}

resource "random_id" "border-htz1-key" {
    byte_length = 32
}

data "external" "border-htz1-key" {
  program = ["${path.module}/wg-keys.sh"]
  query = {
    seed = "${random_id.border-htz1-key.hex}"
  }
}


data "template_cloudinit_config" "border" {

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/common.sh")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<EOF
#!/bin/sh
mkdir -p /opt/consul/config/
cat > /opt/consul/config/ssh.json <<IOF
{
  "service": {
    "name": "ssh",
    "tags": ["border"],
    "address": "$(curl --fail -s http://169.254.169.254/latest/meta-data/public-ipv4)",
    "port": 22,
    "enableTagOverride": false
  }
}
IOF
EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<EOF
#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
add-apt-repository -y ppa:wireguard/wireguard
apt -y update
apt -y install wireguard-dkms wireguard-tools

cat > /etc/wireguard/peering.conf <<IOF
[Interface]
Address      = 172.24.0.1/16
PrivateKey   = ${lookup(data.external.border-gw-key.result,"priv")}
ListenPort   = 52525

[Peer]
PublicKey    = ${lookup(data.external.border-dev-key.result,"pub")}
AllowedIPs   = 172.24.1.0/24

[Peer]
PublicKey    = ${lookup(data.external.border-htz1-key.result,"pub")}
AllowedIPs   = 172.24.2.101/32
IOF

wg-quick up peering
EOF
 }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/consul.sh")}"
  }
}

resource "aws_iam_role" "border-instance-role" {
    name = "${terraform.env}-border-instance-role"
    assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy-doc.json}"
}

resource "aws_iam_instance_profile" "border-instance-profile" {
  name = "${terraform.env}-border-instance-profile"
  role = "${aws_iam_role.border-instance-role.name}"
}

resource "aws_iam_role_policy_attachment" "border-instance-profile-attach-iam" {
    role       = "${aws_iam_role.border-instance-role.id}"
    policy_arn = "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "border-instance-profile-attach-ecs" {
    role       = "${aws_iam_role.border-instance-role.id}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}


resource "local_file" "wireguard" {
    content = <<EOF
[Interface]
Address      = 172.24.1.4/16
PostDown     = resolvconf -d wireguard
PrivateKey   = ${lookup(data.external.border-dev-key.result,"priv")}

[Peer]
PublicKey    = ${lookup(data.external.border-gw-key.result,"pub")}
AllowedIPs   = 172.24.0.0/16,172.30.0.0/16
Endpoint     = ${aws_instance.border.public_ip}:52525
EOF
    filename = "${path.module}/outputs/wireguard.conf"

}

resource "local_file" "ssh_config" {
    content = <<EOF
Host border.${var.domain}
    user ubuntu
    Hostname ${aws_instance.border.public_ip}
EOF
    filename = "${path.module}/outputs/ssh_config"
}


output "border-ip" {
    value = "${aws_instance.border.public_ip}"
}

#FIXME this should be going through vault or something instead of being in tf in the first place
output "border-htz1-key" {
    value = "${lookup(data.external.border-htz1-key.result,"priv")}"
}
output "border-gw-pubkey" {
    value = "${lookup(data.external.border-gw-key.result,"pub")}"
}
