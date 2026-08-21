---
title: Install Python Database Certificate
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Install Python Database Certificate

Verify and extract the transferred application archive:

```sh
root@app01:~ # cd /root/bmca-transfer
root@app01:/root/bmca-transfer # sha256sum -c xmr-pool.tar.sha256
root@app01:/root/bmca-transfer # tar -xf xmr-pool.tar
root@app01:/root/bmca-transfer # cd xmr-pool
```

Install the application certificate and decrypt the key:

```sh
root@app01:/root/bmca-transfer/xmr-pool # install -d -o xmrpool -g xmrpool -m 0750 /etc/xmrpool/tls
root@app01:/root/bmca-transfer/xmr-pool # install -o xmrpool -g xmrpool -m 0644 \
  xmr-pool.crt root_ca.crt intermediate_ca.crt /etc/xmrpool/tls/
root@app01:/root/bmca-transfer/xmr-pool # openssl pkey -in xmr-pool.key \
  -passin file:/root/.bmca-leaf -out /etc/xmrpool/tls/mariadb-client.key
root@app01:/root/bmca-transfer/xmr-pool # chown xmrpool:xmrpool /etc/xmrpool/tls/mariadb-client.key
root@app01:/root/bmca-transfer/xmr-pool # chmod 0600 /etc/xmrpool/tls/mariadb-client.key
```

Use these Python connection settings:

```python
ssl = {
    "ca": "/etc/xmrpool/tls/root_ca.crt",
    "cert": "/etc/xmrpool/tls/xmr-pool.crt",
    "key": "/etc/xmrpool/tls/mariadb-client.key",
    "check_hostname": True,
}
```

Restart the application and confirm it connects to MariaDB over TLS.
