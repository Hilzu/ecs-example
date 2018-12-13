provider "aws" {
  version = "~> 1.50"
  region = "${var.region}"
}

provider "template" {
  version = "~> 1.0"
}
