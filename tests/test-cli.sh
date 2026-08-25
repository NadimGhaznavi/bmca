#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$ROOT"/scripts/*.sh; do
    output=$("$script" --help 2>&1) || { printf '%s --help failed.\n' "$script" >&2; exit 1; }
    [[ $output == *Usage:* ]] || { printf '%s --help has no usage text.\n' "$script" >&2; exit 1; }
done

initialize_help=$("$ROOT/scripts/initialize-bmca.sh" --help)
[[ $initialize_help == *'initialize-bmca.sh --env dev|prod'* ]] || {
    printf 'initialize-bmca.sh --help does not describe the supported command.\n' >&2
    exit 1
}

for environment in '' qa development production; do
    if BMCA_SETTINGS="$ROOT/conf/settings.cfg" bash -c '
        source "$1/scripts/lib/common.sh"
        load_settings
        select_environment "$2"
    ' _ "$ROOT" "$environment" >/dev/null 2>&1; then
        printf 'Invalid environment was accepted: %s\n' "$environment" >&2; exit 1
    fi
done

printf 'CLI contract checks passed.\n'
