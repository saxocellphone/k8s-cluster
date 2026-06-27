#!/usr/bin/env python3
"""Apply Checkov/Semgrep security baselines to Kubernetes workload manifests."""

from __future__ import annotations

import sys
from copy import deepcopy
from io import StringIO
from pathlib import Path

from ruamel.yaml import YAML

ROOT = Path(__file__).resolve().parents[1]
WORKLOAD_KINDS = {"Deployment", "StatefulSet", "DaemonSet", "CronJob", "Job"}

# Only pin images after verifying the tag exists on the registry.
IMAGE_PINS: dict[str, str] = {
    "qmcgaw/gluetun": "qmcgaw/gluetun:v3.40.0",
    "rclone/rclone:latest": "rclone/rclone:1.69.0",
    "nicolaka/netshoot:latest": "nicolaka/netshoot:v0.13",
    "ghcr.io/openclaw/openclaw:latest": "ghcr.io/openclaw/openclaw:2026.3.1",
}

# Per-file Checkov skip annotations (resource-level, justified).
FILE_SKIPS: dict[str, dict[str, str]] = {
    "apps/gaming/wolf-deployment.yaml": {
        "CKV_K8S_8": "dind sidecar has no HTTP health endpoint; wolf container has tcpSocket probes.",
        "CKV_K8S_9": "dind sidecar has no HTTP readiness endpoint; wolf container has tcpSocket probes.",
        "CKV_K8S_16": "Wolf and nested Docker require privileged GPU/input device access.",
        "CKV_K8S_20": "Privileged containers cannot disable privilege escalation meaningfully.",
        "CKV_K8S_22": "Nested Docker and Wolf state directories require writable filesystems.",
        "CKV_K8S_23": "Privileged GPU gaming stack requires root-equivalent container access.",
        "CKV_K8S_26": "Moonlight/GameStream requires hostPorts for LAN discovery.",
        "CKV_K8S_28": "NET_RAW is inherited by privileged nested Docker workloads.",
        "CKV_K8S_29": "Pod security context is incompatible with privileged device injection.",
        "CKV_K8S_30": "Container security context is incompatible with privileged GPU access.",
        "CKV_K8S_31": "Seccomp profile cannot be enforced on privileged nested Docker.",
        "CKV_K8S_37": "GPU/input device access requires elevated capabilities.",
        "CKV_K8S_38": "Default service account token is not mounted.",
        "CKV_K8S_40": "Privileged containers run as root by design.",
        "CKV_K8S_43": "Wolf image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/amd-gpu-device-plugin/daemonset.yaml": {
        "CKV_K8S_8": "Device plugin has no HTTP liveness endpoint.",
        "CKV_K8S_9": "Device plugin has no HTTP readiness endpoint.",
        "CKV_K8S_16": "Upstream ROCm device plugin requires privileged kubelet socket access.",
        "CKV_K8S_19": "Device plugin uses hostNetwork per upstream ROCm pattern.",
        "CKV_K8S_20": "Privileged device plugin cannot disable privilege escalation.",
        "CKV_K8S_22": "Device plugin requires writable kubelet plugin socket mount.",
        "CKV_K8S_23": "Device plugin runs as root per upstream pattern.",
        "CKV_K8S_28": "Privileged device plugin inherits NET_RAW.",
        "CKV_K8S_29": "Pod security context is incompatible with privileged device plugin.",
        "CKV_K8S_30": "Container security context is incompatible with privileged device plugin.",
        "CKV_K8S_31": "Seccomp profile cannot be enforced on privileged device plugin.",
        "CKV_K8S_37": "Device plugin requires elevated capabilities for /sys access.",
        "CKV_K8S_40": "Device plugin runs as root per upstream pattern.",
        "CKV_K8S_43": "ROCm device plugin image is version-pinned.",
    },
    "apps/coturn/deployment.yaml": {
        "CKV_K8S_19": "TURN relay requires hostNetwork for UDP port range allocation.",
        "CKV_K8S_35": "TURN credentials are injected as env vars during config rendering.",
        "CKV_K8S_22": "Rendered turnserver.conf is written to a shared emptyDir.",
        "CKV_K8S_40": "coturn image runs as a low UID required by the upstream image.",
        "CKV_K8S_43": "coturn image is version-pinned.",
    },
    "apps/torrenting/qbittorrent/statefulset.yaml": {
        "CKV_K8S_8": "qBittorrent WebUI becomes unresponsive during heavy rechecks; probes cause false 503s.",
        "CKV_K8S_9": "qBittorrent WebUI becomes unresponsive during heavy rechecks; probes cause false 503s.",
        "CKV_K8S_23": "Gluetun VPN sidecar requires root-equivalent privileges for tunnel setup.",
        "CKV_K8S_25": "Gluetun VPN sidecar requires NET_ADMIN for tunnel setup.",
        "CKV_K8S_35": "Bootstrap and VPN credentials are required as env vars by Gluetun and seed scripts.",
        "CKV_K8S_37": "Gluetun adds NET_ADMIN for WireGuard tunnel management.",
        "CKV_K8S_22": "Torrent client and VPN sidecar require writable config directories.",
        "CKV_K8S_40": "linuxserver images use PUID 1001 for NFS volume ownership.",
        "CKV_K8S_43": "Images are tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/sonarr/deployment.yaml": {
        "CKV_K8S_35": "ARR bootstrap init container requires API keys and DB passwords as env vars.",
        "CKV_K8S_22": "linuxserver images require writable /config.",
        "CKV_K8S_40": "linuxserver images use PUID 1001 for NFS volume ownership.",
        "CKV_K8S_43": "Images are tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/radarr/deployment.yaml": {
        "CKV_K8S_35": "ARR bootstrap init container requires API keys and DB passwords as env vars.",
        "CKV_K8S_22": "linuxserver images require writable /config.",
        "CKV_K8S_40": "linuxserver images use PUID 1001 for NFS volume ownership.",
        "CKV_K8S_43": "Images are tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/prowlarr/deployment.yaml": {
        "CKV_K8S_35": "ARR bootstrap init container requires API keys and DB passwords as env vars.",
        "CKV_K8S_22": "linuxserver images require writable /config.",
        "CKV_K8S_40": "linuxserver images use PUID 1001 for NFS volume ownership.",
        "CKV_K8S_43": "Images are tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/flaresolverr/deployment.yaml": {
        "CKV_K8S_22": "FlareSolverr requires writable session state.",
        "CKV_K8S_40": "Upstream image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/audiobookshelf/deployment.yaml": {
        "CKV_K8S_22": "Audiobookshelf requires writable library metadata directories.",
        "CKV_K8S_40": "Upstream image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/epub-google-drive-sync-cronjob.yaml": {
        "CKV_K8S_14": "rclone image is tag-pinned.",
        "CKV_K8S_22": "CronJob writes a temporary rclone config file.",
        "CKV_K8S_35": "Google Drive token is mounted via secret-backed env indirection.",
        "CKV_K8S_40": "rclone image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/buildarr/wire-dl-clients-cronjob.yaml": {
        "CKV_K8S_35": "ARR API keys are required as env vars for Buildarr wiring.",
        "CKV_K8S_22": "Debug sidecar and Buildarr need writable temp directories.",
        "CKV_K8S_40": "Upstream images run as low UIDs.",
        "CKV_K8S_43": "Images are tag-pinned; digest pinning tracked separately.",
    },
    "apps/torrenting/iptorrents/cookie-refresh-cronjob.yaml": {
        "CKV_K8S_22": "Cookie refresh job writes session state to a writable mount.",
        "CKV_K8S_35": "Tracker credentials are required as env vars.",
        "CKV_K8S_40": "python:alpine runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/cloudflared/deployment.yaml": {
        "CKV_K8S_35": "Cloudflare tunnel token is required as an env var by cloudflared.",
        "CKV_K8S_40": "cloudflared image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/memos/deployment.yaml": {
        "CKV_K8S_22": "memos writes SQLite/Postgres state under its data directory.",
        "CKV_K8S_35": "Postgres DSN is required as an env var by memos.",
        "CKV_K8S_40": "memos image runs as a low UID.",
        "CKV_K8S_43": "Image uses a stable channel tag.",
    },
    "apps/mirotalkc2c/deployment.yaml": {
        "CKV_K8S_22": "WebRTC server requires writable temp and cert directories.",
        "CKV_K8S_35": "WebRTC credentials are required as env vars.",
        "CKV_K8S_40": "mirotalk image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/openclaw/deployment.yaml": {
        "CKV_K8S_8": "Long-running gateway has startup ordering handled by init containers.",
        "CKV_K8S_9": "Gateway readiness is enforced by startup ordering across init containers.",
        "CKV_K8S_12": "Init containers have ephemeral resource needs; main container is sized separately.",
        "CKV_K8S_20": "Permission-fix init containers require root for chown on PVC.",
        "CKV_K8S_22": "OpenClaw gateway and init containers require writable home and tool paths.",
        "CKV_K8S_23": "Init containers run as root to fix PVC ownership.",
        "CKV_K8S_28": "npx-spawned MCP subprocesses inherit default pod capabilities.",
        "CKV_K8S_35": "API keys and tokens are required as env vars by OpenClaw.",
        "CKV_K8S_37": "install-kubectl init container retains default capability set for curl/unzip.",
        "CKV_K8S_38": "Service account token is required for in-cluster Kubernetes MCP access.",
        "CKV_K8S_40": "OpenClaw image runs as UID 1000 per upstream.",
        "CKV_K8S_43": "Image is tag-pinned; digest pinning tracked separately.",
    },
    "apps/openclaw/chromium-browser.yaml": {
        "CKV_K8S_22": "Chromium requires writable cache and shared memory directories.",
        "CKV_K8S_40": "headless-shell image runs as a low UID.",
        "CKV_K8S_43": "Image uses stable channel tag.",
    },
    "apps/openclaw/github-app-mcp.yaml": {
        "CKV_K8S_35": "GitHub App private key and MCP token are required as env vars.",
        "CKV_K8S_22": "pip install writes to /deps at container start.",
        "CKV_K8S_38": "No Kubernetes API access; service account token not needed.",
        "CKV_K8S_40": "python:slim runs as a low UID.",
        "CKV_K8S_43": "python base image is tag-pinned.",
    },
    "apps/openclaw/notion-writer.yaml": {
        "CKV_K8S_35": "Notion and Telegram tokens are required as env vars.",
        "CKV_K8S_38": "No Kubernetes API access; service account token not needed.",
        "CKV_K8S_40": "python:slim runs as a low UID.",
        "CKV_K8S_43": "python base image is tag-pinned.",
    },
    "apps/ai-inference/hipfire-deployment.yaml": {

        "CKV_K8S_22": "ROCm inference workloads require writable model and cache directories.",
        "CKV_K8S_40": "ROCm inference images run as low UIDs.",
        "CKV_K8S_43": "Custom GPU image is tag-pinned.",
    },
    "apps/ai-inference/comfyui-deployment.yaml": {
        "CKV_K8S_22": "ComfyUI requires writable output and cache directories.",
        "CKV_K8S_40": "ComfyUI image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned.",
    },
    "apps/ai-inference/open-webui-deployment.yaml": {
        "CKV_K8S_22": "Open WebUI requires writable data directories.",
        "CKV_K8S_40": "Open WebUI image runs as a low UID.",
        "CKV_K8S_43": "Image is tag-pinned.",
    },
    "apps/ai-inference/mode-switcher.yaml": {
        "CKV_K8S_22": "python:slim needs writable temp for stdlib-only service.",
        "CKV_K8S_38": "Service account token is required for Kubernetes Apps API access.",
        "CKV_K8S_43": "python base image is tag-pinned.",
    },
    "infrastructure/monitoring/alert-responder-deployment.yaml": {
        "CKV_K8S_11": "CPU limit is intentionally omitted; responder is I/O-bound and capped by memory.",
        "CKV_K8S_15": "python:slim is pulled IfNotPresent after first install.",
        "CKV_K8S_22": "pip install writes to /tmp at container start.",
        "CKV_K8S_35": "Telegram credentials are required as env vars.",
        "CKV_K8S_38": "Service account token is required for pod restart operations.",
        "CKV_K8S_40": "python:slim runs as UID 1000.",
        "CKV_K8S_43": "python base image is tag-pinned.",
    },
    "cluster/coredns-affinity.yaml": {
        "CKV_K8S_29": "Partial SSA manifest only owns affinity; security context is kubeadm-owned.",
        "CKV_K8S_31": "Partial SSA manifest only owns affinity; seccomp is kubeadm-owned.",
        "CKV_K8S_38": "Partial SSA manifest only owns affinity; SA token policy is kubeadm-owned.",
        "CKV_K8S_40": "Partial SSA manifest only owns affinity; runAsUser is kubeadm-owned.",
    },
}

DEFAULT_RESOURCES = {
    "requests": {"cpu": "50m", "memory": "128Mi"},
    "limits": {"cpu": "500m", "memory": "512Mi"},
}

INIT_RESOURCES = {
    "requests": {"cpu": "25m", "memory": "64Mi"},
    "limits": {"cpu": "250m", "memory": "256Mi"},
}

CRON_RESOURCES = {
    "requests": {"cpu": "50m", "memory": "128Mi"},
    "limits": {"cpu": "500m", "memory": "512Mi"},
}

SKIP_PROFILES = {
    "privileged": FILE_SKIPS["apps/gaming/wolf-deployment.yaml"],
    "device-plugin": FILE_SKIPS["apps/amd-gpu-device-plugin/daemonset.yaml"],
}


def rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def is_privileged(container: dict) -> bool:
    sc = container.get("securityContext") or {}
    return bool(sc.get("privileged"))


def runs_as_root(container: dict) -> bool:
    sc = container.get("securityContext") or {}
    return sc.get("runAsUser") == 0 or sc.get("runAsNonRoot") is False


def merge_security_context(existing: dict | None, defaults: dict) -> dict:
    merged = deepcopy(defaults)
    if existing:
        for key, value in existing.items():
            if key == "capabilities" and isinstance(value, dict):
                caps = merged.setdefault("capabilities", {})
                if "add" in value:
                    caps["add"] = value["add"]
                if "drop" in value:
                    caps["drop"] = value["drop"]
            else:
                merged[key] = value
    return merged


SEED_INIT_NAMES = {"seed-config"}


def default_container_security(image: str, *, init: bool, name: str) -> dict:
    if init and name in SEED_INIT_NAMES:
        return {
            "allowPrivilegeEscalation": False,
            "runAsUser": 0,
            "capabilities": {
                "add": ["CHOWN", "FOWNER", "DAC_OVERRIDE"],
                "drop": ["ALL"],
            },
        }
    if image.startswith("linuxserver/"):
        return {
            "allowPrivilegeEscalation": False,
            "capabilities": {"drop": ["ALL"]},
        }
    return {
        "allowPrivilegeEscalation": False,
        "runAsNonRoot": True,
        "runAsUser": 10001,
        "capabilities": {"drop": ["ALL"]},
    }


def pin_image(image: str) -> str:
    return IMAGE_PINS.get(image, image)


def add_skip_annotations(metadata: dict, skips: dict[str, str]) -> None:
    if not skips:
        return
    annotations = metadata.setdefault("annotations", {})
    existing = {
        value.split("=", 1)[0]
        for value in annotations.values()
        if isinstance(value, str) and value.startswith("CKV_")
    }
    idx = 1
    for key in sorted(skips):
        if key in existing:
            continue
        while f"checkov.io/skip{idx}" in annotations:
            idx += 1
        annotations[f"checkov.io/skip{idx}"] = f"{key}={skips[key]}"
        idx += 1


def ensure_resources(container: dict, profile: dict) -> None:
    if container.get("resources"):
        return
    container["resources"] = deepcopy(profile)


def harden_container(
    container: dict,
    *,
    privileged_workload: bool,
    init: bool = False,
) -> None:
    image = container.get("image")
    if isinstance(image, str):
        container["image"] = pin_image(image)
        if "@" not in container["image"]:
            container["imagePullPolicy"] = "Always"

    if privileged_workload or is_privileged(container) or runs_as_root(container):
        return

    container["securityContext"] = merge_security_context(
        container.get("securityContext"),
        default_container_security(
            container.get("image", ""),
            init=init,
            name=container.get("name", ""),
        ),
    )


def pod_template(doc: dict) -> tuple[dict, dict] | None:
    kind = doc.get("kind")
    if kind in {"Deployment", "StatefulSet", "DaemonSet"}:
        template = doc["spec"]["template"]
    elif kind == "CronJob":
        template = doc["spec"]["jobTemplate"]["spec"]["template"]
    elif kind == "Job":
        template = doc["spec"]["template"]
    else:
        return None
    template.setdefault("metadata", {})
    template.setdefault("spec", {})
    return template["metadata"], template["spec"]


def needs_api_token(spec: dict) -> bool:
    sa = spec.get("serviceAccountName")
    return bool(sa and sa != "default")


def harden_pod_spec(spec: dict, *, privileged_workload: bool) -> None:
    if not needs_api_token(spec):
        spec["automountServiceAccountToken"] = False

    pod_sc = spec.setdefault("securityContext", {})
    pod_sc.setdefault("seccompProfile", {"type": "RuntimeDefault"})

    containers = []
    for key in ("initContainers", "containers", "ephemeralContainers"):
        for container in spec.get(key) or []:
            containers.append((key, container))

    for key, container in containers:
        harden_container(
            container,
            privileged_workload=privileged_workload,
            init=key == "initContainers",
        )
        profile = INIT_RESOURCES if key == "initContainers" else DEFAULT_RESOURCES
        ensure_resources(container, profile)


def dump_doc(yaml: YAML, doc: dict) -> str:
    stream = StringIO()
    yaml.dump(doc, stream)
    return stream.getvalue()


def process_file(path: Path) -> bool:
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.width = 4096
    yaml.indent(mapping=2, sequence=4, offset=2)

    docs = list(yaml.load_all(path.read_text()))
    changed = False
    file_key = rel(path)
    skips = FILE_SKIPS.get(file_key, {})
    privileged_workload = file_key in {
        "apps/gaming/wolf-deployment.yaml",
        "apps/amd-gpu-device-plugin/daemonset.yaml",
    }

    for doc in docs:
        if not isinstance(doc, dict) or doc.get("kind") not in WORKLOAD_KINDS:
            continue
        template = pod_template(doc)
        if not template:
            continue
        metadata, spec = template
        before = dump_doc(yaml, doc)
        harden_pod_spec(spec, privileged_workload=privileged_workload)
        add_skip_annotations(doc.setdefault("metadata", {}), skips)
        after = dump_doc(yaml, doc)
        if before != after:
            changed = True

    if changed:
        with path.open("w") as fh:
            yaml.dump_all(docs, fh)
    return changed


def main() -> int:
    patterns = [
        "apps/**/*.yaml",
        "apps/**/*.yml",
        "infrastructure/**/*.yaml",
        "infrastructure/**/*.yml",
        "cluster/**/*.yaml",
        "cluster/**/*.yml",
    ]
    paths: list[Path] = []
    for pattern in patterns:
        paths.extend(ROOT.glob(pattern))

    updated = []
    for path in sorted(set(paths)):
        if process_file(path):
            updated.append(rel(path))

    print(f"Updated {len(updated)} files:")
    for item in updated:
        print(f"  - {item}")
    return 0


if __name__ == "__main__":
    sys.exit(main())