#!/bin/bash
set -e

source "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"/tkit.sh

if kind get clusters 2>/dev/null | grep -q "^${DT_CLUSTER_NAME}$"; then
  log info "Cluster ${DT_CLUSTER_NAME} already exists, skipping creation"
  exit 0
fi

mkdir -p "${KIND_DATA_DIR}"
chmod 750 "${KIND_DATA_DIR}"

log info "Creating a cluster 🚀"

cat <<EOF | kind create cluster --name "${DT_CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${DT_CLUSTER_NAME}
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraMounts:
      - hostPath: ${HOME}/.kind/data/${DT_CLUSTER_NAME}
        containerPath: /data
    extraPortMappings:
      - containerPort: 30002
        hostPort: 30002
        protocol: TCP
      - containerPort: 30003
        hostPort: 30003
        protocol: TCP
      - containerPort: ${DT_POSTGRES_NODE_PORT}
        hostPort: ${DT_POSTGRES_NODE_PORT}
        protocol: TCP
  - role: worker
    extraMounts:
      - hostPath: ${HOME}/.kind/data/${DT_CLUSTER_NAME}
        containerPath: /data
networking:
  apiServerAddress: ${DT_API_SERVER_ADDRESS}
  apiServerPort: ${DT_API_SERVER_PORT}
  podSubnet: ${DT_POD_SUBNET}
  serviceSubnet: ${DT_SERVICE_SUBNET}
EOF

log info "Setting kubectl context to use kind 🔄"

CONTEXT_NAME="kind-${DT_CLUSTER_NAME}"
kubectl config use-context "$CONTEXT_NAME"

log info "Creating namespaces: ${DT_INFRA_NAMESPACE}, ${DT_APP_NAMESPACE}"

cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${DT_INFRA_NAMESPACE}
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${DT_APP_NAMESPACE}
EOF


log info "Step 1: Creating registry container unless it already exists 🐳"

if [ "$(docker inspect -f '{{.State.Running}}' "${DT_REGISTRY_NAME}" 2>/dev/null || true)" != 'true' ]; then
  log info "Starting Docker registry container 📦"
  docker run \
    -d --restart=always -p "127.0.0.1:${DT_REGISTRY_PORT}:${DT_REGISTRY_HOST_PORT}" --name "${DT_REGISTRY_NAME}" "${DT_REGISTRY_IMAGE}"
fi
log info "Registry container is working ✅"

log info "Ensuring necessary registry images"
push_image_to_registry "${default_registry_images[@]}"

log info "Step 2: Connecting the registry to the kind network 🔌"

if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${DT_REGISTRY_NAME}" 2>/dev/null)" = 'null' ]; then
  log info "Connecting registry to kind network 🌐"
  if docker network connect "kind" "${DT_REGISTRY_NAME}"; then
    log info "Successfully connected registry to network ✅"
  else
    log warn "Failed to connect to network, unexpected error ⚠️"
  fi
else
    log info "Registry already connected to network ✅"
fi


log info "Configuring Kind nodes to use insecure registry ⚙️"
for node in $(kind get nodes --name "${DT_CLUSTER_NAME}"); do
  LOCALHOST_REGISTRY_DIR="/etc/containerd/certs.d/localhost:${DT_REGISTRY_PORT}"
  docker exec "${node}" mkdir -p "${LOCALHOST_REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" tee "${LOCALHOST_REGISTRY_DIR}/hosts.toml" >/dev/null
[host."http://${DT_REGISTRY_NAME}:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

  DIRECT_REGISTRY_DIR="/etc/containerd/certs.d/${DT_REGISTRY_NAME}:5000"
  docker exec "${node}" mkdir -p "${DIRECT_REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" tee "${DIRECT_REGISTRY_DIR}/hosts.toml" >/dev/null
[host."http://${DT_REGISTRY_NAME}:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF

  log info "Configured node ${node} to use insecure registry ✅"
done


log info "Step 4: Adding entry to /etc/hosts if it doesn't exist already 📝"

if ! grep -q "${DT_REGISTRY_NAME}" /etc/hosts; then
  log info "Adding entry to /etc/hosts (requires sudo) 🔑"
  if sudo tee -a /etc/hosts > /dev/null <<< "127.0.0.1 ${DT_REGISTRY_NAME}"; then
    log info "Successfully added ${DT_REGISTRY_NAME} to /etc/hosts ✅"
  else
    log warn "Failed to add entry to /etc/hosts. You may need to add it manually ⚠️"
    log warn "127.0.0.1 ${DT_REGISTRY_NAME}"
  fi
else
  log info "${DT_REGISTRY_NAME} already exists in /etc/hosts ✅"
fi

log info "Restarting containerd on Kind nodes..."
for node in $(kind get nodes --name "${DT_CLUSTER_NAME}"); do
  docker exec "${node}" systemctl restart containerd
  log info "Restarted containerd on ${node} ✅"
done

install_ingress_nginx

log info "Following is based on: https://kind.sigs.k8s.io/docs/user/local-registry/ instruction 📝"

log info "Cluster setup completed successfully! 🎉"

log info "In order to push image use:"
log info "-> docker image tag some-image localhost:${DT_REGISTRY_HOST_PORT}/some-image:tag 📤"
log info "-> docker push localhost:${DT_REGISTRY_HOST_PORT}/some-image:tag 📤"
log info "To pull image use: ${DT_REGISTRY_NAME}:${DT_REGISTRY_HOST_PORT}/some-image:tag 📥"
