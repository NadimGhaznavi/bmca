#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

main() {
    if [[ ${1:-} == -h || ${1:-} == --help ]]; then
        printf 'Usage: %s\n' "$(basename "$0")"; exit 0
    fi
    (($# == 0)) || die "Unknown argument: $1"
    load_settings
    require_root
    confirm "Remove installed bmca files and the systemd unit? CA state will be preserved."
    systemctl disable --now step-ca.service 2>/dev/null || true
    [[ ! -L $BACKUP_LINK ]] || unlink "$BACKUP_LINK"
    [[ ! -f $SYSTEMD_UNIT_FILE ]] || rm -f -- "$SYSTEMD_UNIT_FILE"
    systemctl daemon-reload
    assert_safe_absolute_path "$INSTALL_DIR"
    rm -rf -- "$INSTALL_DIR"
    success "Uninstalled bmca. Preserved $STEP_CA_CONFIG_DIR and $STEP_CA_STATE_DIR."
}

main "$@"
