#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") offline --environment dev|prod --workspace DIR [--password-file FILE]
  $(basename "$0") import  --environment dev|prod --bundle FILE [--password-file FILE]
  $(basename "$0") local   --environment dev|prod --workspace DIR [--password-file FILE]

The offline command creates the complete PKI in DIR and a filtered online
bundle beside it. Keep DIR offline: it contains the X.509 root private key.
The password defaults to CA_PASSWORD_FILE from settings.cfg. Transfer the
bundle and password through separate secure channels.

The local command performs both steps on the CA host. DIR is retained and
contains the root private key, so it must be root-only and must not be shared.
EOF
}

offline_init() {
    local environment='' workspace='' password_file=''
    while (($#)); do case $1 in
        --environment) environment=$2; shift 2;; --workspace) workspace=$2; shift 2;;
        --password-file) password_file=$2; shift 2;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; password_file=${password_file:-$CA_PASSWORD_FILE}
    require_command "$STEP_CLI_BIN"; require_command tar; require_command sed; require_command sha256sum
    require_file "$password_file"; check_secret_mode "$password_file"
    [[ -n $workspace && $workspace == /* ]] || die "--workspace must be an absolute path."
    [[ ! -e $workspace ]] || die "Offline workspace already exists: $workspace"
    umask 077
    mkdir -p -- "$workspace"

    STEPPATH="$workspace" "$STEP_CLI_BIN" ca init --deployment-type standalone \
        --name "$PROJECT_NAME ($BMCA_ENV)" --dns "$CA_NAME" --address "$STEP_CA_LISTEN_ADDRESS" \
        --provisioner "$STEP_CA_PROVISIONER" --password-file "$password_file" \
        --provisioner-password-file "$password_file" --ssh

    "$SCRIPT_DIR/initialize-step-ca.sh" --environment "$BMCA_ENV" \
        --workspace "$workspace" --password-file "$password_file"

    # Convert ceremony-host paths to their final online locations.
    sed -i -E \
        -e 's#"root": "[^"]+"#"root": "'"$STEP_CA_CERTS_DIR"'/root_ca.crt"#' \
        -e 's#"crt": "[^"]+"#"crt": "'"$STEP_CA_CERTS_DIR"'/intermediate_ca.crt"#' \
        -e 's#"key": "[^"]+"#"key": "'"$STEP_CA_SECRETS_DIR"'/intermediate_ca_key"#' \
        -e 's#"hostKey": "[^"]+"#"hostKey": "'"$STEP_CA_SECRETS_DIR"'/ssh_host_ca_key"#' \
        -e 's#"userKey": "[^"]+"#"userKey": "'"$STEP_CA_SECRETS_DIR"'/ssh_user_ca_key"#' \
        -e 's#"dataSource": "[^"]+"#"dataSource": "'"$STEP_CA_DB_DIR"'"#' \
        "$workspace/config/ca.json"

    local bundle="$workspace-online-$BMCA_ENV.tar"
    tar -C "$workspace" -cf "$bundle" \
        certs config/ca.json templates \
        secrets/intermediate_ca_key secrets/ssh_host_ca_key secrets/ssh_user_ca_key
    if tar -tf "$bundle" | grep -q 'root_ca_key'; then
        rm -f -- "$bundle"; die "Safety failure: online bundle contains the root key."
    fi
    (cd "$(dirname "$bundle")" && sha256sum "$(basename "$bundle")") >"$bundle.sha256"
    local root_fingerprint bundle_digest manifest
    root_fingerprint=$("$STEP_CLI_BIN" certificate fingerprint "$workspace/certs/root_ca.crt")
    bundle_digest=$(sha256sum "$bundle" | awk '{print $1}')
    manifest="$bundle.manifest"
    printf '%s\n' \
        "project=$PROJECT_NAME" \
        "environment=$BMCA_ENV" \
        "ca_name=$CA_NAME" \
        "ceremony_utc=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "step_cli_version=$STEP_CLI_VERSION" \
        "step_ca_version=$STEP_CA_VERSION" \
        "root_fingerprint=$root_fingerprint" \
        "online_bundle=$(basename "$bundle")" \
        "online_bundle_sha256=$bundle_digest" >"$manifest"
    success "Offline PKI created in $workspace. Keep it offline."
    success "Online transfer bundle: $bundle"
    success "Ceremony manifest: $manifest"
}

online_import() {
    local environment='' bundle='' password_file=''
    while (($#)); do case $1 in
        --environment) environment=$2; shift 2;; --bundle) bundle=$2; shift 2;;
        --password-file) password_file=$2; shift 2;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; password_file=${password_file:-$CA_PASSWORD_FILE}
    require_root; assert_host_matches_environment
    require_file "$bundle"; require_file "$password_file"; check_secret_mode "$password_file"
    [[ -f $INSTALL_CONF_DIR/environment ]] || die "Run install.sh first."
    [[ $(<"$INSTALL_CONF_DIR/environment") == "$BMCA_ENV" ]] || die "Installed environment mismatch."
    tar -tf "$bundle" | grep -Eq '(^/|(^|/)\.\.(/|$))' && die "Unsafe path in transfer bundle."
    tar -tf "$bundle" | grep -q 'root_ca_key' && die "Transfer bundle contains a root private key."
    [[ ! -e $STEP_CA_CONFIG_FILE ]] || die "CA is already initialized: $STEP_CA_CONFIG_FILE"

    local staging
    staging=$(mktemp -d /run/bmca-import.XXXXXX)
    trap "rm -rf -- '$staging'" EXIT
    tar -C "$staging" -xf "$bundle"
    require_file "$staging/config/ca.json"; require_file "$staging/certs/root_ca.crt"
    require_file "$staging/certs/intermediate_ca.crt"; require_file "$staging/secrets/intermediate_ca_key"
    "$STEP_CLI_BIN" certificate verify "$staging/certs/intermediate_ca.crt" --roots "$staging/certs/root_ca.crt"

    install -o root -g "$STEP_CA_GROUP" -m 0640 "$staging/config/ca.json" "$STEP_CA_CONFIG_FILE"
    install -o root -g "$STEP_CA_GROUP" -m 0640 "$password_file" "$STEP_CA_PASSWORD_FILE"
    rsync -a --chown="$STEP_CA_USER:$STEP_CA_GROUP" "$staging/certs/" "$STEP_CA_CERTS_DIR/"
    rsync -a --chown="$STEP_CA_USER:$STEP_CA_GROUP" "$staging/secrets/" "$STEP_CA_SECRETS_DIR/"
    rsync -a --chown="$STEP_CA_USER:$STEP_CA_GROUP" "$staging/templates/" "$STEP_CA_STATE_DIR/templates/"
    chmod 0700 "$STEP_CA_SECRETS_DIR"; chmod 0600 "$STEP_CA_SECRETS_DIR"/*
    systemctl enable --now step-ca.service
    "$SCRIPT_DIR/validate-ca.sh" --environment "$BMCA_ENV"
    success "Imported, started, and validated the $BMCA_ENV CA. The X.509 root key remains offline."
}

local_init() {
    local environment='' workspace='' password_file=''
    while (($#)); do case $1 in
        --environment) environment=$2; shift 2;; --workspace) workspace=$2; shift 2;;
        --password-file) password_file=$2; shift 2;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; password_file=${password_file:-$CA_PASSWORD_FILE}
    require_root; assert_host_matches_environment
    [[ -n $workspace && $workspace == /* ]] || die "--workspace must be an absolute path."
    assert_safe_absolute_path "$workspace"

    offline_init --environment "$BMCA_ENV" --workspace "$workspace" --password-file "$password_file"
    online_import --environment "$BMCA_ENV" --bundle "$workspace-online-$BMCA_ENV.tar" \
        --password-file "$password_file"
    success "Created, installed, started, and validated the local $BMCA_ENV CA."
    info "Root CA material is retained in $workspace; keep this directory root-only."
}

case ${1:-} in
    offline) shift; offline_init "$@";;
    import) shift; online_import "$@";;
    local) shift; local_init "$@";;
    -h|--help) usage;;
    *) usage >&2; exit 2;;
esac
