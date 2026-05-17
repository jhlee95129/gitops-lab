#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="gitops-lab"

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "Cluster '$CLUSTER_NAME' already exists."
  exit 0
fi

k3d cluster create "$CLUSTER_NAME" \
  --port "8888:80@loadbalancer" \
  --agents 1

echo "Cluster '$CLUSTER_NAME' created."
echo "Run: kubectl get nodes"
