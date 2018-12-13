data "aws_ami" "ecs_optimized_ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }
}

data "template_file" "container_definitions" {
  template = "${file("${path.module}/templates/container_definitions.json")}"
  vars {
    region = "${var.region}"
    log_group = "${aws_cloudwatch_log_group.app.name}"
    cpu = "${var.cpu}"
    memory = "${var.memory}"
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user_data.sh")}"
  vars {
    cluster_name = "${aws_ecs_cluster.project.name}"
  }
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}


resource "aws_instance" "ecs_instance" {
  ami = "${data.aws_ami.ecs_optimized_ami.id}"
  // Resource needs to be tainted before changing type of ECS container instance
  instance_type = "t3.nano"
  associate_public_ip_address = true
  iam_instance_profile = "${aws_iam_instance_profile.ecs_instance_profile.name}"
  vpc_security_group_ids = ["${aws_security_group.ecs_instance.id}"]
  subnet_id = "${aws_subnet.public.0.id}"
  user_data = "${data.template_file.user_data.rendered}"
  key_name = "${var.ec2_key_name}"
  depends_on = ["aws_internet_gateway.igw"]

  tags {
    Name = "${var.project}-ecs-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name_prefix = "${var.project}-ecs-instance-profile-"
  role = "${aws_iam_role.ecs_instance_role.name}"
}

resource "aws_iam_role" "ecs_instance_role" {
  name_prefix = "${var.project}-ecs-instance-role-"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_role_policy.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_managed_ec2_policy" {
  role = "${aws_iam_role.ecs_instance_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


resource "aws_security_group" "ecs_instance" {
  name_prefix = "${var.project}-ecs-instance-sg-"
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_security_group_rule" "ec2_ssh_ingress" {
  type = "ingress"
  security_group_id = "${aws_security_group.ecs_instance.id}"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ec2_lb_ingress" {
  type = "ingress"
  security_group_id = "${aws_security_group.ecs_instance.id}"
  source_security_group_id = "${aws_security_group.lb.id}"
  description = "All ingress from LB to ephemeral ports"
  from_port = 32768
  to_port = 65535
  protocol = "tcp"
}

module "ecs_icmp" {
  source = "./modules/security-rules/icmp-ingress"
  security_group_id = "${aws_security_group.ecs_instance.id}"
}

module "ecs_all_egress" {
  source = "./modules/security-rules/all-egress"
  security_group_id = "${aws_security_group.ecs_instance.id}"
}

resource "aws_security_group" "lb" {
  name_prefix = "${var.project}-lb-sg-"
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_security_group_rule" "lb_http_ingress" {
  type = "ingress"
  security_group_id = "${aws_security_group.lb.id}"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

module "lb_icmp" {
  source = "./modules/security-rules/icmp-ingress"
  security_group_id = "${aws_security_group.lb.id}"
}

module "lb_all_egress" {
  source = "./modules/security-rules/all-egress"
  security_group_id = "${aws_security_group.lb.id}"
}


resource "aws_cloudwatch_log_group" "app" {
  name = "${var.project}-app"
  retention_in_days = 14
}


resource "aws_lb" "app" {
  name = "${var.project}-app-lb"
  subnets = ["${aws_subnet.public.*.id}"]
  security_groups = ["${aws_security_group.lb.id}"]
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = "${aws_lb.app.arn}"
  port = 80

  default_action {
    type = "forward"
    target_group_arn = "${aws_lb_target_group.app.arn}"
  }
}

resource "aws_lb_target_group" "app" {
  name = "${var.project}-app-tg"
  // Default port doesn't really matter. ECS registers targets with explicit ports that override this.
  port = 1
  protocol = "HTTP"
  vpc_id = "${aws_vpc.main.id}"

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_ecs_cluster" "project" {
  name = "${var.project}-cluster"
}

resource "aws_ecs_service" "app" {
  name = "${var.project}-app-service"
  cluster = "${aws_ecs_cluster.project.arn}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count = 1
  depends_on = ["aws_lb_listener.app"]

  load_balancer {
    container_name = "app-container"
    container_port = 5678
    target_group_arn = "${aws_lb_target_group.app.arn}"
  }
}

resource "aws_ecs_task_definition" "app" {
  family = "${var.project}-app-task-def"
  container_definitions = "${data.template_file.container_definitions.rendered}"
}
