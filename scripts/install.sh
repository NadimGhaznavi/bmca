#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() { printf 'Usage: %s --environment dev|prod\n' "$(basename "$0")"; }

main() {
    local environment=''
    if (($# == 0)); then
        usage >&2
        exit 1
    fi

    while (($#)); do
        case $1 in
            --environment) [[ $# -ge 2 ]] || die "Missing environment."; environment=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done

    load_settings
    select_environment "$environment"
    require_root
    assert_host_matches_environment
    require_command install
    require_command rsync
    [[ -d $SOURCE_DIR/scripts && -f $SOURCE_DIR/conf/settings.cfg ]] ||
        die "Release source is incomplete: $SOURCE_DIR"

    [[ -x $STEP_CLI_BIN ]] || die "step is not installed at $STEP_CLI_BIN"
    [[ -x $STEP_CA_BIN ]] || die "step-ca is not installed at $STEP_CA_BIN"
    [[ $($STEP_CLI_BIN version) == *"/$STEP_CLI_VERSION "* ]] || die "Unexpected step CLI version."
    [[ $($STEP_CA_BIN version) == *"/$STEP_CA_VERSION "* ]] || die "Unexpected step-ca version."
    [[ -d $BACKUP_TARGET_DIR ]] || die "Backup target does not exist: $BACKUP_TARGET_DIR"

    local service_was_active=0 install_complete=0
    systemctl is-active --quiet step-ca.service && service_was_active=1
    restore_service() {
        if ((install_complete == 0 && service_was_active)); then
            systemctl daemon-reload || true
            systemctl start step-ca.service || true
        fi
    }
    trap restore_service EXIT
    ((service_was_active == 0)) || systemctl stop step-ca.service

    getent group "$STEP_CA_GROUP" >/dev/null || groupadd --system "$STEP_CA_GROUP"
    id "$STEP_CA_USER" >/dev/null 2>&1 ||
        useradd --system --gid "$STEP_CA_GROUP" --home-dir "$STEP_CA_STATE_DIR" --shell /usr/sbin/nologin "$STEP_CA_USER"

    install -d -o root -g root -m 0755 "$INSTALL_DIR" "$INSTALL_SCRIPTS_DIR" "$INSTALL_CONF_DIR" "$INSTALL_SYSTEMD_DIR" "$INSTALL_TEMPLATES_DIR"
    rsync -a --delete --exclude backups --exclude '*.bak' "$SOURCE_DIR/scripts/" "$INSTALL_SCRIPTS_DIR/"
    rsync -a --delete "$SOURCE_DIR/conf/" "$INSTALL_CONF_DIR/"
    rsync -a --delete "$SOURCE_DIR/systemd/" "$INSTALL_SYSTEMD_DIR/"
    rsync -a --delete "$SOURCE_DIR/templates/" "$INSTALL_TEMPLATES_DIR/"
    install -d -o root -g "$STEP_CA_GROUP" -m 0750 "$STEP_CA_CONFIG_DIR"
    install -d -o root -g root -m 0700 "$BMCA_CONFIG_DIR"
    install -d -o "$STEP_CA_USER" -g "$STEP_CA_GROUP" -m 0700 "$STEP_CA_STATE_DIR" "$STEP_CA_CERTS_DIR" "$STEP_CA_SECRETS_DIR" "$STEP_CA_DB_DIR"
    install -d -o root -g root -m 0700 "$BACKUP_WORK_DIR"
    install -D -o root -g root -m 0644 "$SYSTEMD_SOURCE_FILE" "$SYSTEMD_UNIT_FILE"

    if [[ -e $BACKUP_LINK && ! -L $BACKUP_LINK ]]; then
        die "Backup path exists and is not a symlink: $BACKUP_LINK"
    fi
    ln -sfn -- "$BACKUP_TARGET_DIR" "$BACKUP_LINK"
    printf '%s\n' "$BMCA_ENV" >"$INSTALL_CONF_DIR/environment"
    chmod 0644 "$INSTALL_CONF_DIR/environment"
    systemctl daemon-reload
    if [[ -f $STEP_CA_CONFIG_FILE && -f $STEP_CA_PASSWORD_FILE ]]; then
        systemctl enable --now step-ca.service
        if ((service_was_active)); then
            success "Replaced bmca with $PROJECT_VERSION for $BMCA_ENV and restarted step-ca."
        else
            success "Installed bmca $PROJECT_VERSION for $BMCA_ENV and started the existing CA."
        fi
    else
        systemctl disable step-ca.service 2>/dev/null || true
        success "Installed bmca $PROJECT_VERSION for $BMCA_ENV. Initialize or restore the complete CA before enabling the service."
    fi
    install_complete=1
    trap - EXIT
}

main "$@"
