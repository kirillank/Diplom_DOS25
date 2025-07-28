#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# 1. Install Ansible 
###############################################################################
echo "▶️  Installing Ansible…"
export DEBIAN_FRONTEND=noninteractive
sudo apt update -y
sudo apt install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
echo "✅  Ansible installed."

###############################################################################
# 2. Run the Ansible-playbook
###############################################################################
ANSIBLE_PLAYBOOK_PATH="Ansible/playbook.yml"
echo "▶️  Running playbook: $ANSIBLE_PLAYBOOK_PATH"
ansible-playbook "$ANSIBLE_PLAYBOOK_PATH"
echo "✅  Playbook finished."

###############################################################################
# 3. Generate and seal Secrets (Jenkins / Alertmanager / Grafana)
###############################################################################
EXAMPLE_FILE="./secrets.env.example"

# Jenkins
JENKINS_NAMESPACE="jenkins"
JENKINS_SECRET_NAME="jenkins-secrets"
JENKINS_DIR="k8s-manifests/jenkins"
DEPLOY_DIR="k8s-manifests"

# Alertmanager
ALERT_NAMESPACE="monitoring"
ALERT_SECRET_NAME="alertmanager-telegram"
ALERT_DIR="k8s-manifests/monitoring/alertmanager"

# Grafana
GRAFANA_NAMESPACE="monitoring"
GRAFANA_SECRET_NAME="grafana-secret"
GRAFANA_DIR="k8s-manifests/monitoring/grafana"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "▶️  Jenkins → Secret"
kubectl create secret generic "$JENKINS_SECRET_NAME" \
  --namespace "$JENKINS_NAMESPACE" \
  --from-env-file="$EXAMPLE_FILE" \
  --dry-run=client -o yaml > "$TMP/jenkins-secret.yaml"
kubeseal --format=yaml < "$TMP/jenkins-secret.yaml" > "$JENKINS_DIR/sealedsecret.yaml"

echo "▶️  Alertmanager → Secret"
kubectl create secret generic "$ALERT_SECRET_NAME" \
  --namespace "$ALERT_NAMESPACE" \
  --from-env-file="$EXAMPLE_FILE" \
  --dry-run=client -o yaml > "$TMP/alert-secret.yaml"
kubeseal --format=yaml < "$TMP/alert-secret.yaml" > "$ALERT_DIR/sealedsecret.yaml"

echo "▶️  Grafana → Secret"
kubectl create secret generic "$GRAFANA_SECRET_NAME" \
  --namespace "$GRAFANA_NAMESPACE" \
  --from-env-file="$EXAMPLE_FILE" \
  --dry-run=client -o yaml > "$TMP/grafana-secret.yaml"
kubeseal --format=yaml < "$TMP/grafana-secret.yaml" > "$GRAFANA_DIR/sealedsecret.yaml"

echo "✅  All SealedSecrets are ready."

###############################################################################
# 4. Check that ALL 5 cluster nodes are Ready
###############################################################################
wait_for_cluster_ready() {
  local expected_nodes=5          # how many nodes must be Ready
  local retries=20                # 20 × 15 s = 5 min
  local delay=15

  echo "🔍 Waiting for all $expected_nodes nodes to reach Ready state…"

  for ((i=1; i<=retries; i++)); do
    total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true)

    if [[ $total_nodes -eq $expected_nodes && $ready_nodes -eq $expected_nodes ]]; then
      echo "✅  All $ready_nodes/$expected_nodes nodes are Ready."
      return 0
    fi

    echo "⏳  Ready $ready_nodes/$expected_nodes nodes out of $total_nodes (attempt $i/$retries). Waiting ${delay}s…"
    sleep "$delay"
  done

  echo "❌  Not all nodes became Ready within the time limit."
  exit 1
}

wait_for_cluster_ready

###############################################################################
# 5. Apply Kubernetes manifests
###############################################################################
echo "▶️  Applying manifests: kubectl apply -k $DEPLOY_DIR"
kubectl apply -k "$DEPLOY_DIR"
echo "✅  Manifests applied."

###############################################################################
# 6. Clean up secrets.env.example
###############################################################################
echo "▶️  Resetting values in $EXAMPLE_FILE"
sed -i 's/=.*/=<your_secret>/' "$EXAMPLE_FILE"
echo "✅  $EXAMPLE_FILE cleaned."

