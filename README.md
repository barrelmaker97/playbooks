# homelab
GitOps and Ansible for the poseidon homelab cluster and the hosts around it.
Flux deploys everything on the cluster from `kubernetes/`; Ansible builds and
bootstraps the cluster, issues the local kubeconfig, and manages the DNS and
sensor hosts.

# Repository Layout
| Path          | Contents                                                              |
|---------------|-----------------------------------------------------------------------|
| `kubernetes/` | Everything on the cluster, deployed by Flux from `main` (see Flux below) |
| `ansible/`    | Playbooks for what Flux cannot do: build and bootstrap the cluster, issue the local kubeconfig, and manage the DNS and sensor hosts |

# Tools
Every tool the repository uses is pinned in `mise.toml`: kubectl, talosctl,
flux, helm, the CloudNativePG kubectl plugin, sops, age, kubeconform, flate,
and Ansible with ansible-lint. CI installs from the same file.

1. [Install mise](https://mise.jdx.dev/installing-mise.html) and activate it
   in your shell.
2. From the repository root:
   ```bash
   mise install          # the pinned tools
   mise run collections  # the Ansible collections in ansible/requirements.yml
   ```

talosctl is pinned to the cluster's Talos version (`talos_version` in
`ansible/vars/setup.yaml`); bump both together.

# Secrets Management
Secrets are encrypted with age/sops. The personal age key is expected at
`~/.config/sops/age/keys.txt` and can decrypt every secret in the repository.
Files under `kubernetes/` are also encrypted to a cluster-only key that Flux
holds; see the Flux section below and `.sops.yaml`.

# Running Playbooks
Playbooks run from `ansible/`, where its `ansible.cfg`, inventory and
`group_vars` apply:
```bash
cd ansible
ansible-playbook user.yaml
ansible-playbook dns.yaml --tags pihole
```

| Playbook        | Targets       | Purpose                                                          |
|-----------------|---------------|------------------------------------------------------------------|
| `setup.yaml`    | localhost     | Generate Talos machine configs for the control plane nodes        |
| `user.yaml`     | localhost     | Create the cluster user, sign its cert, write a kubeconfig        |
| `flux.yaml`     | localhost     | Bootstrap Flux, which then manages itself and the whole cluster   |
| `dns.yaml`      | `dns_servers` | unbound, Pi-hole and keepalived on the DNS pair                   |
| `dewpoint.yaml` | `dns_servers` | The dewpoint Govee sensor Prometheus exporter                     |

None of them is meant to run on a schedule. `setup.yaml` mints a fresh Talos
admin certificate and `user.yaml` a fresh client certificate on every run, so
run them when building the cluster or renewing the kubeconfig. `flux.yaml` only
acts on a cluster missing Flux. `dns.yaml` and `dewpoint.yaml` run against the
hosts in `inventory.yaml`, and both support role tags.

# Flux
Flux deploys the whole cluster: the platform layers in
`kubernetes/infrastructure` and every application in `kubernetes/apps`.
Flux also manages itself: the Flux Operator's HelmRelease and the FluxInstance
live in `kubernetes/clusters/poseidon/flux-system`, so upgrading the operator
or Flux is a commit there. The FluxInstance syncs `kubernetes/clusters/poseidon`
from `main`, which holds one Flux Kustomization per platform layer
(`infrastructure.yaml`) and per application (`apps.yaml`). Ansible's `flux`
role only bootstraps: it installs the cluster's sops key, and the operator and
FluxInstance from those same files when they are missing.

| Path                                          | Contents                                                     |
|-----------------------------------------------|--------------------------------------------------------------|
| `kubernetes/clusters/poseidon`                | Entry point: Flux itself (`flux-system/`), chart sources, and one Kustomization per directory below |
| `kubernetes/infrastructure/flux-notifications`| Discord alerts for failed Flux reconciliations               |
| `kubernetes/infrastructure/<layer>`           | Platform layers, ordered bottom up by `dependsOn` in `infrastructure.yaml` |
| `kubernetes/apps/<app>`                       | The app's HelmRelease, plus its namespace, database and alerts where it owns them |
| `kubernetes/apps/barrelmaker`                 | The shared barrelmaker namespace, its quota and limit range  |

Differences from the Ansible roles:

- Merging to `main` deploys. Flux polls every minute, so there is no playbook
  run to trigger. Before merge, CI validates every kustomization's schema
  (kubeconform), renders the whole cluster offline the way Flux will, charts
  and post-renderers included ([flate](https://github.com/home-operations/flate)),
  and comments the rendered diff on the PR. To preview locally:
  `flate diff all --path ./kubernetes --base main`.
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
- Infrastructure is never pruned (removing a file does not uninstall it) and
  its CRDs are marked `helm.sh/resource-policy: keep`.
- Every HelmRelease corrects drift: a change made by hand to an object a chart
  manages is reverted. Fields that operators manage themselves, such as the CA
  bundles cert-manager injects into webhooks, are not owned by Helm and are left
  alone.
- Namespaces and database Clusters carry
  `kustomize.toolkit.fluxcd.io/prune: disabled`, so deleting their files never
  deletes their data.

Upgrade Flux by editing `flux-system/flux-instance.yaml` (the Flux version)
or `flux-system/flux-operator.yaml` (the operator chart) and merging. To
bootstrap a cluster without Flux, or recover one that lost it:
```bash
cd ansible && ansible-playbook flux.yaml
```

Because Flux syncs its own FluxInstance from `main`, it cannot simply be
pointed at a branch: it would sync the branch's FluxInstance and point itself
back. Preview a change against the cluster with `flux diff kustomization` (below)
instead.

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
   cd ansible
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
4. Bootstrap Flux. It then builds the platform layer by layer, in the
   `dependsOn` order of `kubernetes/clusters/poseidon/infrastructure.yaml`, and
   the applications on top:
   ```bash
   ansible-playbook flux.yaml
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
Bump `talosctl` in `mise.toml` to the new Talos version, then `mise install`.

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
