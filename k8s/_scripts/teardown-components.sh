#!/bin/bash
set -euo pipefail

scripts_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${scripts_dir}/tkit.sh"

components=("flyway" "postgresql")

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      echo "Usage: $0 [options] [component...]"
      echo "Options:"
      echo "  -h, --help     Show this help message"
      echo "  -p, --postgres Remove only PostgreSQL"
      echo "  -f, --flyway  Remove only migrations"
      exit 0
      ;;
    -p|--postgres)
      components=("postgresql")
      ;;
    -f|--flyway)
      components=("flyway")
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
  shift
done

log info "Removing components: ${components[*]}"

for component in "${components[@]}"; do
    helm delete "$component" --wait -n "${DT_APP_NAMESPACE}" || true
done


log info "All components removed successfully!"
