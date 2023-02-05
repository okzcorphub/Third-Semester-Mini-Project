variable "domain_name" {
  default     = "okzcorp.me"
  type        = string
  description = "domain name"
}

resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name
  tags = {
    Environment = "dev"
  }
}

resource "aws_route53_record" "site_domain" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "terraform-test.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.terra_lb.dns_name
    zone_id                = aws_lb.terra_lb.zone_id
    evaluate_target_health = true
  }
}
