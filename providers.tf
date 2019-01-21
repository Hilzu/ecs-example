provider "aws" {
  version = "~> 1.56"
  region = "${var.region}"
}

provider "template" {
  version = "~> 1.0"
}
