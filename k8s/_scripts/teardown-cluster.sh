#!/bin/bash
set -e

source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"/tkit.sh

COMPONENTS_TO_DELETE=()
[ $# -eq 0 ] && COMPONENTS_TO_DELETE+=("cluster")

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -h, --help         Show this help"
      echo "  -a, --all          Delete everything"
      echo "  -c, --cluster      Delete the cluster"
      echo "  -r, --registry     Delete the registry container"
      echo "  -n, --network      Delete the network(s)"
      echo "  -e, --etc-hosts    Remove /etc/hosts entry"
      echo "  -d, --data         Delete the data directory"
      exit 0
      ;;
    -a|--all)
      COMPONENTS_TO_DELETE=("cluster" "registry" "network" "hosts" "data")
      break
      ;;
    -c|--cluster)   COMPONENTS_TO_DELETE+=("cluster") ;;
    -r|--registry)  COMPONENTS_TO_DELETE+=("registry") ;;
    -n|--network)   COMPONENTS_TO_DELETE+=("network") ;;
    -e|--etc-hosts) COMPONENTS_TO_DELETE+=("hosts") ;;
    -d|--data)      COMPONENTS_TO_DELETE+=("data") ;;
    *)
      log warn "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

log info "Starting cleanup of selected components: ${COMPONENTS_TO_DELETE[*]} 🧹"

if [[ " ${COMPONENTS_TO_DELETE[*]} " =~ " cluster " ]]; then
  if kind get clusters 2>/dev/null | grep -q "^${DT_CLUSTER_NAME}$"; then
    log info "Deleting Kind cluster: ${DT_CLUSTER_NAME} 🗑️"
    kind delete cluster --name "${DT_CLUSTER_NAME}"
    log info "Cluster deleted ✅"
  else
    log info "Cluster ${DT_CLUSTER_NAME} not found ⏭️"
  fi
fi

if [[ " ${COMPONENTS_TO_DELETE[*]} " =~ " registry " ]]; then
  if docker ps -a --format '{{.Names}}' | grep -q "^${DT_REGISTRY_NAME}$"; then
    log info "Removing registry container: ${DT_REGISTRY_NAME} 🗑️"
    docker stop "${DT_REGISTRY_NAME}" 2>/dev/null || true
    docker rm "${DT_REGISTRY_NAME}" 2>/dev/null || true
    log info "Registry removed ✅"
  else
    log info "Registry ${DT_REGISTRY_NAME} not found ⏭️"
  fi
fi

if [[ " ${COMPONENTS_TO_DELETE[*]} " =~ " network " ]]; then
  if docker ps -a --format '{{.Names}}' | grep -q "^${DT_REGISTRY_NAME}$" && \
     docker network ls --format '{{.Name}}' | grep -q "^kind$"; then
    if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${DT_REGISTRY_NAME}" 2>/dev/null)" != 'null' ]; then
      log info "Disconnecting registry from kind network 🔌"
      docker network disconnect -f kind "${DT_REGISTRY_NAME}" 2>/dev/null || log warn "Failed to disconnect registry ⚠️"
    fi
  fi

  if [ -n "${DT_NETWORK_NAME}" ] && docker network ls --format '{{.Name}}' | grep -q "^${DT_NETWORK_NAME}$"; then
    log info "Removing network: ${DT_NETWORK_NAME} 🗑️"
    docker network rm "${DT_NETWORK_NAME}" 2>/dev/null || log warn "Failed to remove network ⚠️"
  fi

  if [[ " ${COMPONENTS_TO_DELETE[*]} " =~ " cluster " ]] && docker network ls --format '{{.Name}}' | grep -q "^kind$"; then
    if [ -z "$(docker network inspect kind -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")" ]; then
      log info "Removing kind network 🗑️"
      docker network rm kind 2>/dev/null || log warn "Failed to remove kind network ⚠️"
    else
      log info "Kind network still has connected containers, skipping ⏭️"
    fi
  fi
fi

if [[ " ${COMPONENTS_TO_DELETE[*]} " =~ " hosts " ]]; then
  if grep -q "${DT_REGISTRY_NAME}" /etc/hosts; then
    log info "Removing ${DT_REGISTRY_NAME} from /etc/hosts 🔑"
    TEMP_FILE=$(mktemp)
    grep -v "${DT_REGISTRY_NAME}" /etc/hosts > "$TEMP_FILE"
    if sudo cp "$TEMP_FILE" /etc/hosts; then
      log info "Hosts entry removed ✅"
    else
      log warn "Failed to update /etc/hosts ⚠️"
    fi
    rm "$TEMP_FILE"
  else
    log info "${DT_REGISTRY_NAME} not found in /etc/hosts ⏭️"
  fi
fi

if [[ " ${COMPONENTS_TO_DELETE[*]} " =~ " data " ]]; then
  if [ -d "${KIND_DATA_DIR}" ]; then
    log info "Removing data directory: ${KIND_DATA_DIR} 🗑️"
    if rm -rf "${KIND_DATA_DIR}"; then
      log info "Data directory removed ✅"
    else
      log warn "Failed to remove data directory ⚠️"
    fi
  else
    log info "Data directory not found ⏭️"
  fi
fi

log info "Cleanup complete! 🎉"