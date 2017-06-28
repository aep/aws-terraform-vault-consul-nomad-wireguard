data "aws_iam_policy_document" "instance-assume-role-policy-doc" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs-assume-role-policy-doc" {
  statement {
    actions = [ "sts:AssumeRole" ]
    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs-service-role" {
    name = "${terraform.env}-ecs-service-role"
    assume_role_policy = "${data.aws_iam_policy_document.ecs-assume-role-policy-doc.json}"
}

resource "aws_iam_role_policy_attachment" "ecs-service-ecs" {
    role       = "${aws_iam_role.ecs-service-role.id}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}


resource "aws_iam_user" "vault-sts" {
    force_destroy = true
    name = "${terraform.env}-vault-sts"
}

resource "aws_iam_access_key" "vault-sts" {
    user = "${aws_iam_user.vault-sts.name}"
}

resource "aws_iam_user_policy" "vault-sts-fed" {
  name = "${terraform.env}-vault-sts"
  user = "${aws_iam_user.vault-sts.name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": [
            "sts:GetFederationToken",
            "ec2:*",
            "s3:*"
        ],
        "Resource": "*"
    }
}
EOF
}

resource "local_file" "vault-setup-sts" {
    content      = <<EOF
#!/bin/sh
export VAULT_ADDR=http://localhost:8200
vault auth ${random_id.vault-altroot.b64}
vault mount aws
vault write aws/config/root \
    access_key=${aws_iam_access_key.vault-sts.id}\
    secret_key=${aws_iam_access_key.vault-sts.secret} \
    region=${var.region}
EOF
    filename = "${path.module}/outputs/vault-setup-sts.sh"
}


