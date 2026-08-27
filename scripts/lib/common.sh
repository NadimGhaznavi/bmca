#!/usr/bin/env bash

set -Eeuo pipefail

BMCA_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BMCA_ROOT="$(cd -- "$BMCA_LIB_DIR/../.." && pwd)"
BMCA_SETTINGS="${BMCA_SETTINGS:-$BMCA_ROOT/conf/settings.cfg}"

die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }
info() { printf '[INFO] %s\n' "$*"; }
success() { printf '[SUCCESS] %s\n' "$*"; }
require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this command as root."; }
require_command() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
require_file() { [[ -f "$1" ]] || die "Required file not found: $1"; }

load_settings() {
    require_file "$BMCA_SETTINGS"
    # The selected settings file is repository-controlled and must contain assignments only.
    # shellcheck source=/dev/null
    source "$BMCA_SETTINGS"
}

select_environment() {
    case "${1:-}" in
        dev)
            BMCA_ENV=dev; CA_HOST=$DEV_CA_HOST; CA_NAME=$DEV_CA_NAME
            CA_ADDRESS=$DEV_CA_ADDRESS; BACKUP_TARGET_DIR=$DEV_BACKUP_TARGET_DIR ;;
        prod)
            BMCA_ENV=prod; CA_HOST=$PROD_CA_HOST; CA_NAME=$PROD_CA_NAME
            CA_ADDRESS=$PROD_CA_ADDRESS; BACKUP_TARGET_DIR=$PROD_BACKUP_TARGET_DIR ;;
        *) die "Environment must be 'dev' or 'prod'." ;;
    esac
    export BMCA_ENV CA_HOST CA_NAME CA_ADDRESS BACKUP_TARGET_DIR
}

confirm() {
    local prompt=$1 reply
    [[ -t 0 ]] || die "Confirmation requires an interactive terminal."
    read -r -p "$prompt [y/N] " reply
    [[ $reply == y || $reply == Y ]] || die "Cancelled."
}

assert_host_matches_environment() {
    local short_host
    short_host=$(hostname -s)
    [[ $short_host == "$CA_HOST" ]] ||
        die "Environment '$BMCA_ENV' belongs on '$CA_HOST', not '$short_host'."
}

assert_safe_absolute_path() {
    [[ $1 == /* && $1 != / && $1 != /opt && $1 != /etc && $1 != /var ]] ||
        die "Refusing unsafe path: $1"
}

check_secret_mode() {
    local mode
    mode=$(stat -c '%a' "$1")
    [[ $mode == 600 ]] || die "Secret file must have mode 0600: $1"
}
