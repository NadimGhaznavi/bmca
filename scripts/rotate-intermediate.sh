#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"

usage() {
    cat <<EOF
Usage:
  $(basename "$0") request --environment dev|prod [--password-file FILE]
  $(basename "$0") sign --environment dev|prod --request FILE [--password-file FILE]
  $(basename "$0") install --environment dev|prod --certificate FILE --key FILE [--password-file FILE]
EOF
}

public_key_digest() { openssl pkey "$@" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}'; }
certificate_key_digest() { openssl x509 -in "$1" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}'; }
csr_key_digest() { openssl req -in "$1" -pubkey -noout | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}'; }

create_request() {
    local environment='' password_file=''
    while (($#)); do case $1 in --environment) environment=$2; shift 2;; --password-file) password_file=$2; shift 2;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; password_file=${password_file:-$CA_PASSWORD_FILE}
    require_root; assert_host_matches_environment; require_command openssl; require_command sha256sum
    require_file "$password_file"; check_secret_mode "$password_file"; require_file "$STEP_CA_CERTS_DIR/root_ca.crt"
    local stamp dir csr key root_fingerprint
    stamp=$(date -u '+%Y%m%dT%H%M%SZ'); dir="$INTERMEDIATE_ROTATION_DIR/$stamp"
    csr="$dir/intermediate_ca.csr"; key="$dir/intermediate_ca_key"; umask 077
    install -d -o root -g root -m 0700 "$dir"
    "$STEP_CLI_BIN" certificate create "$PROJECT_NAME Intermediate ($BMCA_ENV)" "$csr" "$key" \
        --csr --kty EC --curve P-256 --password-file "$password_file"
    [[ $(csr_key_digest "$csr") == $(public_key_digest -in "$key" -passin "file:$password_file") ]] || die "CSR and key do not match."
    root_fingerprint=$("$STEP_CLI_BIN" certificate fingerprint "$STEP_CA_CERTS_DIR/root_ca.crt")
    printf '%s\n' "environment=$BMCA_ENV" "ca_name=$CA_NAME" "root_fingerprint=$root_fingerprint" \
        "csr_sha256=$(sha256sum "$csr" | awk '{print $1}')" >"$csr.manifest"
    success "CSR created: $csr"
    info "Sign this request with the local root using the sign command."
}

sign_request() {
    local environment='' request='' password_file=''
    while (($#)); do case $1 in --environment) environment=$2; shift 2;;
        --request) request=$2; shift 2;; --password-file) password_file=$2; shift 2;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; password_file=${password_file:-$CA_PASSWORD_FILE}
    require_file "$request"; require_file "$request.manifest"; require_file "$password_file"; check_secret_mode "$password_file"
    local root_crt="$BMCA_ROOT_CA_DIR/certs/root_ca.crt" root_key="$BMCA_ROOT_CA_DIR/secrets/root_ca_key"
    require_file "$root_crt"; require_file "$root_key"; require_command openssl; require_command sha256sum
    grep -Fxq "environment=$BMCA_ENV" "$request.manifest" || die "CSR environment does not match."
    grep -Fxq "ca_name=$CA_NAME" "$request.manifest" || die "CSR CA name does not match."
    grep -Fxq "root_fingerprint=$("$STEP_CLI_BIN" certificate fingerprint "$root_crt")" "$request.manifest" || die "CSR root fingerprint does not match."
    grep -Fxq "csr_sha256=$(sha256sum "$request" | awk '{print $1}')" "$request.manifest" || die "CSR checksum does not match."
    local certificate="${request%.csr}.crt"
    [[ ! -e $certificate ]] || die "Output already exists: $certificate"
    "$STEP_CLI_BIN" certificate sign "$request" "$root_crt" "$root_key" --profile intermediate-ca \
        --path-len 0 --not-after "$INTERMEDIATE_CA_LIFETIME" --password-file "$password_file" >"$certificate"
    openssl verify -CAfile "$root_crt" "$certificate"
    [[ $(csr_key_digest "$request") == $(certificate_key_digest "$certificate") ]] || die "Signed certificate does not match CSR."
    printf '%s\n' "environment=$BMCA_ENV" \
        "root_fingerprint=$("$STEP_CLI_BIN" certificate fingerprint "$root_crt")" \
        "certificate_sha256=$(sha256sum "$certificate" | awk '{print $1}')" >"$certificate.manifest"
    success "Signed intermediate: $certificate"
    info "Install the signed certificate on $CA_HOST using the install command."
}

install_certificate() {
    local environment='' certificate='' key='' password_file=''
    while (($#)); do case $1 in --environment) environment=$2; shift 2;; --certificate) certificate=$2; shift 2;;
        --key) key=$2; shift 2;; --password-file) password_file=$2; shift 2;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; password_file=${password_file:-$CA_PASSWORD_FILE}
    require_root; assert_host_matches_environment; require_file "$certificate"; require_file "$certificate.manifest"
    require_file "$key"; require_file "$password_file"; check_secret_mode "$password_file"; require_command openssl
    require_file "$STEP_CA_CERTS_DIR/intermediate_ca.crt"; require_file "$STEP_CA_SECRETS_DIR/intermediate_ca_key"
    grep -Fxq "environment=$BMCA_ENV" "$certificate.manifest" || die "Certificate environment does not match."
    grep -Fxq "root_fingerprint=$("$STEP_CLI_BIN" certificate fingerprint "$STEP_CA_CERTS_DIR/root_ca.crt")" "$certificate.manifest" || die "Certificate root fingerprint does not match."
    grep -Fxq "certificate_sha256=$(sha256sum "$certificate" | awk '{print $1}')" "$certificate.manifest" || die "Certificate checksum does not match."
    openssl verify -CAfile "$STEP_CA_CERTS_DIR/root_ca.crt" "$certificate"
    [[ $(certificate_key_digest "$certificate") == $(public_key_digest -in "$key" -passin "file:$password_file") ]] || die "Certificate and online key do not match."
    confirm "Install the replacement $BMCA_ENV intermediate and restart step-ca?"
    BMCA_ROTATION_ROLLBACK=$(mktemp -d /run/bmca-intermediate-rollback.XXXXXX)
    BMCA_ROTATION_ROLLBACK_NEEDED=0
    cleanup_rotation() {
        if ((BMCA_ROTATION_ROLLBACK_NEEDED)); then
            cp -a "$BMCA_ROTATION_ROLLBACK/intermediate_ca.crt" "$STEP_CA_CERTS_DIR/"
            cp -a "$BMCA_ROTATION_ROLLBACK/intermediate_ca_key" "$STEP_CA_SECRETS_DIR/"
            systemctl start step-ca.service || true
        fi
        rm -rf -- "$BMCA_ROTATION_ROLLBACK"
    }
    trap cleanup_rotation EXIT
    cp -a "$STEP_CA_CERTS_DIR/intermediate_ca.crt" "$BMCA_ROTATION_ROLLBACK/"
    cp -a "$STEP_CA_SECRETS_DIR/intermediate_ca_key" "$BMCA_ROTATION_ROLLBACK/"
    BMCA_ROTATION_ROLLBACK_NEEDED=1
    systemctl stop step-ca.service
    install -o "$STEP_CA_USER" -g "$STEP_CA_GROUP" -m 0600 "$certificate" "$STEP_CA_CERTS_DIR/intermediate_ca.crt"
    install -o "$STEP_CA_USER" -g "$STEP_CA_GROUP" -m 0600 "$key" "$STEP_CA_SECRETS_DIR/intermediate_ca_key"
    if systemctl start step-ca.service && "$SCRIPT_DIR/validate-ca.sh" --environment "$BMCA_ENV"; then
        BMCA_ROTATION_ROLLBACK_NEEDED=0
        success "Replacement intermediate installed. Create an encrypted backup now."
    else
        die "Replacement failed validation; previous intermediate restored."
    fi
}

case ${1:-} in request) shift; create_request "$@";; sign) shift; sign_request "$@";; install) shift; install_certificate "$@";; -h|--help) usage;; *) usage >&2; exit 2;; esac
