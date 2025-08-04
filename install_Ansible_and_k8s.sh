#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1. Install Ansible
###############################################################################
echo "▶️  Installing Ansible…"
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
echo "✅  Ansible installed."

###############################################################################
# 2. Run the Ansible-playbook
###############################################################################
ANSIBLE_PLAYBOOK_PATH="playbook.yml"
cd Ansible
echo "▶️  Running playbook: $ANSIBLE_PLAYBOOK_PATH"
ansible-playbook "$ANSIBLE_PLAYBOOK_PATH"
echo "✅  Playbook finished."
cd ..

