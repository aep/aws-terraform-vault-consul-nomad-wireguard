variable "region" {
    type    = "string"
    default = "eu-central-1"
}

variable "domain" {
    type    = "string"
    default = "<DOMAIN>"
}

variable "datacenter" {
    type    = "string"
    default = "aws"
}

output "datacenter" {
    value = "${var.datacenter}"
}

terraform {
    backend "s3" {
        bucket      = "<BUCKET>"
        key         = "foundation.tfstate"
        region      = "eu-central-1"
        encrypt     = true
        kms_key_id  = "<KEYID>"
    }
}

provider "aws" {
    region   = "${var.region}"
    profile  = "default"
}

data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name   = "name"
        values = ["ubuntu/*16.04*-amd64-server**"]
    }

    filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }

    filter {
        name   = "root-device-type"
        values = ["ebs"]
    }

    owners = ["099720109477"] # Canonical
}

data "aws_availability_zones" "available" {}

