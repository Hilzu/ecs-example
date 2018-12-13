#!/usr/bin/env bash

set -euo pipefail

echo ECS_CLUSTER="${cluster_name}" >> /etc/ecs/ecs.config

yum update -y
