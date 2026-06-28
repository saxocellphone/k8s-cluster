#!/usr/bin/env bash
# Dev sandbox entrypoint: real Ubuntu userland (git+https, ssh, certs) + OpenCode binary.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export HOME="${HOME:-/workspace/.home}"
export PATH="/tools/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"

# Persist apt marker on the workspace PVC — emptyDir was wiped every pod restart,
# so apt-get ran for minutes while clients saw "Unable to connect" / CORS failures.
PKG_MARK="${HOME}/.opencode-sandbox-pkgs-ok"
need_pkgs=0
command -v git >/dev/null 2>&1 || need_pkgs=1
# git-remote-https is required for https:// remotes
if ! git remote-https >/dev/null 2>&1 && [[ ! -x "$(git --exec-path 2>/dev/null)/git-remote-https" ]]; then
  need_pkgs=1
fi
command -v ssh >/dev/null 2>&1 || need_pkgs=1
command -v curl >/dev/null 2>&1 || need_pkgs=1
if [[ "$need_pkgs" -eq 1 ]] || [[ ! -f "$PKG_MARK" ]]; then
  apt-get update -qq
  # Keep lean — no build-essential (slow + unnecessary for web server).
  apt-get install -y -qq --no-install-recommends \
    ca-certificates \
    curl \
    git \
    openssh-client \
    less \
    jq \
    python3
  update-ca-certificates || true
  mkdir -p "$(dirname "$PKG_MARK")"
  touch "$PKG_MARK"
fi

# OpenCode CLI (pinned). Prefer tools volume (seeded by init) then install to /usr/local/bin.
OPENCODE_VER="${OPENCODE_VERSION:-1.17.11}"
if [[ -x /tools/bin/opencode ]]; then
  ln -sfn /tools/bin/opencode /usr/local/bin/opencode
elif ! command -v opencode >/dev/null 2>&1 || ! opencode --version 2>/dev/null | grep -q "$OPENCODE_VER"; then
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) asset="opencode-linux-x64.tar.gz" ;;
    aarch64|arm64) asset="opencode-linux-arm64.tar.gz" ;;
    *) asset="opencode-linux-x64.tar.gz" ;;
  esac
  tmp="$(mktemp -d)"
  if curl -fsSL "https://opencode.ai/install" | bash -s -- --version "$OPENCODE_VER" 2>/dev/null; then
    :
  else
    url="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VER}/${asset}"
    curl -fsSL "$url" -o "$tmp/oc.tgz" || curl -fsSL "https://github.com/sst/opencode/releases/download/v${OPENCODE_VER}/${asset}" -o "$tmp/oc.tgz"
    tar -xzf "$tmp/oc.tgz" -C "$tmp"
    install -m 0755 "$(find "$tmp" -type f -name opencode | head -1)" /usr/local/bin/opencode
  fi
  rm -rf "$tmp"
fi

git --version
git remote-https 2>/dev/null || test -x "$(git --exec-path)/git-remote-https"
command -v kubectl >/dev/null && kubectl version --client=true || true
command -v docker >/dev/null && docker version --format '{{.Client.Version}}' || true

cd /workspace

# Headless: opencode web tries xdg-open (ENOENT) in k8s.
export BROWSER="${BROWSER:-/bin/true}"
if [[ ! -x /usr/local/bin/xdg-open ]]; then
  printf '%s\n' '#!/bin/sh' 'exit 0' >/usr/local/bin/xdg-open
  chmod 0755 /usr/local/bin/xdg-open
fi

echo "OpenCode remote (Basic auth OPENCODE_SERVER_USERNAME / OPENCODE_SERVER_PASSWORD):" >&2
echo "  Desktop: connect to https://opencode.victornazzaro.com with username/password" >&2
echo "  CLI:     ./scripts/opencode-attach.sh" >&2
echo "  LAN:     http://opencode.k8s.home (DNS → ingress LB)" >&2
echo "  Do not use localhost:4096 on your laptop." >&2

# oc://renderer = OpenCode Desktop app origin (CORS for remote server)
exec opencode web \
  --hostname 0.0.0.0 \
  --port 4096 \
  --cors https://opencode.victornazzaro.com \
  --cors http://opencode.k8s.home \
  --cors oc://renderer \
  --cors oc://opencode \
  --cors http://localhost:5173 \
  --cors http://127.0.0.1:5173 \
  --cors http://localhost:4096 \
  --cors http://127.0.0.1:4096
