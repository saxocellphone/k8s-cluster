# Agent notes — `k8s-cluster` (homelab GitOps)

This tree is the **homelab** Kubernetes GitOps source of truth (`saxocellphone/k8s-cluster`), managed by Argo CD. It is **not** an xMoney / corporate cluster repo.

## Kubernetes context guard

When working **in this repository** (cwd under `k8s-cluster`, or OpenCode workspace for this repo):

1. Prefer explicit config: `kubectl --kubeconfig=./kubeconfig` and `talosctl --talosconfig=./talosconfig` from the **repo root** (see `CLAUDE.md` / `README.md`).
2. **Do not** trust ambient `~/.kube/config` or “whatever context is selected” on a laptop or shared agent host.
3. **Before** any cluster-mutating or diagnostic command that uses the default kubeconfig, check:
   ```bash
   kubectl config current-context
   ```
   - If the context name contains **`xmoney`** (case-insensitive), **stop**. Switch away or pass `--kubeconfig` pointing at **this** repo’s `./kubeconfig`.
   - Do not `apply`, `delete`, `scale`, or “fix prod” against an xMoney context while this repo is the task context.
4. If unsure which cluster a context points at, prefer **read-only** checks with an explicit `--kubeconfig=./kubeconfig`, or ask the operator.

OpenCode on the **homelab cluster** already uses **in-cluster** credentials for that cluster; the main risk is **local attach / CI / multi-kubeconfig agents** mixing contexts.

## See also

- `CLAUDE.md` — full agent guidance for this repo
- `apps/opencode/` — seeded `AGENTS.md` for the in-cluster OpenCode sandbox (synced from ConfigMap)
