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
    confirm "Stop BMCA and remove its installed files, configuration, and local work state?"
    systemctl disable --now step-ca.service 2>/dev/null || true
    [[ ! -L $BACKUP_LINK ]] || unlink "$BACKUP_LINK"
    [[ ! -f $SYSTEMD_UNIT_FILE ]] || rm -f -- "$SYSTEMD_UNIT_FILE"
    systemctl daemon-reload
    assert_safe_absolute_path "$INSTALL_DIR"
    assert_safe_absolute_path "$BMCA_CONFIG_DIR"
    assert_safe_absolute_path "$BMCA_STATE_DIR"
    rm -rf -- "$INSTALL_DIR"
    rm -rf -- "$BMCA_CONFIG_DIR"
    rm -rf -- "$BMCA_STATE_DIR"
    success "Uninstalled bmca. Preserved Smallstep programs and CA state in $STEP_CA_CONFIG_DIR and $STEP_CA_STATE_DIR."
}

main "$@"
