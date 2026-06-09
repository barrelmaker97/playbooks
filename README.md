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

# Gateway API Cutover (ingress-nginx removal)
The core role deploys Envoy Gateway (Gateway API) which replaces the retired
ingress-nginx controller. The router forwards ports 80/443 to `192.168.15.60`,
which ingress-nginx holds until cutover. To migrate without downtime:

1. Run the playbooks with `gateway_ip: 192.168.15.65` (transition IP). Both
   ingress-nginx and the gateway will serve all hosts side by side.
2. Seed the gateway's TLS secrets from the existing ones so the HTTPS
   listeners are valid immediately (cert-manager adopts and renews them later):
   ```bash
   for s in website-tls:barrelmaker:website-tls \
            dotfiles-ingress-tls:barrelmaker:dotfiles-tls \
            jellyfin-tls:barrelmaker:jellyfin-tls \
            niucraft-dynmap-tls:barrelmaker:niucraft-tls \
            obscura-tls:barrelmaker:obscura-tls \
            dev-obscura-tls:barrelmaker:devscura-tls \
            grafana-tls:monitoring:grafana-tls; do
     IFS=: read -r old ns new <<< "$s"
     kubectl get secret "$old" -n "$ns" -o json \
       | jq 'del(.metadata) | .metadata = {name: "'"$new"'", namespace: "envoy-gateway-system"}' \
       | kubectl apply -f -
   done
   ```
3. Validate every host against the gateway, e.g.:
   ```bash
   curl -sI --resolve barrelmaker.dev:443:192.168.15.65 https://barrelmaker.dev
   ```
4. Cutover (a few seconds of downtime while MetalLB reassigns the IP):
   ```bash
   helm uninstall ingress-nginx -n ingress-nginx
   ```
   Then set `gateway_ip: 192.168.15.60` in `group_vars/all.yaml` and re-run
   the core playbook. Old Ingress resources are removed by the workload chart
   upgrades; certificate renewals are validated through the gateway
   (`gatewayHTTPRoute` solver) from this point on.
5. Verify external reachability and certificate issuance, then clean up:
   orphaned `*-tls` secrets in the `barrelmaker`/`monitoring` namespaces and
   the empty `ingress-nginx` namespace.

# License

Copyright (c) 2026 Nolan Cooper

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
