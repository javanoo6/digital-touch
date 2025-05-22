#!/bin/bash
set -euo pipefail

scripts_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${scripts_dir}/tkit.sh"

components=()
deploy_all=true

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      cat << EOF
Usage: $0 [options] [component...]
Options:
  -h, --help     Show this help message
  -p, --postgres Deploy only PostgreSQL
  -f, --flyway  Deploy only database migrations

If no components are specified, all components will be deployed.
Available components: postgresql flyway
EOF
      exit 0
      ;;
    -p|--postgres) components+=("postgresql"); deploy_all=false ;;
    -f|--flyway)  components+=("flyway"); deploy_all=false ;;
    -*)
      log error "Unknown option: $arg"
      echo "Use --help for usage information"
      exit 1
      ;;
    *) components+=("$arg"); deploy_all=false ;;
  esac
done

[[ "$deploy_all" == "true" ]] && components=("postgresql" "flyway")

"${scripts_dir}/render-envs.sh"


charts_dir="${scripts_dir}/../charts"
for component in "${components[@]}"; do
    chart_path="${charts_dir}/${component}"
    log info "Deploying '${component}'"
    helm upgrade --install "${component}" "${chart_path}" -n "${DT_APP_NAMESPACE}"
done        