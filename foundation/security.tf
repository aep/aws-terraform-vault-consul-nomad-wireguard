resource "aws_security_group" "consul" {
    vpc_id      = "${aws_vpc.main.id}"
    name        = "${terraform.env}-consul"
    description = "${terraform.env}-consul"

    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        self        = true
    }

    tags {
        Name  = "${terraform.env}-consul"
        Stage = "${terraform.env}"
    }
}

resource "aws_security_group" "border" {
    vpc_id      = "${aws_vpc.main.id}"
    name        = "${terraform.env}-border"
    description = "${terraform.env}-border"

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = [
            "0.0.0.0/0"
        ]
    }

    ingress {
        from_port   = 52525
        to_port     = 52525
        protocol    = "udp"
        cidr_blocks = [
            "0.0.0.0/0"
        ]
    }

    tags {
        Name = "${terraform.env}-border"
        Stage = "${terraform.env}"
    }
}

resource "aws_security_group" "egress" {
    vpc_id      = "${aws_vpc.main.id}"
    name        = "${terraform.env}-egress"
    description = "${terraform.env}-egress"

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
        Name = "${terraform.env}-egress"
        Stage = "${terraform.env}"
    }
}

resource "aws_security_group" "cluster" {
    vpc_id      = "${aws_vpc.main.id}"
    name        = "${terraform.env}-cluster"
    description = "${terraform.env}-cluster"


#FIXME this would allow anything from wan too. don't do it.
    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = -1
        security_groups = ["${aws_security_group.border.id}"]
    }

    ingress {
        from_port   = 9000
        to_port     = 9999
        protocol    = "tcp"
        security_groups = ["${aws_security_group.ingress.id}"]
    }

    tags {
        Name = "${terraform.env}-cluster"
        Stage = "${terraform.env}"
    }
}

resource "aws_security_group" "ingress" {
    vpc_id      = "${aws_vpc.main.id}"
    name        = "${terraform.env}-ingress"
    description = "${terraform.env}-ingress"

    ingress {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags {
        Name = "${terraform.env}-ingress"
        Stage = "${terraform.env}"
    }
}

resource "aws_security_group" "cluster-wan" {
    vpc_id      = "${aws_vpc.main.id}"
    name        = "${terraform.env}-cluster-wan"
    description = "allows cluster wan connections from transit network"
    tags {
        Name = "${terraform.env}-cluster-wan"
        Stage = "${terraform.env}"
    }

    #consul
    ingress {
        from_port   = 8300
        to_port     = 8300
        protocol    = "tcp"
        cidr_blocks = ["172.24.0.0/16"]
    }
    ingress {
        from_port   = 8302
        to_port     = 8302
        protocol    = "udp"
        cidr_blocks = ["172.24.0.0/16"]
    }
    ingress {
        from_port   = 8302
        to_port     = 8302
        protocol    = "tcp"
        cidr_blocks = ["172.24.0.0/16"]
    }
    # vault
    ingress {
        from_port   = 8200
        to_port     = 8200
        protocol    = "tcp"
        cidr_blocks = ["172.24.0.0/16"]
    }

    #nomad
    ingress {
        from_port   = 4647
        to_port     = 4647
        protocol    = "tcp"
        cidr_blocks = ["172.24.0.0/16"]
    }
}
