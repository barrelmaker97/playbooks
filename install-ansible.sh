#!/bin/bash
set -euo pipefail
sudo apt update
sudo apt install pipx
pipx ensurepath
pipx install --include-deps ansible
pipx inject ansible argcomplete kubernetes
pipx inject --include-apps ansible ansible-lint
