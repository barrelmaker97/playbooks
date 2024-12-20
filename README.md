# playbooks
Personal Ansible Playbook Library

# Installing Ansible
```bash
./install-ansible.sh
```

# Secrets Management
Secret values needed for playbooks are encrypted with age/sops,
which will be installed by the `setup.yaml` playbook if they are not present.
The age key file is expected to be at `~/.config/sops/age/keys.txt`.

# Prerequisites
The `setup.yaml` playbook depends on `talosctl` to generate artifacts for cluster setup
and will also be needed for bootstrapping after the playbook is complete. It can be installed
using [this guide](https://www.talos.dev/v1.9/talos-guides/install/talosctl/). Be sure to install
the version that matches the version of Talos to be used for the cluster.

# Running Playbooks
To run all playbooks, use site.yaml:
```bash
ansible-playbook site.yaml
```

Individual playbooks can be run in a similar manner:
```bash
ansible-playbook setup.yaml
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
talosctl -n node1-poseidon.lan -e node1-poseidon.lan kubeconfig
```

## Node 2
```bash
talosctl -n node2-poseidon.lan apply-config --insecure --file node2-poseidon.yaml
```

## Node 3
```bash
talosctl -n node3-poseidon.lan apply-config --insecure --file node3-poseidon.yaml
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
