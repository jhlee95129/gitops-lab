#!/usr/bin/env bash
set -euo pipefail

# Argo CD 네임스페이스 생성
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Argo CD 공식 manifest 설치
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s

# 초기 admin 비밀번호 출력
echo ""
echo "Argo CD installed successfully."
echo "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "  https://localhost:8081 (user: admin)"
