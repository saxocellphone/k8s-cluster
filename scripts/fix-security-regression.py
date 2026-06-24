#!/usr/bin/env python3
"""Undo security-hardening changes that break linuxserver and seed init containers."""

from __future__ import annotations

from pathlib import Path

from ruamel.yaml import YAML

ROOT = Path(__file__).resolve().parents[1]

# Fabricated pins that 404 on registries — revert to :latest.
REVERT_IMAGES = {
    "ghcr.io/flaresolverr/flaresolverr:v3.3.25.0": "ghcr.io/flaresolverr/flaresolverr:latest",
    "ghcr.io/advplyr/audiobookshelf:2.25.1": "ghcr.io/advplyr/audiobookshelf:latest",
    "mirotalk/c2c:1.0.16": "mirotalk/c2c:latest",
    "ghcr.io/openclaw/openclaw:2026.2.0": "ghcr.io/openclaw/openclaw:latest",
    "ghcr.io/saxocellphone/hipfire-gfx1151:2026.02.0": "ghcr.io/saxocellphone/hipfire-gfx1151:latest",
    "linuxserver/sonarr:4.0.16": "linuxserver/sonarr:latest",
    "linuxserver/radarr:5.22.4": "linuxserver/radarr:latest",
    "linuxserver/prowlarr:1.32.2": "linuxserver/prowlarr:latest",
    "linuxserver/qbittorrent:5.0.4": "linuxserver/qbittorrent:latest",
    "cloudflare/cloudflared:2025.2.0": "cloudflare/cloudflared:latest",
}

SEED_INIT_NAMES = {"seed-config"}

# Images that manage their own UID and need writable home/config paths.
WRITABLE_IMAGES = (
    "linuxserver/",
    "ghcr.io/flaresolverr/flaresolverr",
    "ghcr.io/advplyr/audiobookshelf",
)


def walk_containers(spec: dict):
    for key in ("initContainers", "containers", "ephemeralContainers"):
        for container in spec.get(key) or []:
            yield key, container


def fix_container(name: str, key: str, container: dict) -> bool:
    changed = False
    image = container.get("image", "")
    if image in REVERT_IMAGES:
        container["image"] = REVERT_IMAGES[image]
        changed = True

    sc = container.get("securityContext")
    if not sc:
        return changed

    if key == "initContainers" and container.get("name") in SEED_INIT_NAMES:
        new_sc = {
            "allowPrivilegeEscalation": False,
            "runAsUser": 0,
            "seccompProfile": {"type": "Unconfined"},
            "capabilities": {
                "add": ["CHOWN", "FOWNER", "DAC_OVERRIDE"],
                "drop": ["ALL"],
            },
        }
        if sc != new_sc:
            container["securityContext"] = new_sc
            changed = True
        return changed

    if isinstance(image, str) and image.startswith(WRITABLE_IMAGES):
        new_sc = {
            "allowPrivilegeEscalation": False,
            "capabilities": {"drop": ["ALL"]},
        }
        if sc != new_sc:
            container["securityContext"] = new_sc
            changed = True
    return changed


def fix_file(path: Path) -> bool:
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.width = 4096
    docs = list(yaml.load_all(path.read_text()))
    changed = False
    for doc in docs:
        if not isinstance(doc, dict):
            continue
        spec = None
        if doc.get("kind") in {"Deployment", "StatefulSet", "DaemonSet"}:
            spec = doc["spec"]["template"]["spec"]
        elif doc.get("kind") == "CronJob":
            spec = doc["spec"]["jobTemplate"]["spec"]["template"]["spec"]
        if not spec:
            continue
        for key, container in walk_containers(spec):
            if fix_container(container.get("name", ""), key, container):
                changed = True
    if changed:
        with path.open("w") as fh:
            yaml.dump_all(docs, fh)
    return changed


def main() -> int:
    updated = []
    for path in sorted(ROOT.glob("apps/**/*.yaml")):
        if fix_file(path):
            updated.append(path.relative_to(ROOT))
    print(f"Fixed {len(updated)} files")
    for item in updated:
        print(f"  - {item}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())