# playbooks
Personal Ansible Playbook Library

# Installing Ansible
```bash
sudo apt update
sudo apt install pipx
pipx ensurepath
pipx install --include-deps ansible
pipx inject ansible argcomplete kubernetes
pipx inject --include-apps ansible ansible-lint
```

# License

Copyright (c) 2024 Nolan Cooper

This chart collection is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This chart collection is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this chart collection.  If not, see <https://www.gnu.org/licenses/>.
