#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
    printf 'Usage: %s --env dev|qa|prod --subject DNS_NAME [--key-password-file FILE]\n' "$(basename "$0")"
}

main() {
    local environment='' subject='' key_password_file='/root/.bmca-leaf'

    while (($#)); do
        case $1 in
            --env) environment=$2; shift 2 ;;
            --subject) subject=$2; shift 2 ;;
            --key-password-file) key_password_file=$2; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done

    [[ -n $environment && -n $subject ]] || {
        usage >&2
        die "Environment and subject are required."
    }
    case $environment in
        dev) [[ $subject == xmr-db-dev.osoyalce.com ]] || die "Invalid DEV database subject: $subject" ;;
        qa) [[ $subject =~ ^xmr-db[0-9]+-qa\.osoyalce\.com$ ]] || die "Invalid QA database subject: $subject" ;;
        prod) [[ $subject =~ ^xmr-db[0-9]+\.osoyalce\.com$ ]] || die "Invalid PROD database subject: $subject" ;;
        *) die "Environment must be 'dev', 'qa', or 'prod'." ;;
    esac

    require_root
    load_settings
    require_command scp
    require_command sha256sum
    require_command tar
    require_command openssl
    require_command install
    require_command systemctl
    require_file "$key_password_file"
    check_secret_mode "$key_password_file"
    [[ -n ${XMR_CERT_SOURCE_HOST:-} ]] || die "XMR_CERT_SOURCE_HOST is not configured."
    [[ ${XMR_CERT_SOURCE_DIR:-} == /* ]] || die "XMR_CERT_SOURCE_DIR must be an absolute path."

    umask 077
    local work_dir archive_name checksum_name leaf_cert encrypted_key
    local server_cert server_key backup_root backup_dir timestamp file
    work_dir=$(mktemp -d /tmp/install-db-cert.XXXXXX)
    trap 'rm -rf -- "$work_dir"' EXIT
    archive_name="xmr-certs-$environment.tar.gz"
    checksum_name="$archive_name.sha256"
    leaf_cert="$work_dir/certificates/$subject.crt"
    encrypted_key="$work_dir/certificates/$subject.key"
    server_cert="$work_dir/server-cert.pem"
    server_key="$work_dir/server-key.pem"

    info "Retrieving $archive_name from $XMR_CERT_SOURCE_HOST"
    scp -o BatchMode=yes \
        "root@$XMR_CERT_SOURCE_HOST:$XMR_CERT_SOURCE_DIR/$archive_name" "$work_dir/"
    scp -o BatchMode=yes \
        "root@$XMR_CERT_SOURCE_HOST:$XMR_CERT_SOURCE_DIR/$checksum_name" "$work_dir/"

    (
        cd -- "$work_dir"
        sha256sum -c "$checksum_name"
    )

    tar -xzf "$work_dir/$archive_name" \
        -C "$work_dir" \
        --no-same-owner \
        root_ca.crt \
        intermediate_ca.crt \
        "certificates/$subject.crt" \
        "certificates/$subject.key"

    openssl verify \
        -CAfile "$work_dir/root_ca.crt" \
        -untrusted "$work_dir/intermediate_ca.crt" \
        "$leaf_cert"
    openssl x509 -in "$leaf_cert" -noout -checkhost "$subject"
    openssl pkey \
        -in "$encrypted_key" \
        -passin "file:$key_password_file" \
        -out "$server_key"

    local certificate_public_key private_public_key
    certificate_public_key=$(openssl x509 -in "$leaf_cert" -pubkey -noout |
        openssl pkey -pubin -outform DER 2>/dev/null |
        sha256sum | awk '{print $1}')
    private_public_key=$(openssl pkey -in "$server_key" -pubout -outform DER 2>/dev/null |
        sha256sum | awk '{print $1}')
    [[ $certificate_public_key == "$private_public_key" ]] ||
        die "Certificate and private key do not match."

    cp -- "$leaf_cert" "$server_cert"
    printf '\n' >>"$server_cert"
    sed -n '/-----BEGIN CERTIFICATE-----/,$p' "$work_dir/intermediate_ca.crt" >>"$server_cert"

    timestamp=$(date -u +%Y%m%dT%H%M%SZ)
    backup_root='/var/backups/bmca'
    install -d -o root -g root -m 0700 "$backup_root"
    backup_dir=$(mktemp -d "$backup_root/mariadb-certificates-$timestamp.XXXXXX")
    chmod 0700 "$backup_dir"
    for file in cacert.pem server-cert.pem server-key.pem; do
        [[ ! -e /etc/mysql/$file ]] || cp -a -- "/etc/mysql/$file" "$backup_dir/"
    done

    install -o root -g mysql -m 0644 "$work_dir/root_ca.crt" /etc/mysql/cacert.pem
    install -o root -g mysql -m 0644 "$server_cert" /etc/mysql/server-cert.pem
    install -o root -g mysql -m 0640 "$server_key" /etc/mysql/server-key.pem

    systemctl restart mariadb

    success "Installed MariaDB certificate for $subject (previous files: $backup_dir)"
}

main "$@"
