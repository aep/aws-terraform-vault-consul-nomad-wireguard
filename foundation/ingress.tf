resource "aws_elb" "ingress" {
    name    = "${terraform.env}-ingress"

    listener {
        instance_port      = 9999
        instance_protocol  = "http"
        lb_port            = 443
        lb_protocol        = "https"
        ssl_certificate_id = "${data.aws_acm_certificate.primary.arn}"
    }

    listener {
        instance_port      = 9909
        instance_protocol  = "http"
        lb_port            = 80
        lb_protocol        = "http"
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        target              = "HTTP:9999/"
        interval            = 5
    }

    cross_zone_load_balancing   = true
    idle_timeout                = 400
    connection_draining         = false

    subnets = ["${aws_subnet.main-public.*.id}"]
    security_groups = ["${aws_security_group.ingress.id}"]

    tags {
        Name   = "${terraform.env}-ingress"
        Stage  = "${terraform.env}"
    }
}

resource "aws_proxy_protocol_policy" "ingress" {
  load_balancer  = "${aws_elb.ingress.name}"
  instance_ports = ["9999", "9909"]
}

output "ingress-dns-name" {
    value = "${aws_elb.ingress.dns_name}"
}

output "ingress-zone-id" {
    value = "${aws_elb.ingress.zone_id}"
}

resource "aws_elb" "lifeline" {
    name    = "${terraform.env}-lifeline"

    #device endpoint
    listener {
        instance_port      = 9134
        instance_protocol  = "tcp"
        lb_port            = 80
        lb_protocol        = "tcp"
    }

    #wss api endpoint
    listener {
        instance_port      = 9135
        instance_protocol  = "tcp"
        lb_port            = 443
        lb_protocol        = "ssl"
        ssl_certificate_id = "${data.aws_acm_certificate.primary.arn}"
    }

    health_check {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        target              = "http:9135/"
        interval            = 5
    }

    cross_zone_load_balancing   = true
    idle_timeout                = 3600
    connection_draining         = false

    subnets = ["${aws_subnet.main-public.*.id}"]
    security_groups = ["${aws_security_group.ingress.id}"]

    tags {
        Name   = "${terraform.env}-lifeline"
        Stage  = "${terraform.env}"
    }
}

