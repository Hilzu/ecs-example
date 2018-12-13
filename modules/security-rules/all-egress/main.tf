variable "security_group_id" {}

resource "aws_security_group_rule" "all_egress" {
  type = "egress"
  description = "Allow all egress traffic to anywhere"
  security_group_id = "${var.security_group_id}"
  from_port = 0
  to_port = 0
  protocol = "all"
  cidr_blocks = ["0.0.0.0/0"]
}

output "security_group_rule_id" {
  value = "${aws_security_group_rule.all_egress.id}"
}
