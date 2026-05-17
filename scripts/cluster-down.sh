#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="gitops-lab"

k3d cluster delete "$CLUSTER_NAME"
echo "Cluster '$CLUSTER_NAME' deleted."
