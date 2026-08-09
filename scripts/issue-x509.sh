#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"

usage() { printf 'Usage: %s --environment dev|prod --kind web-server|mariadb-server|mariadb-client|admin-client --subject NAME --output-dir DIR --provisioner-password-file FILE --key-password-file FILE [--san NAME]... [--lifetime DURATION]\n' "$(basename "$0")"; }

main() {
    local environment='' kind='' subject='' output='' provisioner_password='' key_password='' lifetime=''
    local -a sans=()
    while (($#)); do case $1 in
        --environment) environment=$2; shift 2;; --kind) kind=$2; shift 2;;
        --subject) subject=$2; shift 2;; --output-dir) output=$2; shift 2;;
        --provisioner-password-file) provisioner_password=$2; shift 2;;
        --key-password-file) key_password=$2; shift 2;; --san) sans+=("$2"); shift 2;;
        --lifetime) lifetime=$2; shift 2;; -h|--help) usage; exit 0;; *) die "Unknown argument: $1";; esac; done
    load_settings; select_environment "$environment"; require_command "$STEP_CLI_BIN"
    case $kind in web-server|mariadb-server|mariadb-client|admin-client) :;; *) usage >&2; die "Invalid certificate kind.";; esac
    [[ -n $subject && -n $output ]] || die "Subject and output directory are required."
    [[ $output == /* ]] || die "Output directory must be absolute."
    require_file "$provisioner_password"; require_file "$key_password"
    check_secret_mode "$provisioner_password"; check_secret_mode "$key_password"
    [[ $kind != *-server || ${#sans[@]} -gt 0 ]] || die "Server certificates require at least one SAN."
    lifetime=${lifetime:-$X509_DEFAULT_LIFETIME}; umask 077; mkdir -p -- "$output"; chmod 0700 "$output"
    local safe_subject=${subject//[^A-Za-z0-9_.-]/_}; local crt="$output/$safe_subject.crt" key="$output/$safe_subject.key"
    [[ ! -e $crt && ! -e $key ]] || die "Output certificate or key already exists."
    local -a args=(ca certificate "$subject" "$crt" "$key" --ca-url "https://$CA_NAME:$STEP_CA_PORT" \
        --root "$STEP_CA_CERTS_DIR/root_ca.crt" --provisioner "$STEP_CA_PROVISIONER" \
        --provisioner-password-file "$provisioner_password" --password-file "$key_password" --not-after "$lifetime")
    local san; for san in "${sans[@]}"; do args+=(--san "$san"); done
    "$STEP_CLI_BIN" "${args[@]}"
    chmod 0644 "$crt"; chmod 0600 "$key"
    success "Issued $kind certificate: $crt (private key: $key)"
}
main "$@"
