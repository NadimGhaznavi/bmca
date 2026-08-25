#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"

main() {
    if [[ ${1:-} == -h || ${1:-} == --help ]]; then
        printf 'Usage: %s --env dev|prod\n' "$(basename "$0")"; exit 0
    fi
    [[ ${1:-} == --env && $# -eq 2 ]] || die "Usage: $(basename "$0") --env dev|prod"
    load_settings; select_environment "$2"; require_root; assert_host_matches_environment
    require_command gpg; require_command tar; require_command flock; require_command sha256sum
    require_file "$BACKUP_PASSPHRASE_FILE"; check_secret_mode "$BACKUP_PASSPHRASE_FILE"
    require_file "$STEP_CA_CONFIG_FILE"; [[ -d $STEP_CA_STATE_DIR ]] || die "CA state is missing."
    require_file "$BMCA_ROOT_CA_DIR/certs/root_ca.crt"
    require_file "$BMCA_ROOT_CA_DIR/secrets/root_ca_key"
    [[ ! -e $STEP_CA_SECRETS_DIR/root_ca_key ]] || die "Root private key found online; refusing backup."
    [[ -d $BACKUP_TARGET_DIR && -w $BACKUP_TARGET_DIR ]] || die "Backup target is not writable: $BACKUP_TARGET_DIR"
    install -d -o root -g root -m 0700 "$BACKUP_WORK_DIR"
    exec 9>"$BACKUP_WORK_DIR/backup.lock"; flock -n 9 || die "Another backup is running."

    local timestamp name
    timestamp=$(date -u '+%Y%m%dT%H%M%SZ'); name="bmca-$BMCA_ENV-$timestamp.tar.gpg"
    BMCA_BACKUP_LOCAL_FILE="$BACKUP_WORK_DIR/$name"; BMCA_BACKUP_WAS_ACTIVE=0; umask 077
    systemctl is-active --quiet step-ca.service && BMCA_BACKUP_WAS_ACTIVE=1
    cleanup_backup() { rm -f -- "$BMCA_BACKUP_LOCAL_FILE"; ((BMCA_BACKUP_WAS_ACTIVE == 0)) || systemctl start step-ca.service; }
    trap cleanup_backup EXIT
    ((BMCA_BACKUP_WAS_ACTIVE == 0)) || systemctl stop step-ca.service

    tar -C / -cpf - "${STEP_CA_CONFIG_DIR#/}" "${STEP_CA_STATE_DIR#/}" \
        "${BMCA_ROOT_CA_DIR#/}" "${INSTALL_CONF_DIR#/}/environment" |
        gpg --batch --yes --pinentry-mode loopback --passphrase-file "$BACKUP_PASSPHRASE_FILE" \
            --symmetric --cipher-algo AES256 --output "$BMCA_BACKUP_LOCAL_FILE"
    install -m 0600 "$BMCA_BACKUP_LOCAL_FILE" "$BACKUP_TARGET_DIR/$name"
    sha256sum "$BACKUP_TARGET_DIR/$name" >"$BACKUP_TARGET_DIR/$name.sha256"
    success "Encrypted backup created: $BACKUP_TARGET_DIR/$name"
}
main "$@"
