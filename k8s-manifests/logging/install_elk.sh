#!/usr/bin/env bash
set -euo pipefail

# версия Helm-чарта и тег релиза
VER="8.5.1"
NS="elasticsearch"
CHARTS=(elasticsearch logstash filebeat kibana)
# откуда берём исходники чартов
SRC_URL="https://github.com/elastic/helm-charts/archive/refs/tags/v${VER}.tar.gz"

# рабочая папка для распаковки
WORKDIR="$(mktemp -d)"
# корень репозитория (где лежит этот скрипт)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── 0. Namespace ──────────────────────────────────────────────────────────────
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

# ─── 1. Скачиваем и пакуем чарты ───────────────────────────────────────────────
echo "Downloading source charts from ${SRC_URL}"
curl -fsSL "$SRC_URL" | tar -xz -C "$WORKDIR"

SRC_DIR="${WORKDIR}/helm-charts-${VER}"
for CH in "${CHARTS[@]}"; do
  TGZ="${ROOT_DIR}/${CH}-${VER}.tgz"
  if [[ ! -f "$TGZ" ]]; then
    echo "Packaging chart $CH…"
    helm package "${SRC_DIR}/${CH}" \
      --version "$VER" \
      --destination "$ROOT_DIR"
  fi
done

# ─── 2. Устанавливаем / обновляем чарты ────────────────────────────────────────
# флаги ожидания: 
#  --wait          — дождаться Ready всех Deployment/StatefulSet и Services,
#  --wait-for-jobs — дополнительно дождаться успешного завершения всех HelmJobhook’ов
DEPLOY_OPTS="--wait-for-jobs --timeout 10m"
for CH in "${CHARTS[@]}"; do
  echo "Deploying chart $CH (version $VER)…"
  helm upgrade --install "$CH" "${ROOT_DIR}/${CH}-${VER}.tgz" \
    -f "${ROOT_DIR}/${CH}/values.yaml" \
    -n "$NS" $DEPLOY_OPTS
  echo "✅ Chart $CH deployed."
done

# ─── 3. Переключаем ReclaimPolicy на Retain ────────────────────────────────────
kubectl get pv -l app=elasticsearch -o name | \
  xargs -r kubectl patch -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

echo "🎉 All ELK components ($VER) have been installed/updated successfully."

