# acme.sh
SSL Certificate manager using [acme-tiny](https://github.com/diafygi/acme-tiny) from Daniel Roesler.

This is a bash script to simplify managing certificates from [letsencrypt](https://letsencrypt.org/) but it can also be used with others that implement the ACME v2 API. By default it creates both RSA and EC (Elliptic Curve) certificates. Note that certbot does not support EC certificates at the time of writing this.

# Installation
Download the acme.sh script and make sure you check the code before you trust it.
Invoke the builtin installer with:

`sudo bash acme.sh install`

The installer:
* Copies the script to your /usr/local/bin directory and makes it executable.
* Installs acme-tiny using python pip.
* Creates /etc/acme with default configuration files.

# Configuration
* Review the configuration in /etc/acme and configure the challenge path on your webserver. 
* There is an example acme-challenge.conf file included for apache.
* The deploy.sh script is a stub that is copied to the certificate configuration and gets executed after each succesfull renewal.

# Create a certificate configuration for your domains.

For example `sudo acme.sh create mydomain.com www someotherdomain.com`

* Names that do not contain a period get the first name appended, so this creates a certificate for `mydomain.com`, `www.mydomain.com` and `someotherdomain.com`. But you may also specify all names as FQDN.
* Yes you can request a certificate for multiple domains if the challenges succeed.
* An /etc/acme/account.key will be generated if it does not exist. You may also copy your own key there.
* The configuration will be saved to `/etc/acme/mydomain.com/config`. Note that you can also pass some commandline options to prevent manual editing if you want to change the defaults. See the source for those.

# Request or renew your certificates

Command `sudo acme.sh renew` walks through all certificate configurations and requests certificates as needed or renews them when they are valid for less than RENEW_AGE days. After a successful request or renewal it executes `deploy.sh`. You can edit this script to do whatever you want, like copy certificates to another location or restart your webserver.
