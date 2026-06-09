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
The core role deploys Envoy Gateway (Gateway API), which replaces the retired
ingress-nginx controller. The gateway and its Let's Encrypt certificates are
already live and validated on a temporary IP; the router forwards ports 80/443
to `192.168.15.60` (`gateway_ip`), which ingress-nginx holds until cutover.
Workload chart upgrades replace Ingresses with HTTPRoutes, so the switch
happens in one short window (a few minutes of external downtime):

1. Release the updated charts and merge this branch.
2. Free up the load balancer IP (external downtime starts):
   ```bash
   helm uninstall ingress-nginx -n ingress-nginx
   helm uninstall ingress -n barrelmaker  # legacy dotfiles redirect chart
   kubectl delete namespace ingress-nginx
   ```
3. Apply everything (gateway takes over the IP, issuers switch to the
   `gatewayHTTPRoute` solver, charts swap Ingresses for HTTPRoutes):
   ```bash
   ansible-playbook core.yaml
   ansible-playbook workloads.yaml
   ```
4. Verify external reachability of every host and confirm the ACME solver
   works through the gateway with a throwaway staging certificate:
   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: solver-test
     namespace: envoy-gateway-system
   spec:
     secretName: solver-test-tls
     dnsNames: [barrelmaker.dev]
     issuerRef: {name: letsencrypt-staging, kind: ClusterIssuer}
   EOF
   kubectl wait --for=condition=Ready certificate/solver-test \
     -n envoy-gateway-system --timeout=180s
   kubectl delete certificate solver-test -n envoy-gateway-system
   kubectl delete secret solver-test-tls -n envoy-gateway-system
   ```
5. Remove orphaned TLS secrets left behind by the deleted Ingresses
   (certificates now live in `envoy-gateway-system`):
   ```bash
   kubectl delete secret -n barrelmaker website-tls dotfiles-ingress-tls \
     jellyfin-tls niucraft-dynmap-tls obscura-tls dev-obscura-tls
   kubectl delete secret -n monitoring grafana-tls
   ```

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
