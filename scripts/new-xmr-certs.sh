#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s [--output-dir DIR] [--provisioner-password-file FILE] [--key-password-file FILE] [--lifetime DURATION]\n' "$(basename "$0")"
}

main() {
    local output_dir="$PWD/new-certs"
    local provisioner_password_file='/root/.bmca'
    local key_password_file='/root/.bmca-leaf'
    local lifetime=''

    while (($#)); do
        case $1 in
            --output-dir) output_dir=$2; shift 2 ;;
            --provisioner-password-file) provisioner_password_file=$2; shift 2 ;;
            --key-password-file) key_password_file=$2; shift 2 ;;
            --lifetime) lifetime=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done

    [[ $output_dir == /* ]] || output_dir="$PWD/$output_dir"
    [[ ! -e $output_dir ]] || die "Output directory already exists: $output_dir"

    load_settings
    require_command tar
    require_command sha256sum
    require_file "$STEP_CA_CERTS_DIR/root_ca.crt"
    require_file "$STEP_CA_CERTS_DIR/intermediate_ca.crt"

    local output_parent archive checksum environment
    output_parent=$(dirname -- "$output_dir")
    [[ -d $output_parent ]] || die "Output parent directory does not exist: $output_parent"
    for environment in dev qa prod; do
        archive="$output_parent/xmr-certs-$environment.tar.gz"
        checksum="$archive.sha256"
        [[ ! -e $archive ]] || die "Archive already exists: $archive"
        [[ ! -e $checksum ]] || die "Checksum already exists: $checksum"
    done

    local -a common_args=(
        --env prod
        --output-dir "$output_dir"
        --provisioner-password-file "$provisioner_password_file"
        --key-password-file "$key_password_file"
    )
    [[ -z $lifetime ]] || common_args+=(--lifetime "$lifetime")

    issue_server() {
        local kind=$1 dns_name=$2
        "$SCRIPT_DIR/issue-x509.sh" \
            "${common_args[@]}" \
            --kind "$kind" \
            --subject "$dns_name" \
            --san "$dns_name"
    }

    local -a dev_certificates=(
        xmr-dev.osoyalce.com
        xmr-app-dev.osoyalce.com
        xmr-admin-dev.osoyalce.com
        xmr-db-dev.osoyalce.com
    )
    local -a qa_certificates=(
        xmr-qa.osoyalce.com
        xmr1-qa.osoyalce.com
        xmr-app1-qa.osoyalce.com
        xmr-admin1-qa.osoyalce.com
        xmr-db1-qa.osoyalce.com
        xmr2-qa.osoyalce.com
        xmr-app2-qa.osoyalce.com
        xmr-admin2-qa.osoyalce.com
        xmr-db2-qa.osoyalce.com
    )
    local -a prod_certificates=(
        xmr.osoyalce.com
        xmr1.osoyalce.com
        xmr-app1.osoyalce.com
        xmr-admin1.osoyalce.com
        xmr-db1.osoyalce.com
        xmr2.osoyalce.com
        xmr-app2.osoyalce.com
        xmr-admin2.osoyalce.com
        xmr-db2.osoyalce.com
    )

    issue_environment() {
        local dns_name kind
        for dns_name in "$@"; do
            kind=web-server
            [[ $dns_name != xmr-db* ]] || kind=mariadb-server
            issue_server "$kind" "$dns_name"
        done
    }

    issue_environment "${dev_certificates[@]}"
    issue_environment "${qa_certificates[@]}"
    issue_environment "${prod_certificates[@]}"

    create_bundle() (
        local bundle_environment=$1
        shift
        local bundle_archive="$output_parent/xmr-certs-$bundle_environment.tar.gz"
        local staging dns_name
        staging=$(mktemp -d "/tmp/xmr-certs-$bundle_environment.XXXXXX")
        trap 'rm -rf -- "$staging"' EXIT
        chmod 0700 "$staging"
        mkdir -m 0700 "$staging/certificates"
        install -m 0644 "$STEP_CA_CERTS_DIR/root_ca.crt" "$staging/root_ca.crt"
        install -m 0644 "$STEP_CA_CERTS_DIR/intermediate_ca.crt" "$staging/intermediate_ca.crt"
        for dns_name in "$@"; do
            install -m 0644 "$output_dir/$dns_name.crt" "$staging/certificates/$dns_name.crt"
            install -m 0600 "$output_dir/$dns_name.key" "$staging/certificates/$dns_name.key"
        done
        tar -C "$staging" -czf "$bundle_archive" root_ca.crt intermediate_ca.crt certificates
        chmod 0600 "$bundle_archive"
        (
            cd -- "$output_parent"
            sha256sum "$(basename -- "$bundle_archive")" >"$(basename -- "$bundle_archive").sha256"
        )
        chmod 0600 "$bundle_archive.sha256"
    )

    create_bundle dev "${dev_certificates[@]}"
    create_bundle qa "${qa_certificates[@]}"
    create_bundle prod "${prod_certificates[@]}"

    success "Generated XMR certificates in $output_dir and environment archives in $output_parent"
}

main "$@"
