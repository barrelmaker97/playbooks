#!/bin/bash
set -euo pipefail
# requirements.yml is referenced relatively, so run from the script's directory
cd "$(dirname "$0")"
sudo apt update
sudo apt install -y pipx
pipx ensurepath
pipx install --include-deps ansible
pipx inject ansible argcomplete kubernetes
pipx inject --include-apps ansible ansible-lint
ansible-galaxy collection install -r requirements.yml
