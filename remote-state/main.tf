provider "aws" {
  version = "~> 1.56"
  region = "${var.region}"
}

resource "aws_s3_bucket" "tf_remote_state" {
  bucket_prefix = "${var.project}-tf-remote-state-"
  acl = "private"

  versioning {
    enabled = true
  }
}

resource "aws_dynamodb_table" "tf_locking" {
  name = "${var.project}-tf-locking"
  hash_key = "LockID"
  read_capacity = 1
  write_capacity = 1

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "remote_state_bucket_id" {
  value = "${aws_s3_bucket.tf_remote_state.id}"
}

output "remote_state_locking_table_id" {
  value = "${aws_dynamodb_table.tf_locking.id}"
}

output "region" {
  value = "${var.region}"
}
