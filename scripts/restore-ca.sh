#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"

main() {
    local environment='' archive='' skip_safety=0
    while (($#)); do case $1 in
        -h|--help) printf 'Usage: %s --environment dev|prod --archive FILE [--skip-safety-backup]\n' "$(basename "$0")"; exit 0;;
        --environment) environment=$2; shift 2;; --archive) archive=$2; shift 2;;
        --skip-safety-backup) skip_safety=1; shift;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; require_root; assert_host_matches_environment
    require_command gpg; require_command tar; require_command rsync; require_command flock; require_command realpath
    require_file "$archive"; require_file "$BACKUP_PASSPHRASE_FILE"; check_secret_mode "$BACKUP_PASSPHRASE_FILE"
    archive=$(realpath -e "$archive")
    local backup_target_real
    backup_target_real=$(realpath -e "$BACKUP_TARGET_DIR")
    [[ $archive == "$backup_target_real"/* ]] || die "Archive must be under $BACKUP_TARGET_DIR"
    [[ ! -f $archive.sha256 ]] || (cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256")
    confirm "Restore $archive onto $CA_HOST? Current CA state will be replaced."
    exec 9>"/run/bmca-restore.lock"; flock -n 9 || die "Another restore is running."

    if ((skip_safety == 0)) && [[ -f $STEP_CA_CONFIG_FILE ]]; then
        "$SCRIPT_DIR/backup-ca.sh" --environment "$BMCA_ENV"
    fi
    if gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$BACKUP_PASSPHRASE_FILE" \
        --decrypt "$archive" | tar -tf - | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
        die "Backup archive contains an unsafe path."
    fi
    local staging; staging=$(mktemp -d /run/bmca-restore.XXXXXX)
    trap "rm -rf -- '$staging'" EXIT
    gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$BACKUP_PASSPHRASE_FILE" \
        --decrypt "$archive" | tar -C "$staging" -xpf -
    local restored_config="$staging/${STEP_CA_CONFIG_DIR#/}"
    local restored_state="$staging/${STEP_CA_STATE_DIR#/}"
    local restored_root_ca="$staging/${BMCA_ROOT_CA_DIR#/}"
    require_file "$restored_config/ca.json"; require_file "$restored_state/certs/root_ca.crt"
    require_file "$restored_config/$(basename "$STEP_CA_PASSWORD_FILE")"
    require_file "$restored_state/certs/intermediate_ca.crt"; require_file "$restored_state/secrets/intermediate_ca_key"
    require_file "$restored_root_ca/certs/root_ca.crt"; require_file "$restored_root_ca/secrets/root_ca_key"
    [[ ! -e $restored_state/secrets/root_ca_key ]] || die "Backup contains a root private key; refusing restore."
    "$STEP_CLI_BIN" certificate verify "$restored_state/certs/intermediate_ca.crt" --roots "$restored_state/certs/root_ca.crt"

    systemctl stop step-ca.service 2>/dev/null || true
    rsync -a --delete "$restored_config/" "$STEP_CA_CONFIG_DIR/"
    rsync -a --delete --chown="$STEP_CA_USER:$STEP_CA_GROUP" "$restored_state/" "$STEP_CA_STATE_DIR/"
    install -d -o root -g root -m 0700 "$BMCA_ROOT_CA_DIR"
    rsync -a --delete --chown=root:root "$restored_root_ca/" "$BMCA_ROOT_CA_DIR/"
    chmod 0700 "$BMCA_ROOT_CA_DIR" "$BMCA_ROOT_CA_DIR/secrets"
    chmod 0600 "$BMCA_ROOT_CA_DIR/secrets"/*
    chown root:"$STEP_CA_GROUP" "$STEP_CA_CONFIG_DIR" "$STEP_CA_CONFIG_FILE" "$STEP_CA_PASSWORD_FILE"
    chmod 0750 "$STEP_CA_CONFIG_DIR"; chmod 0640 "$STEP_CA_CONFIG_FILE" "$STEP_CA_PASSWORD_FILE"
    systemctl enable --now step-ca.service
    "$SCRIPT_DIR/validate-ca.sh" --environment "$BMCA_ENV"
    success "Restored $BMCA_ENV CA from $archive"
}
main "$@"
