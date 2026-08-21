---
title: Install Caddy Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Install Caddy Certificates

Verify and extract the transferred web archive:

```sh
root@app01:~ # cd /root/bmca-transfer
root@app01:/root/bmca-transfer # sha256sum -c pool-dev.tar.sha256
root@app01:/root/bmca-transfer # tar -xf pool-dev.tar
root@app01:/root/bmca-transfer # cd pool-dev
```

Install the certificate chain and decrypt the key:

```sh
root@app01:/root/bmca-transfer/pool-dev # install -d -o root -g caddy -m 0750 /etc/caddy/tls
root@app01:/root/bmca-transfer/pool-dev # sh -c 'cat pool-dev.osoyalce.com.crt intermediate_ca.crt > /etc/caddy/tls/full-chain.crt'
root@app01:/root/bmca-transfer/pool-dev # install -o root -g caddy -m 0644 root_ca.crt /etc/caddy/tls/root_ca.crt
root@app01:/root/bmca-transfer/pool-dev # openssl pkey -in pool-dev.osoyalce.com.key \
  -passin file:/root/.bmca-leaf -out /etc/caddy/tls/pool-dev.key
root@app01:/root/bmca-transfer/pool-dev # chown root:caddy /etc/caddy/tls/full-chain.crt /etc/caddy/tls/pool-dev.key
root@app01:/root/bmca-transfer/pool-dev # chmod 0640 /etc/caddy/tls/full-chain.crt /etc/caddy/tls/pool-dev.key
```

Configure Caddy:

```caddyfile
pool-dev.osoyalce.com {
    tls /etc/caddy/tls/full-chain.crt /etc/caddy/tls/pool-dev.key
    reverse_proxy 127.0.0.1:8000
}
```

Validate and reload:

```sh
root@app01:~ # caddy validate --config /etc/caddy/Caddyfile
root@app01:~ # systemctl reload caddy
root@app01:~ # curl --cacert /etc/caddy/tls/root_ca.crt https://pool-dev.osoyalce.com/
```
