variable "security_group_id" {}

locals {
  icmp_rules = [
    { type = 3, code = 4, desc = "Path MTU Discovery" },
    { type = 8, code = -1, desc = "Ping" },
    { type = 11, code = 0, desc = "Traceroute" }
  ]
}

resource "aws_security_group_rule" "icmp_ingress" {
  count = "${length(local.icmp_rules)}"

  type = "ingress"
  security_group_id = "${var.security_group_id}"
  from_port = "${lookup(local.icmp_rules[count.index], "type")}"
  to_port = "${lookup(local.icmp_rules[count.index], "code")}"
  description = "${lookup(local.icmp_rules[count.index], "desc")}"
  protocol = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
}

output "security_group_rule_ids" {
  value = "${aws_security_group_rule.icmp_ingress.*.id}"
}
