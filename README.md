# Local Development Setup

## Prerequisites

- **Docker Engine**: 24.0.0 or newer
    - [Docker Installation Guide](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)

- **Kind**: 0.20.0 or newer
    - [Kind Installation Guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

- **kubectl**: 1.27.0 or newer
    - [kubectl Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

- **Helm**: 3.12.0 or newer
    - [Helm Installation Guide](https://helm.sh/docs/intro/install/)

- **Java**: JDK 17 or newer for backend development
    - [OpenJDK Installation](https://openjdk.org/install/)

- **Maven**: JDK 17 or newer for backend development
  - [Maven Installation](https://maven.apache.org/download.cgi)

## System Requirements

- At least 8GB RAM
- 20GB free disk space
- Ubuntu 24.04 or compatible Linux distribution

In order to install prerequisites on ubuntu 24.04 please run
`./k8s/install-prerequsites.sh`