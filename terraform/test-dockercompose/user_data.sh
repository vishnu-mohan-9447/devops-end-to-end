#!/bin/bash
# Minimal bootstrap only. Jenkins, Docker, and Docker Compose are
# installed and configured by the Ansible playbook in Phase 3 -
# this script just ensures the host is reachable by Ansible.
set -euo pipefail

apt-get update -y
apt-get install -y python3 python3-apt
