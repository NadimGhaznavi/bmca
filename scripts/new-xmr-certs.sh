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

    # Development
    issue_server web-server xmr-dev.osoyalce.com
    issue_server web-server xmr-app-dev.osoyalce.com
    issue_server web-server xmr-admin-dev.osoyalce.com
    issue_server mariadb-server xmr-db-dev.osoyalce.com

    # QA
    issue_server web-server xmr-qa.osoyalce.com
    issue_server web-server xmr1-qa.osoyalce.com
    issue_server web-server xmr-app1-qa.osoyalce.com
    issue_server web-server xmr-admin1-qa.osoyalce.com
    issue_server mariadb-server xmr-db1-qa.osoyalce.com
    issue_server web-server xmr2-qa.osoyalce.com
    issue_server web-server xmr-app2-qa.osoyalce.com
    issue_server web-server xmr-admin2-qa.osoyalce.com
    issue_server mariadb-server xmr-db2-qa.osoyalce.com

    # Production
    issue_server web-server xmr.osoyalce.com
    issue_server web-server xmr1.osoyalce.com
    issue_server web-server xmr-app1.osoyalce.com
    issue_server web-server xmr-admin1.osoyalce.com
    issue_server mariadb-server xmr-db1.osoyalce.com
    issue_server web-server xmr2.osoyalce.com
    issue_server web-server xmr-app2.osoyalce.com
    issue_server web-server xmr-admin2.osoyalce.com
    issue_server mariadb-server xmr-db2.osoyalce.com

    success "Generated XMR certificates in $output_dir"
}

main "$@"
