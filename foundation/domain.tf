data "aws_route53_zone" "primary" {
    name         = "${var.domain}"
    private_zone = false
}

resource "aws_route53_record" "lifeline" {
  zone_id = "${data.aws_route53_zone.primary.zone_id}"
  name    = "${terraform.env}-lifeline"
  type    = "A"

  alias {
    name                   = "${aws_elb.lifeline.dns_name}"
    zone_id                = "${aws_elb.lifeline.zone_id}"
    evaluate_target_health = true
  }
}


data "aws_acm_certificate" "primary" {
  domain   = "*.${var.domain}"
  statuses = ["ISSUED"]
}
