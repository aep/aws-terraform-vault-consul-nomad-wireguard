resource "aws_ecs_cluster" "main" {
    name = "${terraform.env}"
}

data "template_cloudinit_config" "cluster" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/common.sh")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/consul.sh")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/ecs.sh")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/vault.sh")}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<EOF
#!/bin/sh
echo "${random_id.vault-altroot.b64}" >  /tmp/vaultt
EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${file("./cloudinit/nomad.sh")}"
  }
}

resource "aws_launch_configuration" "main-cluster" {
    lifecycle { create_before_destroy = true }
    image_id        = "${data.aws_ami.ubuntu.id}"
    instance_type   = "t2.micro"
    user_data       = "${data.template_cloudinit_config.cluster.rendered}"
    iam_instance_profile = "${aws_iam_instance_profile.cluster-instance-profile.arn}"
    security_groups = [
        "${aws_security_group.consul.id}",
        "${aws_security_group.egress.id}",
        "${aws_security_group.cluster.id}",
        "${aws_security_group.cluster-wan.id}",
    ]
}

resource "aws_autoscaling_group" "main-cluster" {
    lifecycle { create_before_destroy = true }
    name     = "${terraform.env}-cluster"
    max_size = 3
    min_size = 3
    vpc_zone_identifier = ["${aws_subnet.main-private.*.id}"]
    health_check_grace_period = 300
    health_check_type         = "EC2"
    launch_configuration = "${aws_launch_configuration.main-cluster.name}"
    load_balancers = ["${aws_elb.ingress.id}", "${aws_elb.lifeline.id}"]
    tag {
        key     = "Name"
        value   = "${terraform.env}-cluster"
        propagate_at_launch = true
    }
    tag {
        key     = "Consul-DC"
        value   = "${terraform.env}-${var.datacenter}"
        propagate_at_launch = true
    }

}

resource "aws_iam_role" "cluster-instance-role" {
    name = "${terraform.env}-cluster-instance-role"
    assume_role_policy = "${data.aws_iam_policy_document.instance-assume-role-policy-doc.json}"
}

resource "aws_iam_instance_profile" "cluster-instance-profile" {
  name = "${terraform.env}-cluster-instance-profile"
  role = "${aws_iam_role.cluster-instance-role.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-instance-cluster" {
    role       = "${aws_iam_role.cluster-instance-role.id}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "cluster-instance-consul" {
    role       = "${aws_iam_role.cluster-instance-role.id}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

#TODO: this is only nessesary because nomad has no way of passing aws sts creds into docker env
resource "aws_iam_role_policy_attachment" "cluster-instance-s3" {
    role       = "${aws_iam_role.cluster-instance-role.id}"
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


resource "random_id" "vault-altroot" {
    byte_length = 16
}

resource "local_file" "vault-provisioner" {
    content      = <<EOF
#!/bin/sh
ssh ubuntu@${aws_instance.border.public_ip} docker run aaep/vault-init vault-init -consul consul:8500 -token ${random_id.vault-altroot.b64}
EOF
    filename = "${path.module}/outputs/vault-provisioner.sh"
}


output "vault-token" {
    value = "${random_id.vault-altroot.b64}"
}
