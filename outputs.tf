output "lb_dns_name" {
  value = "${aws_lb.app.dns_name}"
}

output "ec2_ip" {
  value = "${aws_instance.ecs_instance.public_ip}"
}
