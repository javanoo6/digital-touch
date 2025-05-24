#!/bin/bash
set -euo pipefail

scripts_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "${scripts_dir}/tkit.sh"

src="${scripts_dir}/../tmpl"
dst="${scripts_dir}/../charts"

if [[ ! -d "${src}" ]]; then
    log warn "Template directory not found: ${src}"
    exit 1
fi

log info "Rendering templates from ${src} to ${dst}"

find "${src}" -type f -name "*.yaml" | while read -r template; do
    rel_path="${template#"${src}"/}"
    target_dir="${dst}/$(dirname "${rel_path}")"
    target_file="${dst}/${rel_path}"

    mkdir -p "${target_dir}"

    log info "Rendering: ${rel_path}"
    envsubst < "${template}" > "${target_file}"
done

log info "✅ All templates rendered successfully!"
