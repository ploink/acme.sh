# acme.sh
SSL Certificate manager using [acme-tiny](https://github.com/diafygi/acme-tiny) from Daniel Roesler.

<sup>(not to be confused with [Neilpang/acme.sh](https://github.com/Neilpang/acme.sh))</sup>

This is a bash script to simplify managing certificates from [letsencrypt](https://letsencrypt.org/) but it can also be used with others that implement the ACME v2 API. By default it creates both RSA and EC (Elliptic Curve) certificates. I initially wrote this script because certbot did not support EC certificates.

# Installation
Download the acme.sh script and make sure you check the code before you trust it.

`curl https://raw.githubusercontent.com/ploink/acme.sh/master/acme.sh -o acme.sh`

Invoke the builtin installer with:

`sudo bash acme.sh install`

The installer:
* Copies the script to your /usr/local/bin directory and makes it executable.

And if the installer is run for the first time:
* Installs acme-tiny using python pip.
* Creates /etc/acme with default configuration.
* Symlinks the script in /etc/cron.daily for automated renewal.

# Configuration
* Review the configuration in /etc/acme and configure the challenge path on your webserver. 
* There is an example acme-challenge.conf file included for apache. It may be sufficient to symlink or copy it into /etc/httpd/conf.d and restart apache.
* The deploy.sh script is a stub that is copied to the certificate configuration and gets executed after each succesfull renewal.

# Create a certificate configuration for your domains.

For example `sudo acme.sh create mydomain.com www someotherdomain.com`

* Names that do not contain a period get the first name appended, so this creates a certificate for `mydomain.com`, `www.mydomain.com` and `someotherdomain.com`. But you may also specify all names as FQDN.
* Yes you can request a certificate for multiple domains if the challenges succeed.
* An /etc/acme/account.key will be generated if it does not exist. You may also copy your own key there.
* The configuration will be saved to `/etc/acme/mydomain.com/config`. Note that you can also pass some commandline options to prevent manual editing if you want to change the defaults. See the source for those.

# Request or renew your certificates

Command `sudo acme.sh renew` walks through all certificate configurations and requests certificates as needed or renews them when they are valid for less than RENEW_AGE days. After a successful request or renewal it executes `deploy.sh`. You can edit this script to do whatever you want, like copy certificates to another location or restart your webserver.

# Webserver configuration

Apache can load multiple certificates for a domain. This allows for configuration of both RSA and EC certificates:
```
SSLCertificateKeyFile       /etc/acme/mydomain.com/rsa.key
SSLCertificateFile          /etc/acme/mydomain.com/rsa.crt
SSLCertificateKeyFile       /etc/acme/mydomain.com/ec.key
SSLCertificateFile          /etc/acme/mydomain.com/ec.crt
```
In particular the EC certificate allows us to jack up security by limiting the server to only secure protocols, high strenght ciphers with ephemeral keys and still support a wide range of clients. My configuration in Apache:
```
SSLUseStapling              on
SSLProtocol                 all -SSLv3 -TLSv1 -TLSv1.1
SSLCipherSuite              HIGH+kECDHE:!TLSv1:!SSLv3:!SHA256:!SHA384:@STRENGTH
```
This supports many clients starting from Safari 9, Android 4.4.1, IE 11. Chrome 49 on WinXP is supported using RSA.
Test you webserver security at https://www.ssllabs.com/ssltest/
