#!/usr/bin/env bash
set -euo pipefail

# --- Путь до вашего отредактированного примера ---
EXAMPLE_FILE="./secrets.env.example"

# --- Параметры для Jenkins ---
JENKINS_NAMESPACE="jenkins"
JENKINS_SECRET_NAME="jenkins-secrets"
JENKINS_DIR="k8s-manifests/jenkins"
DEPLOY_DIR="k8s-manifests"

# --- Параметры для Alertmanager (Monitoring) ---
ALERT_NAMESPACE="monitoring"
ALERT_SECRET_NAME="alertmanager-telegram"
ALERT_DIR="k8s-manifests/monitoring/alertmanager"

# Временная папка для артефактов
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "▶️  Генерируем обычный Secret для Jenkins из $EXAMPLE_FILE"
kubectl create secret generic "$JENKINS_SECRET_NAME" \
  --namespace "$JENKINS_NAMESPACE" \
  --from-env-file="$EXAMPLE_FILE" \
  --dry-run=client -o yaml > "$TMP/jenkins-secret.yaml"

echo "▶️  Запечатываем Secret для Jenkins"
kubeseal --format=yaml < "$TMP/jenkins-secret.yaml" \
  > "$TMP/jenkins-sealedsecret.yaml"

echo "▶️  Копируем SealedSecret в $JENKINS_DIR"
cp "$TMP/jenkins-sealedsecret.yaml" "$JENKINS_DIR/sealedsecret.yaml"

echo "▶️  Генерируем обычный Secret для Alertmanager из $EXAMPLE_FILE"
kubectl create secret generic "$ALERT_SECRET_NAME" \
  --namespace "$ALERT_NAMESPACE" \
  --from-env-file="$EXAMPLE_FILE" \
  --dry-run=client -o yaml > "$TMP/alert-secret.yaml"

echo "▶️  Запечатываем Secret для Alertmanager"
kubeseal --format=yaml < "$TMP/alert-secret.yaml" \
  > "$TMP/alert-sealedsecret.yaml"

echo "▶️  Копируем SealedSecret в $ALERT_DIR"
cp "$TMP/alert-sealedsecret.yaml" "$ALERT_DIR/sealedsecret.yaml"

echo "✅  Все SealedSecrets готовы."

echo "▶️  Применяем Jenkins-манифесты"
kubectl apply -k "$DEPLOY_DIR"

echo "✅  Jenkins развернут"

echo "Очищаем все значения в $EXAMPLE_FILE, чтобы токены/пароли не оставались:"

sed -i 's/=.*/=<your_secret>/' "$EXAMPLE_FILE"

echo "✅  Секреты из $EXAMPLE_FILE обнулены."

