#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s --environment dev|prod [--password-file FILE]\n' "$(basename "$0")"
}

main() {
    local environment='' password_file=''
    while (($#)); do
        case $1 in
            --environment) [[ $# -ge 2 ]] || die "Missing environment."; environment=$2; shift 2 ;;
            --password-file) [[ $# -ge 2 ]] || die "Missing password file."; password_file=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done

    load_settings
    select_environment "$environment"
    password_file=${password_file:-$CA_PASSWORD_FILE}
    require_root
    assert_host_matches_environment
    require_command "$STEP_CLI_BIN"
    require_command rsync
    require_command sed
    require_file "$password_file"
    check_secret_mode "$password_file"
    [[ -f $INSTALL_CONF_DIR/environment ]] || die "Run install.sh first."
    [[ $(<"$INSTALL_CONF_DIR/environment") == "$BMCA_ENV" ]] || die "Installed environment mismatch."
    [[ ! -e $STEP_CA_CONFIG_FILE ]] || die "CA is already initialized: $STEP_CA_CONFIG_FILE"
    [[ ! -e $BMCA_ROOT_CA_DIR ]] || die "Root CA directory already exists: $BMCA_ROOT_CA_DIR"

    umask 077
    install -d -o root -g root -m 0700 "$BMCA_ROOT_CA_DIR"
    STEPPATH="$BMCA_ROOT_CA_DIR" "$STEP_CLI_BIN" ca init --deployment-type standalone \
        --name "$PROJECT_NAME ($BMCA_ENV)" --dns "$CA_NAME" --address "$STEP_CA_LISTEN_ADDRESS" \
        --provisioner "$STEP_CA_PROVISIONER" --password-file "$password_file" \
        --provisioner-password-file "$password_file" --ssh

    "$SCRIPT_DIR/initialize-step-ca.sh" --environment "$BMCA_ENV" \
        --workspace "$BMCA_ROOT_CA_DIR" --password-file "$password_file"

    sed -i -E \
        -e 's#"root": "[^"]+"#"root": "'"$STEP_CA_CERTS_DIR"'/root_ca.crt"#' \
        -e 's#"crt": "[^"]+"#"crt": "'"$STEP_CA_CERTS_DIR"'/intermediate_ca.crt"#' \
        -e 's#"key": "[^"]+"#"key": "'"$STEP_CA_SECRETS_DIR"'/intermediate_ca_key"#' \
        -e 's#"hostKey": "[^"]+"#"hostKey": "'"$STEP_CA_SECRETS_DIR"'/ssh_host_ca_key"#' \
        -e 's#"userKey": "[^"]+"#"userKey": "'"$STEP_CA_SECRETS_DIR"'/ssh_user_ca_key"#' \
        -e 's#"dataSource": "[^"]+"#"dataSource": "'"$STEP_CA_DB_DIR"'"#' \
        "$BMCA_ROOT_CA_DIR/config/ca.json"

    "$STEP_CLI_BIN" certificate verify "$BMCA_ROOT_CA_DIR/certs/intermediate_ca.crt" \
        --roots "$BMCA_ROOT_CA_DIR/certs/root_ca.crt"
    install -o root -g "$STEP_CA_GROUP" -m 0640 \
        "$BMCA_ROOT_CA_DIR/config/ca.json" "$STEP_CA_CONFIG_FILE"
    install -o root -g "$STEP_CA_GROUP" -m 0640 "$password_file" "$STEP_CA_PASSWORD_FILE"
    rsync -a --chown="$STEP_CA_USER:$STEP_CA_GROUP" \
        "$BMCA_ROOT_CA_DIR/certs/" "$STEP_CA_CERTS_DIR/"
    rsync -a --exclude root_ca_key --chown="$STEP_CA_USER:$STEP_CA_GROUP" \
        "$BMCA_ROOT_CA_DIR/secrets/" "$STEP_CA_SECRETS_DIR/"
    rsync -a --chown="$STEP_CA_USER:$STEP_CA_GROUP" \
        "$BMCA_ROOT_CA_DIR/templates/" "$STEP_CA_STATE_DIR/templates/"
    chmod 0700 "$STEP_CA_SECRETS_DIR"
    chmod 0600 "$STEP_CA_SECRETS_DIR"/*

    systemctl enable --now step-ca.service
    "$SCRIPT_DIR/validate-ca.sh" --environment "$BMCA_ENV"
    success "Initialized, started, and validated BMCA for $BMCA_ENV."
    info "Local root CA material: $BMCA_ROOT_CA_DIR"
}

main "$@"
