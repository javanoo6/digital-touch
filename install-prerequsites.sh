#!/bin/bash
set -e

if which docker >/dev/null 2>&1; then
  echo "Docker is already installed."
else
  echo "Installing Docker IO:"
  sudo apt install -y docker.io

  sudo usermod -aG docker "${USER}"
  echo "Docker installed successfully. You need to log out and log in for group changes to take effect."
fi

if which kind >/dev/null 2>&1; then
  echo "kind is already installed."
else
  echo "Installing KIND:"
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
  sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
  rm kind
  echo "kind installed successfully."
fi

if which helm >/dev/null 2>&1; then
  echo "Helm is already installed."
else
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
  sudo apt-get install apt-transport-https --yes
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
  sudo apt-get update
  sudo apt-get install helm
fi

if which mvn >/dev/null 2>&1; then
  echo "Maven is already installed."
else
  echo "Installing Maven..."
  sudo apt install -y maven
  echo "Maven installed successfully."
fi

if dpkg -l | grep -q openjdk-21-jdk; then
  echo "OpenJDK 21 is already installed."
else
  echo "Installing OpenJDK 21..."
  sudo apt install -y openjdk-21-jdk
  echo "OpenJDK 21 installed successfully."
fi

if which mvn >/dev/null 2>&1; then
  echo "Maven is already installed."
else
  echo "Installing Maven..."
  sudo apt install -y maven
  echo "Maven installed successfully."
fi
