# playbooks
GitOps and Ansible for the poseidon homelab cluster and the hosts around it.
Flux deploys everything on the cluster from `kubernetes/`; Ansible builds and
bootstraps the cluster, issues the local kubeconfig, and manages the DNS and
sensor hosts.

# Installing Ansible
```bash
./install-ansible.sh
```

# Secrets Management
Secrets are encrypted with age/sops, which the `setup.yaml` playbook installs
if they are not present. The personal age key is expected at
`~/.config/sops/age/keys.txt` and can decrypt every secret in the repository.
Files under `kubernetes/` are also encrypted to a cluster-only key that Flux
holds; see the Flux section below and `.sops.yaml`.

# Prerequisites
The `setup.yaml` playbook depends on `talosctl` to generate artifacts for cluster setup
and will also be needed for bootstrapping after the playbook is complete. It can be installed
using [this guide](https://docs.siderolabs.com/talos/v1.14/getting-started/talosctl). Be sure to install
the version that matches the version of Talos to be used for the cluster.

# Running Playbooks
To run the playbooks that manage the running cluster, use site.yaml:
```bash
ansible-playbook site.yaml
```

`setup.yaml` is not part of `site.yaml`. It generates Talos machine
configuration for a new cluster and mints a fresh admin client certificate each
time it runs, so it is a bootstrap step to run deliberately rather than on every
converge. `user.yaml` is left out for the same reason: it issues a new client
certificate and rewrites `~/.kube/config`, so run it when the kubeconfig needs
creating or renewing.

Individual playbooks can be run in a similar manner:
```bash
ansible-playbook setup.yaml
```

| Playbook         | Targets       | In `site.yaml` | Purpose                                                        |
|------------------|---------------|----------------|----------------------------------------------------------------|
| `setup.yaml`     | localhost     | no             | Generate Talos machine configs for the control plane nodes      |
| `user.yaml`      | localhost     | no             | Create the cluster user, sign its cert, write a kubeconfig      |
| `core.yaml`      | localhost     | yes            | Install Flux, which deploys the platform and applications       |
| `dns.yaml`       | `dns_servers` | no             | unbound, Pi-hole and keepalived on the DNS pair                 |
| `dewpoint.yaml`  | `dns_servers` | no             | The dewpoint Govee sensor Prometheus exporter                   |

`dns.yaml` and `dewpoint.yaml` run against the hosts in `inventory.yaml` rather
than localhost, and are kept out of `site.yaml` so that a full cluster run never
touches the DNS servers. Both support role tags:

```bash
ansible-playbook dns.yaml --tags pihole
```
# Flux
Flux deploys the whole cluster: the platform layers in
`kubernetes/infrastructure` and every application in `kubernetes/apps`.
Ansible's core role only installs the Flux Operator, the cluster's sops key,
and a FluxInstance that syncs `kubernetes/clusters/poseidon` from `main`. That
directory holds one Flux Kustomization per platform layer
(`infrastructure.yaml`) and per application (`apps.yaml`).

| Path                                          | Contents                                                     |
|-----------------------------------------------|--------------------------------------------------------------|
| `kubernetes/clusters/poseidon`                | Entry point: Helm repositories and one Kustomization per directory below |
| `kubernetes/infrastructure/flux-notifications`| Discord alerts for failed Flux reconciliations               |
| `kubernetes/infrastructure/<layer>`           | Platform layers, ordered bottom up by `dependsOn` in `infrastructure.yaml` |
| `kubernetes/apps/<app>`                       | The app's HelmRelease, plus its namespace, database and alerts where it owns them |
| `kubernetes/apps/barrelmaker`                 | The shared barrelmaker namespace, its quota and limit range  |

Differences from the Ansible roles:

- Merging to `main` deploys. Flux polls every minute, so there is no playbook
  run to trigger, and CI validates every kustomization before merge.
- There is no templating. Manifests hold literal values, so what is in Git is
  what is applied.
- sops files under `kubernetes/` are encrypted to a second, cluster-only age
  key as well as the personal one (see `.sops.yaml`). Flux holds that key as
  the `sops-age` Secret, and it cannot decrypt anything outside `kubernetes/`.
  A Helm values file stays a sops file and becomes a Secret through a
  kustomize `secretGenerator`, read by the HelmRelease's `valuesFrom`.
- Failed reconciliations post to the same Discord channel as Alertmanager,
  through a separate webhook named for Flux. Flux itself is watched from the
  other side too: Prometheus scrapes the controllers and the operator, and
  Alertmanager alerts if a Flux object stays not ready, a controller has no
  replicas, or its metrics stop (`prometheusrule-flux.yaml`), so a broken
  notification-controller cannot fail silently.
- HelmReleases fail forward: a failed install or upgrade is retried as
  written every 15 minutes and never rolled back, so the cluster does not drift
  from Git. Fix forward with a commit, or `git revert`. A StatefulSet stuck on a
  bad pod also needs that pod deleted by hand once the spec is fixed.
- Infrastructure is never pruned (removing a file does not uninstall it), its
  CRDs are marked `helm.sh/resource-policy: keep`, and its drift is reported
  rather than corrected until known operator-managed fields are ignored.
- Namespaces and database Clusters carry
  `kustomize.toolkit.fluxcd.io/prune: disabled`, so deleting their files never
  deletes their data.

Install or update Flux itself:
```bash
ansible-playbook core.yaml
# Try a branch before merging it; any later run without the override points
# Flux back at main
ansible-playbook core.yaml -e flux_sync_ref=refs/heads/<branch>
```

Day to day, with the [flux CLI](https://fluxcd.io/flux/installation/#install-the-flux-cli):
```bash
flux get all -A                                   # Status of every Flux object
flux reconcile kustomization devscura --with-source  # Apply now instead of waiting
flux diff kustomization devscura --path kubernetes/apps/devscura  # Preview local changes
flux suspend helmrelease devscura -n obscura-dev   # Pause while fixing by hand
flux resume helmrelease devscura -n obscura-dev
flux events -A                                    # Why something is not Ready
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
1. Generate the Talos machine configs and the ISO link:
   ```bash
   ansible-playbook setup.yaml
   ```
2. Boot the nodes from the ISO, then apply the configs and bootstrap etcd:
   ```bash
   # Node 1
   talosctl -n node1-poseidon.lan apply-config --insecure --file node1-poseidon.yaml
   talosctl -n node1-poseidon.lan -e node1-poseidon.lan bootstrap

   # Node 2
   talosctl -n node2-poseidon.lan apply-config --insecure --file node2-poseidon.yaml

   # Node 3
   talosctl -n node3-poseidon.lan apply-config --insecure --file node3-poseidon.yaml
   ```
3. Create the cluster user and the local kubeconfig:
   ```bash
   ansible-playbook user.yaml
   ```
4. Install Flux. It then builds the platform layer by layer, in the
   `dependsOn` order of `kubernetes/clusters/poseidon/infrastructure.yaml`, and
   the applications on top:
   ```bash
   ansible-playbook core.yaml
   flux get kustomizations --watch
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
