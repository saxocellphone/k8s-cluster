#!/usr/bin/env bash
# Dev sandbox entrypoint: real Ubuntu userland (git+https, ssh, certs) + OpenCode binary.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export HOME="${HOME:-/workspace/.home}"
export PATH="/tools/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"
export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"

# Idempotent package install (image is minimal Ubuntu; first start is slower).
need_pkgs=0
command -v git >/dev/null 2>&1 || need_pkgs=1
command -v git-remote-https >/dev/null 2>&1 || need_pkgs=1
command -v ssh >/dev/null 2>&1 || need_pkgs=1
command -v curl >/dev/null 2>&1 || need_pkgs=1
if [[ "$need_pkgs" -eq 1 ]] || [[ ! -f /var/lib/opencode-sandbox/.pkgs-ok ]]; then
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends \
    ca-certificates \
    curl \
    git \
    openssh-client \
    less \
    jq \
    python3 \
    build-essential \
    pkg-config
  update-ca-certificates || true
  mkdir -p /var/lib/opencode-sandbox
  touch /var/lib/opencode-sandbox/.pkgs-ok
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
  # Official install script; fallback to GitHub release tarball naming used by anomalyco/opencode.
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

# Smoke: HTTPS git must work (was broken with lone alpine `git` binary).
git --version
git remote-https 2>/dev/null || test -x "$(git --exec-path)/git-remote-https"
command -v kubectl >/dev/null && kubectl version --client=true || true
command -v docker >/dev/null && docker version --format '{{.Client.Version}}' || true

cd /workspace
# Headless: opencode web tries xdg-open → ENOENT noise / flaky startup in k8s.
export BROWSER="${BROWSER:-/bin/true}"
mkdir -p /usr/local/bin
if [[ ! -x /usr/local/bin/xdg-open ]]; then
  printf '%s\n' '#!/bin/sh' 'exit 0' >/usr/local/bin/xdg-open
  chmod 0755 /usr/local/bin/xdg-open
fi

# Advertise remote URLs in logs; clients must not use pod localhost from laptops.
echo "OpenCode remote attach (Basic auth OPENCODE_SERVER_USERNAME/PASSWORD):" >&2
echo "  opencode attach https://opencode.victornazzaro.com -u \"\$OPENCODE_SERVER_USERNAME\" -p \"\$OPENCODE_SERVER_PASSWORD\"" >&2
echo "  opencode attach http://opencode.k8s.home -u \"\$OPENCODE_SERVER_USERNAME\" -p \"\$OPENCODE_SERVER_PASSWORD\"" >&2
echo "  browser: https://opencode.victornazzaro.com or http://opencode.k8s.home" >&2

exec opencode web \
  --hostname 0.0.0.0 \
  --port 4096 \
  --cors https://opencode.victornazzaro.com \
  --cors http://opencode.k8s.home \
  --cors http://localhost:5173 \
  --cors http://127.0.0.1:5173 \
  --cors http://localhost:4096 \
  --cors http://127.0.0.1:4096
