# Agent notes — `k8s-cluster` (homelab GitOps)

This tree is the **homelab** Kubernetes GitOps source of truth (`saxocellphone/k8s-cluster`), managed by Argo CD.

## Kubernetes context guard

When working **in this repository** (cwd under `k8s-cluster`, or OpenCode workspace for this repo):

1. Prefer explicit config: `kubectl --kubeconfig=./kubeconfig` and `talosctl --talosconfig=./talosconfig` from the **repo root** (see `CLAUDE.md` / `README.md`).
2. **Do not** trust ambient `~/.kube/config` or “whatever context is selected” on a laptop or shared agent host.
3. **Before** any cluster-mutating or diagnostic command that uses the default kubeconfig, confirm you are on **this** cluster, for example:
   ```bash
   kubectl --kubeconfig=./kubeconfig config current-context   # or: kubectl config current-context
   kubectl --kubeconfig=./kubeconfig cluster-info
   kubectl --kubeconfig=./kubeconfig get nodes
   ```
   Cross-check against what this repo expects (homelab node names / `*.k8s.home` / Argo at `argocd.k8s.home` — see `README.md`). If the API, node set, or context clearly belongs to a **different** cluster, **stop** and switch to `./kubeconfig` from this repo (or ask the operator). Never apply or debug this GitOps tree against the wrong cluster.
4. If unsure, prefer **read-only** checks with `--kubeconfig=./kubeconfig` only, or ask.

OpenCode **on the homelab cluster** already uses **in-cluster** credentials for that cluster; the main risk is **local attach / CI / multi-kubeconfig agents** mixing contexts.

## See also

- `CLAUDE.md` — full agent guidance for this repo
- `apps/opencode/` — seeded `AGENTS.md` for the in-cluster OpenCode sandbox (synced from ConfigMap)
