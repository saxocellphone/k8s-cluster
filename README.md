# k8s-cluster

GitOps repository for a homelab Kubernetes cluster managed by [Argo CD](https://argo-cd.readthedocs.io/).

## Cluster Overview

| Node | Role | OS | IP |
|---|---|---|---|
| talos-mru-smr | Control plane | Talos v1.11.5 | 192.168.8.227 |
| talos-gcx-zwd | Worker | Talos v1.11.5 | 192.168.8.126 |
| talos-pik-q76 | Worker | Talos v1.11.5 | 192.168.8.165 |
| carbon-node | Worker | Linux Mint 22.2 | 192.168.8.140 |

All nodes are amd64 architecture.

## Repository Structure

```
k8s-cluster/
├── apps/                       # Application workloads (Kustomize)
│   ├── openclaw/               #   AI agent gateway + Telegram bot
│   └── torrenting/             #   Media stack (qBittorrent, *arr, Postgres, etc.)
├── argocd/                     # Argo CD Application definitions
│   ├── app-of-apps.yaml        #   Root Application
│   ├── apps/                   #   App Applications (torrenting, openclaw, cluster-resources)
│   └── infrastructure/         #   Infrastructure Applications (Helm-based)
├── cluster/                    # Cluster-wide resources (Kustomize)
│   ├── persistent-volumes.yaml #   NFS PVs and PVCs
│   ├── storage-classes.yaml    #   local-storage StorageClass
│   ├── rbac.yaml               #   ClusterRoleBindings
│   └── prometheus-pv.yaml      #   Local PV for Prometheus
├── infrastructure/             # Helm values for infrastructure
│   ├── argocd/                 #   Argo CD
│   ├── ingress-nginx/          #   Ingress controller
│   ├── longhorn/               #   Distributed block storage
│   ├── metallb/                #   Bare-metal load balancer (+ CRs in resources/)
│   ├── monitoring/             #   kube-prometheus-stack (+ Grafana ingress)
│   └── nfs-provisioner/        #   NFS dynamic provisioner
├── scripts/                    # Operational scripts
│   ├── bootstrap-argocd.sh     #   Initial Argo CD installation
│   └── backup-postgres.sh      #   PostgreSQL backup
├── talos/                      # Talos machine configs (reference only, not Argo-managed)
├── .sops.yaml                  # SOPS encryption rules
└── key.txt                     # Age private key (NEVER committed, in .gitignore)
```

## How It Works

### Argo CD App-of-Apps

Argo CD watches this repo and automatically syncs cluster state from Git.

```
app-of-apps (argocd/app-of-apps.yaml)
├── torrenting          apps/torrenting/          Kustomize (directory)
├── openclaw            apps/openclaw/            Kustomize (directory)
├── cluster-resources   cluster/                  Kustomize (directory)
├── ingress-nginx       Helm chart                ingress-nginx namespace
├── longhorn            Helm chart                longhorn namespace
├── metallb             Helm chart                metallb-system namespace
├── metallb-config      infrastructure/metallb/   MetalLB CRs (IPAddressPool, L2Advertisement)
├── monitoring          Helm chart                monitoring namespace
├── monitoring-extras   infrastructure/monitoring/ Grafana ingress
└── nfs-provisioner     Helm chart                kube-system namespace
```

**Plain-manifest apps** (torrenting, openclaw, cluster-resources) use Kustomize with `kustomization.yaml` files that enumerate all resources.

**Infrastructure apps** use Helm charts with values stored in `infrastructure/<name>/values.yaml`. Argo CD uses multi-source Applications to reference both the upstream Helm chart and the values file from this repo.

### Sync Policies

- **selfHeal: true** on all apps -- manual `kubectl edit` changes get reverted automatically
- **prune: false** on workload apps -- removing a file from Git won't delete the resource (safety net)
- **prune: true** only on app-of-apps -- removing an Application YAML from `argocd/` deletes the Application

### Making Changes

1. Edit manifests or Helm values in this repo
2. Commit and push to `main`
3. Argo CD detects the change and syncs automatically (within ~3 minutes)
4. Verify in Argo CD UI at http://argocd.k8s.home

## Secret Management

Secrets are encrypted with [SOPS](https://github.com/getsops/sops) using [age](https://github.com/FiloSottile/age) encryption.

### Encrypted files

| File | Contents |
|---|---|
| `apps/torrenting/postgres/secret.yaml` | PostgreSQL credentials |
| `apps/torrenting/qbittorrent/secret.yaml` | ProtonVPN WireGuard config |
| `apps/openclaw/secret.yaml` | Anthropic API key, Telegram bot token |
| `apps/openclaw/tls-secret.yaml` | Self-signed TLS certificate |

### How it works

- `.sops.yaml` defines encryption rules: any file matching `*secret*.yaml` has its `data`/`stringData` fields encrypted
- The age private key (`key.txt`) is stored as a Kubernetes Secret (`sops-age`) in the `argocd` namespace
- Argo CD's repo-server uses [KSOPS](https://github.com/viaduct-ai/kustomize-sops) to decrypt secrets during kustomize builds
- Each directory with encrypted secrets has a `secret-generator.yaml` (KSOPS generator) referenced from `kustomization.yaml`

### Editing secrets

```bash
# Decrypt and edit in-place (requires key.txt)
SOPS_AGE_KEY_FILE=./key.txt sops apps/openclaw/secret.yaml

# Encrypt a new secret file
SOPS_AGE_KEY_FILE=./key.txt sops -e -i path/to/new-secret.yaml
```

**Never commit unencrypted secrets.** The `.gitignore` excludes `key.txt` and `*.dec.yaml`.

## Infrastructure Components

| Component | Chart | Namespace | Purpose |
|---|---|---|---|
| Argo CD | argo/argo-cd | argocd | GitOps controller |
| ingress-nginx | ingress-nginx | ingress-nginx | Ingress controller |
| Longhorn | longhorn | longhorn | Distributed block storage (Talos workers only) |
| MetalLB | metallb | metallb-system | Bare-metal LoadBalancer (192.168.8.200-220) |
| kube-prometheus-stack | kube-prometheus-stack | monitoring | Prometheus + Grafana |
| nfs-provisioner | nfs-subdir-external-provisioner | kube-system | NFS dynamic PV provisioner |

## Application Workloads

### Torrenting (media stack)

VPN-protected media management stack in the `torrenting` namespace.

| Service | Port | URL | Notes |
|---|---|---|---|
| qBittorrent | 8080 | http://qbit.k8s.home | StatefulSet with gluetun VPN sidecar |
| Prowlarr | 9696 | http://prowlarr.k8s.home | Indexer manager |
| Radarr | 7878 | http://radarr.k8s.home | Movie management |
| Sonarr | 8989 | http://sonarr.k8s.home | TV show management |
| FlareSolverr | 8191 | http://flaresolverr.k8s.home | CloudFlare solver |
| Audiobookshelf | 13378 | http://audiobooks.k8s.home | Audiobook server (scaled to 0) |
| PostgreSQL | 5432 | hostNetwork on carbon-node | Database for *arr apps |

### OpenClaw (AI gateway)

AI agent gateway with Telegram bot integration in the `openclaw` namespace.

| Service | Port | URL |
|---|---|---|
| OpenClaw Gateway | 18789 | https://openclaw.k8s.home |
| Chromium Browser | 9222 | Internal (CDP) |

## Storage

- **nfs-client** (default StorageClass) -- NFS volumes on 192.168.8.246
- **longhorn** -- Distributed block storage on Talos workers (talos-gcx-zwd, talos-pik-q76)
- **local-storage** -- Node-pinned local volumes

## Bootstrapping

For a fresh cluster or to reinstall Argo CD:

```bash
# 1. Ensure key.txt is in the repo root
# 2. Run the bootstrap script
./scripts/bootstrap-argocd.sh

# 3. Get the admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

The bootstrap script:
1. Adds the Argo CD Helm repo
2. Installs Argo CD with values from `infrastructure/argocd/values.yaml`
3. Creates the `sops-age` secret from `key.txt`
4. Applies the `app-of-apps.yaml` root Application
5. Argo CD then discovers and syncs all other Applications automatically

## Talos Machine Configs

The `talos/` directory contains Talos Linux machine configurations for reference. These are **not managed by Argo CD** -- Talos has its own lifecycle via `talosctl`.

| File | Purpose |
|---|---|
| controlplane.yaml | Control plane node config |
| worker.yaml | Base worker node config |
| longhorn-worker-patch.yaml | Patch to enable iSCSI + Longhorn extensions |
| longhorn-disk-patch-gcx.yaml | Dedicated Longhorn disk for talos-gcx-zwd |
| longhorn-disk-patch-pik.yaml | Dedicated Longhorn disk for talos-pik-q76 |
| longhorn-schematic.yaml | Talos schematic with extensions |

## Adding a New Application

1. Create a directory under `apps/<name>/` with your manifests
2. Add a `kustomization.yaml` listing all resources
3. If the app has secrets: encrypt them with SOPS, add `secret-generator.yaml` KSOPS generators
4. Create an Argo CD Application definition in `argocd/apps/<name>.yaml`
5. Commit and push -- Argo CD picks it up via app-of-apps

## Adding a New Helm-based Infrastructure Component

1. Create `infrastructure/<name>/values.yaml` with Helm value overrides
2. Create an Argo CD Application definition in `argocd/infrastructure/<name>.yaml` with:
   - `source.repoURL` pointing to the upstream Helm chart repo
   - `source.helm.valueFiles` referencing the values file via `$values` ref
   - A second source pointing to this Git repo with `ref: values`
3. Commit and push
