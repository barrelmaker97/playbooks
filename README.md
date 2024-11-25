# playbooks
Personal Ansible Playbook Library

# Installing Ansible
```bash
./install-ansible.sh
```

# Running Playbooks
To run all playbooks, use site.yaml:
```bash
ansible-playbook site.yaml
```

Individual playbooks can be run in a similar manner:
```bash
ansible-playbook cluster_user.yaml
```
# IP Plan
| Name       | Address       | Hostname           |
|------------|---------------|--------------------|
| Virtual IP | 192.168.15.40 | kube.poseidon.lan  |
| Node 1     | 192.168.15.41 | node1-poseidon.lan |
| Node 2     | 192.168.15.42 | node2-poseidon.lan |
| Node 3     | 192.168.15.43 | node3-poseidon.lan |

# Cluster Bootstrap
## Node 1
```bash
talosctl -n node1-poseidon.lan apply-config --insecure --file node1-poseidon.yaml
talosctl -n node1-poseidon.lan -e node1-poseidon.lan bootstrap
talosctl -n node1-poseidon.lan -e node1-poseidon.lan patch mc --patch @nut-extension.yaml
talosctl -n node1-poseidon.lan -e node1-poseidon.lan kubeconfig
```

## Node 2
```bash
talosctl -n node2-poseidon.lan apply-config --insecure --file node2-poseidon.yaml
talosctl -n node2-poseidon.lan -e node2-poseidon.lan patch mc --patch @nut-extension.yaml
```

## Node 3
```bash
talosctl -n node3-poseidon.lan apply-config --insecure --file node3-poseidon.yaml
talosctl -n node3-poseidon.lan -e node3-poseidon.lan patch mc --patch @nut-extension.yaml
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
