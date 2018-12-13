locals {
  subnet_count = 2
}

data "aws_availability_zones" "azs" {}

resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
  enable_dns_hostnames = true


  tags {
    Name = "${var.project}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = "${local.subnet_count}"

  cidr_block = "10.10.${count.index}.0/24"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.azs.names[count.index]}"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.project}-public-subnet-${count.index}"
  }
}

resource "aws_default_route_table" "main" {
  default_route_table_id = "${aws_vpc.main.default_route_table_id}"
  tags {
    Name = "${var.project}-default-rtb"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.project}-igw"
  }
}

resource "aws_route" "internet_route" {
  route_table_id = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.igw.id}"
}

resource "aws_route_table_association" "public_subnets_to_route_table" {
  count = "${local.subnet_count}"

  route_table_id = "${aws_vpc.main.main_route_table_id}"
  subnet_id = "${aws_subnet.public.*.id[count.index]}"
}

resource "aws_default_network_acl" "main" {
  default_network_acl_id = "${aws_vpc.main.default_network_acl_id}"
  subnet_ids = ["${aws_subnet.public.*.id}"]

  ingress {
    protocol = -1
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  egress {
    protocol = -1
    rule_no = 100
    action = "allow"
    cidr_block = "0.0.0.0/0"
    from_port = 0
    to_port = 0
  }

  tags {
    Name = "${var.project}-default-nacl"
  }
}
