# To display the outputs of our application load balancer

output "elb_target_group_arn" {
  value = aws_lb_target_group.terra-tg.arn
}

output "elb_load_balancer_dns_name" {
  value = aws_lb.terra_lb.dns_name
}

output "elastic_load_balancer_zone_id" {
  value = aws_lb.terra_lb.zone_id
}
