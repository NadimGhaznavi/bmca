#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s --env dev|prod --workspace DIR [--password-file FILE]\n' "$(basename "$0")"
}

main() {
    local environment='' workspace='' password_file=''
    while (($#)); do
        case $1 in
            --env) [[ $# -ge 2 ]] || die "Missing value for --env."; environment=$2; shift 2 ;;
            --workspace) [[ $# -ge 2 ]] || die "Missing workspace."; workspace=$2; shift 2 ;;
            --password-file) [[ $# -ge 2 ]] || die "Missing password file."; password_file=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done

    load_settings
    select_environment "$environment"
    password_file=${password_file:-$CA_PASSWORD_FILE}
    require_command "$STEP_CLI_BIN"
    require_file "$password_file"
    check_secret_mode "$password_file"
    [[ -n $workspace && $workspace == /* ]] || die "--workspace must be an absolute path."
    assert_safe_absolute_path "$workspace"

    local ca_config="$workspace/config/ca.json"
    local source_templates="$BMCA_ROOT/templates/certs/x509"
    local target_templates="$workspace/templates/certs/x509"
    require_file "$ca_config"

    local -a provisioners=(
        "$STEP_CA_WEB_PROVISIONER"
        "$STEP_CA_DB_SERVER_PROVISIONER"
        "$STEP_CA_DB_REPLICATION_PROVISIONER"
        "$STEP_CA_DB_APPLICATION_PROVISIONER"
        "$STEP_CA_DB_ADMIN_PROVISIONER"
    )
    local -a template_names=(
        web-server.tpl
        mariadb-server.tpl
        mariadb-replication.tpl
        mariadb-client.tpl
        admin-client.tpl
    )

    local name template
    for template in "${template_names[@]}"; do require_file "$source_templates/$template"; done
    for name in "${provisioners[@]}"; do
        ! grep -Fq '"name": "'"$name"'"' "$ca_config" ||
            die "step-ca provisioner already exists: $name"
    done

    local rollback
    rollback=$(mktemp "$workspace/config/ca.json.rollback.XXXXXX")
    cp -- "$ca_config" "$rollback"
    rollback_config() {
        [[ ! -f $rollback ]] || cp -- "$rollback" "$ca_config"
        rm -f -- "$rollback"
    }
    trap rollback_config ERR

    install -d -m 0700 "$target_templates"
    for template in "${template_names[@]}"; do
        install -m 0600 "$source_templates/$template" "$target_templates/$template"
    done

    local index
    for index in "${!provisioners[@]}"; do
        name=${provisioners[$index]}
        template=${template_names[$index]}
        (
            cd -- "$workspace"
            STEPPATH="$workspace" "$STEP_CLI_BIN" ca provisioner add "$name" \
                --type JWK --create --ssh=false \
                --password-file "$password_file" \
                --ca-config config/ca.json \
                --x509-template "templates/certs/x509/$template" \
                --x509-min-dur "$X509_MIN_LIFETIME" \
                --x509-default-dur "$X509_DEFAULT_LIFETIME" \
                --x509-max-dur "$X509_MAX_LIFETIME"
        )
    done

    rm -f -- "$rollback"
    trap - ERR
    for name in "${provisioners[@]}"; do
        grep -Fq '"name": "'"$name"'"' "$ca_config" || die "Missing configured provisioner: $name"
    done
    success "Configured BMCA X.509 policy for $BMCA_ENV in $ca_config."
}

main "$@"
