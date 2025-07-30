#!/bin/bash

# Variables for secrets generation
ALERT_NAMESPACE="alertmanager"
GRAFANA_NAMESPACE="grafana"
JENKINS_NAMESPACE="jenkins"
EXAMPLE_FILE="secrets.env.example"
TMP="/tmp/k8s-secrets"
ALERT_DIR="k8s-manifests/monitoring/alertmanager"
GRAFANA_DIR="k8s-manifests/monitoring/grafana"
JENKINS_DIR="k8s-manifests/jenkins"
ALERT_SECRET_NAME="alertmanager-secret"
GRAFANA_SECRET_NAME="grafana-secret"
JENKINS_SECRET_NAME="jenkins-secrets"

# Variables for cluster readiness check
EXPECTED_NODES=5
RETRIES=20
DELAY=15

# Variables for deployment
DEPLOY_DIR="k8s-manifests"
MONITOR_DIR="k8s-manifests/monitoring"
LOGGING_SCRIPT="k8s-manifests/logging/install_elk.sh"

###############################################################################
# 1. Generate SealedSecrets
###############################################################################
generate_secrets() {
  echo "▶️  Generating SealedSecrets..."
  mkdir -p "$TMP"
  
  # Jenkins
  echo "▶️  Jenkins → Secret"
  kubectl create secret generic "$JENKINS_SECRET_NAME" \
    --namespace "$JENKINS_NAMESPACE" \
    --from-env-file="$EXAMPLE_FILE" \
    --dry-run=client -o yaml > "$TMP/jenkins-secret.yaml"
  kubeseal --format=yaml < "$TMP/jenkins-secret.yaml" > "$JENKINS_DIR/sealedsecret.yaml"
  
  # Alertmanager
  echo "▶️  Alertmanager → Secret"
  kubectl create secret generic "$ALERT_SECRET_NAME" \
    --namespace "$ALERT_NAMESPACE" \
    --from-env-file="$EXAMPLE_FILE" \
    --dry-run=client -o yaml > "$TMP/alert-secret.yaml"
  kubeseal --format=yaml < "$TMP/alert-secret.yaml" > "$ALERT_DIR/sealedsecret.yaml"
  
  # Grafana
  echo "▶️  Grafana → Secret"
  kubectl create secret generic "$GRAFANA_SECRET_NAME" \
    --namespace "$GRAFANA_NAMESPACE" \
    --from-env-file="$EXAMPLE_FILE" \
    --dry-run=client -o yaml > "$TMP/grafana-secret.yaml"
  kubeseal --format=yaml < "$TMP/grafana-secret.yaml" > "$GRAFANA_DIR/sealedsecret.yaml"
  
  echo "✅  All SealedSecrets generated"
  echo "▶️  Resetting values in $EXAMPLE_FILE"
  sed -i 's/=.*/=<your_secret>/' "$EXAMPLE_FILE"
  echo "✅  $EXAMPLE_FILE cleaned."
}


###############################################################################
# 2. Check cluster readiness
###############################################################################
wait_for_cluster_ready() {
  echo "🔍 Waiting for all $EXPECTED_NODES nodes to reach Ready state..."
  
  for ((i=1; i<=RETRIES; i++)); do
    total_nodes=$(kubectl get nodes --no-headers | wc -l)
    ready_nodes=$(kubectl get nodes --no-headers | grep -c ' Ready ' || true)

    if [[ $total_nodes -eq $EXPECTED_NODES && $ready_nodes -eq $EXPECTED_NODES ]]; then
      echo "✅  All $ready_nodes/$EXPECTED_NODES nodes are Ready."
      return 0
    fi

    echo "⏳  Ready $ready_nodes/$EXPECTED_NODES nodes (attempt $i/$RETRIES). Waiting ${DELAY}s..."
    sleep "$DELAY"
  done

  echo "❌  Not all nodes became Ready within the time limit."
  exit 1
}

###############################################################################
# 3. Deployment process
###############################################################################
deploy_jenkins() {
  echo "▶️  Deploying Jenkins..."
  kubectl apply -k "$DEPLOY_DIR"
  echo "✅  Jenkins deployed"
}

deploy_monitoring() {
  echo "▶️  Deploying Monitoring..."
  kubectl apply -k "$MONITOR_DIR"
  echo "✅  Monitoring deployed"
}

deploy_logging() {
  echo "▶️  Starting ELK deployment in background..."
  chmod +x "$LOGGING_SCRIPT"
  nohup "$LOGGING_SCRIPT" >/dev/null 2>&1 &
  echo "✅  ELK deployment started in background"
}

###############################################################################
# Main execution
###############################################################################

# 1. Generate secrets (Jenkins first)
generate_secrets

# 2. Check cluster status
wait_for_cluster_ready

# 3. Deploy components in sequence
deploy_jenkins
deploy_monitoring
deploy_logging

echo "🚀  All components deployment initiated. Command line is available."
