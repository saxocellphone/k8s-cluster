#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
KUBECONFIG_FILE="${REPO_DIR}/kubeconfig"

echo "=== Argo CD Bootstrap ==="
echo ""

# Add Argo CD Helm repo
echo "Adding Argo CD Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo CD
echo "Installing Argo CD..."
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --kubeconfig="$KUBECONFIG_FILE" \
  -f "${REPO_DIR}/infrastructure/argocd/values.yaml" \
  --wait

# Create SOPS age secret for decryption
echo "Creating SOPS age key secret..."
if [ -f "${REPO_DIR}/key.txt" ]; then
  kubectl --kubeconfig="$KUBECONFIG_FILE" -n argocd create secret generic sops-age \
    --from-file=key.txt="${REPO_DIR}/key.txt" \
    --dry-run=client -o yaml | kubectl --kubeconfig="$KUBECONFIG_FILE" apply -f -
else
  echo "WARNING: key.txt not found at ${REPO_DIR}/key.txt"
  echo "You'll need to create the sops-age secret manually."
fi

# Wait for Argo CD to be ready
echo "Waiting for Argo CD server to be ready..."
kubectl --kubeconfig="$KUBECONFIG_FILE" -n argocd wait --for=condition=available \
  deployment/argocd-server --timeout=120s

# Apply the root app-of-apps
echo "Applying app-of-apps..."
kubectl --kubeconfig="$KUBECONFIG_FILE" apply -f "${REPO_DIR}/argocd/app-of-apps.yaml"

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Argo CD UI: http://argocd.k8s.home"
echo ""
echo "Get admin password:"
echo "  kubectl --kubeconfig=$KUBECONFIG_FILE -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
