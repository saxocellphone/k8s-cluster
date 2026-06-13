# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

GitOps source-of-truth for a 4-node homelab Kubernetes cluster (3x Talos Linux + 1x Linux Mint). Argo CD watches `main` and reconciles cluster state. There is no build/test/lint pipeline — changes are YAML, validated by Argo CD on sync.

See `README.md` for the node table, component list, ingress URLs, secret/SOPS workflow, and bootstrap procedure. Don't duplicate that here; read it when you need it.

## Mental model: how a change reaches the cluster

1. Edit a manifest or a Helm `values.yaml` under `apps/`, `cluster/`, or `infrastructure/`.
2. Commit and **push to the remote** — Argo CD reads from GitHub, not the local working tree.
3. The local `.git/hooks/post-commit` hook hits the Argo CD API to hard-refresh `app-of-apps`, which cascades to all child Applications. Without the push, the refresh sees stale state.
4. Verify in the Argo CD UI (`http://argocd.k8s.home`) or with `kubectl --kubeconfig=./kubeconfig get applications -n argocd`.

The repo root contains `kubeconfig` and `talosconfig` (gitignored). Use them with `--kubeconfig=./kubeconfig` and `--talosconfig=./talosconfig` rather than relying on `~/.kube/config`, so commands match what's in this repo.

**On a new machine**, only `talosconfig` needs to be transferred securely (1Password, scp, AirDrop). Then `./scripts/regenerate-kubeconfig.sh` derives a working kubeconfig from it. Avoids transferring two secrets when one is sufficient.

## Two flavors of Argo CD Application — know which you're touching

Look in `argocd/`:

- **`argocd/apps/*.yaml`** — single-source `Application`s pointing at a directory under `apps/` or `cluster/`. Kustomize-rendered. Adding/removing files changes what gets applied.
- **`argocd/infrastructure/*.yaml`** — multi-source `Application`s. One source is the upstream Helm chart repo (e.g. `https://prometheus-community.github.io/helm-charts`), the other is *this* repo with `ref: values`, and `helm.valueFiles` references `$values/infrastructure/<name>/values.yaml`. To change behavior, edit the values file — do **not** vendor the chart.
- `argocd/infrastructure/monitoring.yaml` is the exception that proves the rule: it declares both `monitoring` (the Helm chart) and `monitoring-extras` (a plain Kustomize directory at `infrastructure/monitoring/` that excludes `values.yaml`). When adding sibling resources to a Helm-managed component (e.g. an Ingress for Grafana), follow this pattern instead of forking the chart.

## Sync policy invariants

- `selfHeal: true` cluster-wide — manual `kubectl edit` is reverted within seconds. To experiment, disable selfHeal on the Application first or your changes will vanish.
- `prune: false` on every workload/infrastructure Application — deleting a file or `resources:` entry will **not** remove the live object. Either delete it manually with `kubectl delete`, or temporarily set `prune: true`.
- `prune: true` only on `app-of-apps` — removing an `Application` YAML from `argocd/apps/` or `argocd/infrastructure/` *will* delete the Application (but its workloads survive due to the per-app `prune: false`).

## Secrets — SOPS + KSOPS

- `.sops.yaml` encrypts `data` / `stringData` of any file matching `*secret*.yaml`. Naming is load-bearing: a secret file not matching the regex will be committed in plaintext.
- The age private key lives in `key.txt` at repo root (gitignored, mode 600). The same key is mounted into the Argo CD repo-server as a Secret named `sops-age` in the `argocd` namespace, created during bootstrap.
- Each directory containing encrypted secrets ships a `*-secret-generator.yaml` (KSOPS generator referencing the secret file by relative path) and lists it under `generators:` (not `resources:`) in `kustomization.yaml`. Adding a new encrypted secret requires both the generator file and the kustomization entry, otherwise it never reaches the cluster.
- **KSOPS path gotcha**: in `secret-generator.yaml`, the `files:` paths are resolved relative to the **kustomization root** (where `kustomization.yaml` lives), not the generator file's directory. So a generator at `apps/torrenting/bootstrap/secret-generator.yaml` referenced from `apps/torrenting/kustomization.yaml` must use `files: - ./bootstrap/secret.yaml`, not `./secret.yaml`.

```bash
# Edit an encrypted secret in place
SOPS_AGE_KEY_FILE=./key.txt sops apps/openclaw/secret.yaml

# Encrypt a brand-new secret file (filename must match *secret*.yaml)
SOPS_AGE_KEY_FILE=./key.txt sops -e -i path/to/new-secret.yaml
```

## Storage — pick the right class

- **`nfs-client`** (default) — NFS at 192.168.8.246. Use for config volumes and shared data. Avoid for write-heavy workloads (Prometheus TSDB/WAL, Postgres) — latency and locking semantics will bite.
- **`longhorn`** — distributed block storage, **only** scheduled on Talos workers labeled `extensions.talos.dev/iscsi-tools: v0.2.0` (currently `talos-gcx-zwd`, `talos-worker-pve191-01`, `talos-gpu-01`). Workloads using Longhorn must carry a matching `nodeSelector`. Use for databases, Prometheus, anything stateful and write-heavy.
- **`local-storage`** — node-pinned hostPath. **Do not use on Talos nodes** — the immutable rootfs means arbitrary host paths may not exist after a reboot and the mount fails. OK on `carbon-node` (Linux Mint) only.
- **PVCs are immutable.** Changing `storageClassName` in a Helm value or StatefulSet will not migrate an existing PVC. Procedure: scale workload to 0 → `kubectl delete pvc` (mind the `pvc-protection` finalizer — it clears once no pod references the PVC) → re-sync → operator recreates on the new class. Back data up first.

## PodSecurity

- Cluster default is `baseline:latest` enforcement (set in Talos admission config). Only `kube-system` is exempt out-of-the-box.
- Anything that needs `hostNetwork`, `hostPID`, `hostPath`, `hostPort`, or privileged containers (notably `node-exporter`, `qbittorrent`'s VPN sidecar, the Postgres pod on `carbon-node`) needs its namespace labeled `pod-security.kubernetes.io/enforce: privileged`.
- Persist that label via `spec.syncPolicy.managedNamespaceMetadata.labels` on the Argo CD Application (see `argocd/infrastructure/monitoring.yaml`). **Chicken-and-egg warning:** if the very pod whose admission is failing is what's blocking the sync, `managedNamespaceMetadata` may never apply. Label the namespace by hand first, then let Argo take over.

## Common operations

```bash
# Fast-refresh a single Application (the post-commit hook only refreshes app-of-apps)
kubectl --kubeconfig=./kubeconfig annotate app <name> -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# See what an Application is waiting on when sync is stuck
kubectl --kubeconfig=./kubeconfig get app <name> -n argocd \
  -o jsonpath='{.status.operationState.message}'

# Bootstrap a fresh cluster (after key.txt is in place)
./scripts/bootstrap-argocd.sh

# Snapshot all torrenting-stack Postgres DBs to NFS, with 7-day retention
./scripts/backup-postgres.sh
```

When `sync` blocks on one unhealthy resource, *every* other change in that Application waits behind it. Fix or delete the blocker before expecting unrelated edits to land.

## Adding things — quick reference

- **New plain-manifest app:** create `apps/<name>/` with manifests and a `kustomization.yaml`; create `argocd/apps/<name>.yaml` (copy `torrenting.yaml` as a template); commit & push.
- **New Helm-based infra component:** create `infrastructure/<name>/values.yaml`; create `argocd/infrastructure/<name>.yaml` using the multi-source pattern with `ref: values` and `$values/infrastructure/<name>/values.yaml`; commit & push.
- **New encrypted secret:** name the file `*secret*.yaml`, encrypt with `sops -e -i`, add a sibling `*-secret-generator.yaml` (KSOPS), and list the generator under `generators:` in the directory's `kustomization.yaml` with the path relative to the kustomization root.

## Talos node configs

`talos/` holds machine configs for reference. They are **not** Argo-managed — changes apply via `talosctl --talosconfig=./talosconfig apply-config`. Be deliberate: a bad config can brick a node until you reinstall.

## Proxmox VMs as Terraform

`terraform/proxmox/` declares the VMs that host the Talos cluster (and other workloads) using the bpg/proxmox provider with two aliased provider blocks (one per Proxmox host — they're not clustered). State lives **in-cluster** as `Secret/terraform-state/tfstate-default-proxmox` via the `kubernetes` backend; locking uses a Lease in the same namespace, so any operator with `./kubeconfig` can run plan/apply without clobbering. The Proxmox API tokens are stored alongside, as a SOPS-encrypted Secret managed by `apps/terraform-state/` — load them into your shell with `source scripts/tf-env.fish`. See `terraform/proxmox/README.md` for the full flow. Apply changes with `terraform plan` / `terraform apply` from that directory; this is **separate from Argo CD's GitOps loop** — Terraform doesn't run automatically on commit (yet).
