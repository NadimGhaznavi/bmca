---
Title: Install BMCA
Layout: Default
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Clone the GitHub Repo

```
root@sally:~ # git clone git@github.com:NadimGhaznavi/bmca
Cloning into 'bmca'...
remote: Enumerating objects: 485, done.
remote: Counting objects: 100% (194/194), done.
remote: Compressing objects: 100% (109/109), done.
remote: Total 485 (delta 101), reused 156 (delta 69), pack-reused 291 (from 1)
Receiving objects: 100% (485/485), 3.92 MiB | 4.40 MiB/s, done.
Resolving deltas: 100% (246/246), done.
root@sally:~ # cd bmca
root@sally:~/bmca 
```
---

# Install the DEV environment

```
root@sally:~/bmca # ./scripts/install.sh --environment dev
[SUCCESS] Installed bmca 0.2.27 for dev. Initialize or restore the CA before enabling the service.
root@sally:~/bmca # 
```

---

# Initialize the DEV environment

```
root@sally:~/bmca # ./scripts/initialize-ca.sh offline --environment dev --workspace /root/bmca-workspace

Generating root certificate... done!
Generating intermediate certificate... done!
Generating user and host SSH certificate signing keys... done!

✔ Root certificate: /root/bmca-workspace/certs/root_ca.crt
✔ Root private key: /root/bmca-workspace/secrets/root_ca_key
✔ Root fingerprint: 521c57f26af393b2af01d094050e30f204524b79cc079ac4fd87c3eb25ff5dfb
✔ Intermediate certificate: /root/bmca-workspace/certs/intermediate_ca.crt
✔ Intermediate private key: /root/bmca-workspace/secrets/intermediate_ca_key
✔ SSH user public key: /root/bmca-workspace/certs/ssh_user_ca_key.pub
✔ SSH user private key: /root/bmca-workspace/secrets/ssh_user_ca_key
✔ SSH host public key: /root/bmca-workspace/certs/ssh_host_ca_key.pub
✔ SSH host private key: /root/bmca-workspace/secrets/ssh_host_ca_key
✔ Database folder: /root/bmca-workspace/db
✔ Templates folder: /root/bmca-workspace/templates
✔ Default configuration: /root/bmca-workspace/config/defaults.json
✔ Certificate Authority configuration: /root/bmca-workspace/config/ca.json

Your PKI is ready to go. To generate certificates for individual services see 'step help ca'.

FEEDBACK 😍 🍻
  The step utility is not instrumented for usage statistics. It does not phone
  home. But your feedback is extremely valuable. Any information you can provide
  regarding how you’re using `step` helps. Please send us a sentence or two,
  good or bad at feedback@smallstep.com or join GitHub Discussions
  https://github.com/smallstep/certificates/discussions and our Discord 
  https://u.step.sm/discord.
[SUCCESS] Offline PKI created in /root/bmca-workspace. Keep it offline.
[SUCCESS] Online transfer bundle: /root/bmca-workspace-online-dev.tar
[SUCCESS] Ceremony manifest: /root/bmca-workspace-online-dev.tar.manifest
root@sally:~/bmca # 
```



