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
using [this guide](https://www.talos.dev/v1.13/talos-guides/install/talosctl/). Be sure to install
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

| Playbook         | Targets       | In `site.yaml` | Purpose                                                        |
|------------------|---------------|----------------|----------------------------------------------------------------|
| `setup.yaml`     | localhost     | yes            | Generate Talos machine configs for the control plane nodes      |
| `user.yaml`      | localhost     | yes            | Create the cluster user, sign its cert, write a kubeconfig      |
| `core.yaml`      | localhost     | yes            | Storage, networking, certificates and the monitoring stack      |
| `workloads.yaml` | localhost     | yes            | Namespaces, PostgreSQL clusters and application Helm releases   |
| `dns.yaml`       | `dns_servers` | no             | unbound, Pi-hole and keepalived on the DNS pair                 |
| `dewpoint.yaml`  | `dns_servers` | no             | The dewpoint Govee sensor Prometheus exporter                   |

`dns.yaml` and `dewpoint.yaml` run against the hosts in `inventory.yaml` rather
than localhost, and are deliberately not part of `site.yaml` so that a full
cluster run never touches the DNS servers. Both support role tags:

```bash
ansible-playbook dns.yaml --tags pihole
```
# IP Plan
### Cluster
| Name         | Address                     | Hostname           |
|--------------|-----------------------------|--------------------|
| Virtual IP   | 192.168.15.40               | kube.poseidon.lan  |
| Node 1       | 192.168.15.41               | node1-poseidon.lan |
| Node 2       | 192.168.15.42               | node2-poseidon.lan |
| Node 3       | 192.168.15.43               | node3-poseidon.lan |
| MetalLB pool | 192.168.15.60-192.168.15.69 |                    |
| Gateway      | 192.168.15.60               | poseidon.lan       |

### DNS
| Name       | Address       | Hostname   | Role   |
|------------|---------------|------------|--------|
| Virtual IP | 192.168.15.80 |            |        |
| Castor     | 192.168.15.70 | castor.lan | MASTER |
| Pollux     | 192.168.15.30 | pollux.lan | BACKUP |

# Cluster Bootstrap
```bash
# Node 1
talosctl -n node1-poseidon.lan apply-config --insecure --file node1-poseidon.yaml
talosctl -n node1-poseidon.lan -e node1-poseidon.lan bootstrap
talosctl -n node1-poseidon.lan -e node1-poseidon.lan kubeconfig

# Node 2
talosctl -n node2-poseidon.lan apply-config --insecure --file node2-poseidon.yaml

# Node 3
talosctl -n node3-poseidon.lan apply-config --insecure --file node3-poseidon.yaml
```

# Cluster Upgrade
## Upgrade Talos
Be sure to wait for upgrade to complete on each node before proceeding to the next one. This means waiting for all workloads to be in a good state.
```bash
# Node 1
talosctl -e node2-poseidon.lan -n node1-poseidon.lan upgrade --image factory.talos.dev/installer/<Image ID>:<Talos Version>

# Node 2
talosctl -e node1-poseidon.lan -n node2-poseidon.lan upgrade --image factory.talos.dev/installer/<Image ID>:<Talos Version>

# Node 3
talosctl -e node1-poseidon.lan -n node3-poseidon.lan upgrade --image factory.talos.dev/installer/<Image ID>:<Talos Version>
```
## Upgrade Talosctl
Download the talosctl binary from the Github release page for the correct architecture. Then move it to the correct location and make sure it is executable. For example:
```bash
sudo mv ./talosctl-linux-amd64 /usr/local/bin/talosctl
sudo chmod +x /usr/local/bin/talosctl
```

## Upgrade Kubernetes
```bash
talosctl -n node1-poseidon.lan upgrade-k8s --dry-run
talosctl -n node1-poseidon.lan upgrade-k8s
```

# License

Copyright (c) 2026 Nolan Cooper

These playbooks are free software: you can redistribute them and/or modify
them under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

They are distributed in the hope that they will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with these playbooks.  If not, see <https://www.gnu.org/licenses/>.
