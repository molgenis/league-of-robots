# Certificates for webservers

This role automatically creates SSL certificates for webservers (*.gcc.rug.nl), currently used for:
  * jenkins.gcc.rug.nl
  * docs.gcc.rug.nl

Creating and renewing certificates is handled using the ACME protocol and requires
* an account + credentials to manage certs for a certain domain and
* that the Certificate Authority (CA) that is able to sign certificates for that domain provides an ACME interface.
 
The account + credentials + URL for the CA's ACME interface are stored in the encrypted `group_vars/*/secrets.yml`

### Replacing existing certificates with new ones

On the webserver, delete the existing certificates, auto-renewal config and symlinks:

```
rm -r /etc/letsencrypt/live/${certificates_folder_name}
```

```
rm /etc/letsencrypt/renewal/${certificates_folder_name}.conf
```

```
rm /etc/pki/tls/private/localhost.key
rm /etc/pki/tls/certs/localhost.crt
rm /etc/pki/tls/certs/server-chain.crt
```

After running the above commands, you can run the certs_webserver role for the specific webserver. This will create new certificates, as well as the symlinks and auto-renewal configuration.
