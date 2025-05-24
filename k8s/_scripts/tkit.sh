#!/bin/bash

# Version information
export APP_VERSION=${APP_VERSION:-"0.0.1"}

# Chart versions
export KIND_CHART_VERSION=${KIND_CHART_VERSION:-"0.0.1"}
export NGINX_CHART_VERSION=${NGINX_CHART_VERSION:-"0.0.1"}
export NS_CHART_VERSION=${NS_CHART_VERSION:-"0.0.1"}
export REGISTRY_CHART_VERSION=${REGISTRY_CHART_VERSION:-"0.0.1"}

# App versions
export KIND_APP_VERSION=${KIND_APP_VERSION:-"0.27.0"}
export NGINX_APP_VERSION=${NGINX_APP_VERSION:-"1.12.2"}
export REGISTRY_APP_VERSION=${REGISTRY_APP_VERSION:-"3.0.0"}

# Cluster configuration
export DT_CLUSTER_NAME=${DT_CLUSTER_NAME:-"digitaltouch"}
export DT_API_SERVER_ADDRESS=${DT_API_SERVER_ADDRESS:-"127.0.0.1"}
export DT_API_SERVER_PORT=${DT_API_SERVER_PORT:-"6443"}
export DT_POD_SUBNET=${DT_POD_SUBNET:-"10.244.0.0/16"}
export DT_SERVICE_SUBNET=${DT_SERVICE_SUBNET:-"10.96.0.0/16"}

# Namespace configuration
export DT_INFRA_NAMESPACE=${DT_INFRA_NAMESPACE:-"digital-touch-infra"}
export DT_APP_NAMESPACE=${DT_APP_NAMESPACE:-"digital-touch-app"}

# Registry configuration
export KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-"kind"}
export DT_NETWORK_NAME=${DT_NETWORK_NAME:-"dt-registry-network"}
export DT_REGISTRY_NAME=${DT_REGISTRY_NAME:-"dt-registry"}
export DT_REGISTRY_PORT=${DT_REGISTRY_PORT:-"5000"}
export DT_REGISTRY_HOST_PORT=${DT_REGISTRY_HOST_PORT:-"5000"}
export DT_REGISTRY_IMAGE=${DT_REGISTRY_IMAGE:-"registry:2.8.0"}

export KIND_DATA_DIR=${KIND_DATA_DIR:-"${HOME}/.kind/data/${DT_CLUSTER_NAME}"}

# Ingress-Nginx
export DT_IN_SERVICE_TYPE=${DT_IN_SERVICE_TYPE:-"NodePort"}
export DT_INGRESS_HTTP_PORT=${DT_INGRESS_HTTP_PORT:-80}
export DT_INGRESS_HTTPS_PORT=${DT_INGRESS_HTTPS_PORT:-433}

# Postgres
export DT_POSTGRES_DB_NAME=${DT_POSTGRES_DB_NAME:-"digital-touch-app"}
export DT_POSTGRES_DB_ADMIN_USERNAME=${DT_POSTGRES_DB_ADMIN_USERNAME:-"dt-super-admin"}
export DT_POSTGRES_DB_ADMIN_PASSWORD=${DT_POSTGRES_DB_ADMIN_PASSWORD:-"dt-super-passwd"}

export DT_POSTGRES_DB_APP_USERNAME=${DT_POSTGRES_DB_APP_USERNAME:-"dt-admin"}
export DT_POSTGRES_DB_APP_PASSWORD=${DT_POSTGRES_DB_APP_PASSWORD:-"dt-passwd"}

export DT_POSTGRES_SERVICE_TYPE=${DT_POSTGRES_SERVICE_TYPE:-"NodePort"}
export DT_POSTGRES_CONTAINER_PORT=${DT_POSTGRES_CONTAINER_PORT:-5432}
export DT_POSTGRES_SERVICE_PORT=${DT_POSTGRES_SERVICE_PORT:-5432}
export DT_POSTGRES_NODE_PORT=${DT_POSTGRES_NODE_PORT:-30432}

log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  case "$level" in
    info)  echo -e "\033[0;32m[$timestamp] [INFO] $message\033[0m" ;;
    warn)  echo -e "\033[0;33m[$timestamp] [WARN] $message\033[0m" ;;
    debug) echo -e "\033[0;36m[$timestamp] [DEBUG] $message\033[0m" ;;
    error) echo -e "\033[0;31m[$timestamp] [ERROR] $message\033[0m" ;;
    *)     echo -e "Usage: log info|warn|debug \"message\"" ;;
  esac
}

# taken from here: https://github.com/kubernetes/ingress-nginx/blob/main/deploy/static/provider/kind/deploy.yaml
install_ingress_nginx() {
  log info "Installing ingress-nginx in ${DT_INFRA_NAMESPACE} namespace 🚀"

  TMP_MANIFEST=$(mktemp)
  log info "Generating ingress-nginx manifest..."

  curl -s https://raw.githubusercontent.com/kubernetes/ingress-nginx/refs/heads/main/deploy/static/provider/kind/deploy.yaml | \
    sed "s|registry.k8s.io/ingress-nginx/controller:v1.12.2|${DT_REGISTRY_NAME}:5000/controller:v1.12.2|g" | \
    sed "s|registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.3|${DT_REGISTRY_NAME}:5000/kube-webhook-certgen:v1.5.3|g" | \
    sed "s|@sha256:[a-f0-9]*||g" | \
    sed "s/namespace: ingress-nginx/namespace: ${DT_INFRA_NAMESPACE}/g" | \
    sed "s/port: 80/port: ${DT_INGRESS_HTTP_PORT}/g" | \
    sed "s/port: 443/port: ${DT_INGRESS_HTTPS_PORT}/g" > "$TMP_MANIFEST"

  kubectl apply -f "$TMP_MANIFEST"

  rm "$TMP_MANIFEST"

  log info "Waiting for ingress-nginx controller to be ready..."
  kubectl wait --namespace "${DT_INFRA_NAMESPACE}" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s

  log info "ingress-nginx installed successfully in ${DT_INFRA_NAMESPACE} namespace ✅"
}

uninstall_ingress_nginx() {
  log info "Uninstalling ingress-nginx from ${DT_INFRA_NAMESPACE} namespace 🗑️"

  TMP_MANIFEST=$(mktemp)

  curl -s https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml | \
    sed "s/namespace: ingress-nginx/namespace: ${DT_INFRA_NAMESPACE}/g" > "$TMP_MANIFEST"

  kubectl delete -f "$TMP_MANIFEST" --ignore-not-found=true

  rm "$TMP_MANIFEST"

  log info "Checking for any leftover ingress-nginx resources..."

  kubectl delete all,ingress,ingressclass,validatingwebhookconfiguration,secret,serviceaccount,configmap,clusterrole,clusterrolebinding,role,rolebinding \
    -l app.kubernetes.io/name=ingress-nginx \
    -n "${DT_INFRA_NAMESPACE}" \
    --ignore-not-found=true

  kubectl delete validatingwebhookconfiguration ingress-nginx-admission --ignore-not-found=true

  log info "Checking if any ingress-nginx pods remain..."
  if kubectl get pods -n "${DT_INFRA_NAMESPACE}" -l app.kubernetes.io/name=ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
    log warn "Some ingress-nginx pods still exist. Forcing deletion..."
    kubectl delete pods -n "${DT_INFRA_NAMESPACE}" -l app.kubernetes.io/name=ingress-nginx --force --grace-period=0
  fi

  log info "ingress-nginx has been uninstalled from ${DT_INFRA_NAMESPACE} namespace ✅"
}

export default_registry_images=(
  "registry.k8s.io/ingress-nginx/controller:v1.12.2"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.5.3"
  "postgres:17.5-alpine3.21"
  "flyway/flyway:11-alpine"
  "kindest/node:v1.32.2"
  "alpine:3.21.3"
  "registry.k8s.io/e2e-test-images/agnhost:2.39"
)

push_image_to_registry() {
  if ! curl -s -S -m 2 "http://localhost:${DT_REGISTRY_PORT}/v2/" > /dev/null; then
    log error "Cannot connect to registry at localhost:${DT_REGISTRY_PORT}"
    log info "Make sure registry is running with: docker run -d --restart=always -p ${DT_REGISTRY_PORT}:5000 --name ${DT_REGISTRY_NAME} ${DT_REGISTRY_IMAGE}"
    return 1
  fi

  log info "Registry connection successful at localhost:${DT_REGISTRY_PORT}"

  for image in "$@"; do
    if [[ "$image" == *":"* ]]; then
      image_name=${image%:*}
      tag=${image#*:}
    else
      image_name=$image
      tag="latest"
    fi

    base_name=$(echo "$image_name" | sed 's|.*/||')

    log info "Processing $image (Name: $image_name, Tag: $tag, Base: $base_name)"

    if ! docker pull "$image"; then
      log error "Failed to pull $image"
      continue
    fi

    local_tag="localhost:${DT_REGISTRY_PORT}/${base_name}:${tag}"
    log info "Tagging as ${local_tag}"
    if ! docker tag "$image" "$local_tag"; then
      log error "Failed to tag $image"
      continue
    fi

    log info "Pushing to registry as ${local_tag}"
    if docker push "$local_tag"; then
      log info "Successfully pushed ${local_tag}"
    else
      log error "Failed to push ${local_tag}"
    fi
  done
}

