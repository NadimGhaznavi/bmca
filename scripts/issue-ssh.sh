#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"

usage() { printf 'Usage: %s --environment dev|prod --type host|user --key-id ID --key-file PATH --principal NAME [--principal NAME]... --provisioner-password-file FILE --key-password-file FILE [--lifetime DURATION]\n' "$(basename "$0")"; }

main() {
    local environment='' type='' key_id='' key_file='' provisioner_password='' key_password='' lifetime=''
    local -a principals=()
    while (($#)); do case $1 in
        --environment) environment=$2; shift 2;; --type) type=$2; shift 2;; --key-id) key_id=$2; shift 2;;
        --key-file) key_file=$2; shift 2;; --principal) principals+=("$2"); shift 2;;
        --provisioner-password-file) provisioner_password=$2; shift 2;; --key-password-file) key_password=$2; shift 2;;
        --lifetime) lifetime=$2; shift 2;; -h|--help) usage; exit 0;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; require_command "$STEP_CLI_BIN"
    [[ $type == host || $type == user ]] || die "Type must be host or user."
    [[ -n $key_id && $key_file == /* && ${#principals[@]} -gt 0 ]] || die "Key ID, absolute key path, and principals are required."
    require_file "$provisioner_password"; require_file "$key_password"; check_secret_mode "$provisioner_password"; check_secret_mode "$key_password"
    [[ ! -e $key_file ]] || die "Key file already exists: $key_file"
    [[ -d $(dirname "$key_file") ]] || die "Key output directory does not exist."
    [[ -n $lifetime ]] || { if [[ $type == host ]]; then lifetime=$SSH_HOST_DEFAULT_LIFETIME; else lifetime=$SSH_USER_DEFAULT_LIFETIME; fi; }
    local -a args=(ssh certificate "$key_id" "$key_file" --ca-url "https://$CA_NAME:$STEP_CA_PORT" \
        --root "$STEP_CA_CERTS_DIR/root_ca.crt" --provisioner-password-file "$provisioner_password" \
        --password-file "$key_password" --not-after "$lifetime")
    [[ $type == user ]] || args+=(--host)
    local principal; for principal in "${principals[@]}"; do args+=(--principal "$principal"); done
    umask 077; "$STEP_CLI_BIN" "${args[@]}"
    success "Issued SSH $type certificate for $key_id."
}
main "$@"
