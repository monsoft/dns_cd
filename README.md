# Informal acme.sh DNS API plugin for Crazy Domain DNS provider

## Why it is infomal ?
Because it's not following [acme.sh](https://github.com/acmesh-official/acme.sh) author "guidance" located on acme.sh project wiki. This plugin evaluated from my private script which I used to automate Let's Encrypt certificate renewal and I decided to adapt it little bit so it can be run as acme.sh DNS API plugin. It was tested on Debian and Ubuntu but I can't guarantee that it will works on other systems.

I use it for renewing certificates for my domains so it "does the job".

## Installation
To install dns_cd.sh DNS API plugin, copy it to `dnsapi` directory in `acme.sh` folder.
Plugin require [jq](https://stedolan.github.io/jq/) and `curl` to work, so it have to be installed in system.

```
sudo apt install -y jq curl
```

## Configuration
As Crazy Domain doesn't provide API for end users (only for resellers), we have to use login details used to access Crazy Domain management web dashboard.

```
 # Login details
  CR_USERNAME="Username"
  CR_PASSWORD="Password"
```
## Using plugin

For detailed information how to use `acme.sh` please visit project's Github repository [https://github.com/acmesh-official/acme.sh](https://github.com/acmesh-official/acme.sh).

I run it in that way:

```
./acme.sh --issue --dns dns_cd -d 'domain_name' --server letsencrypt --preferred-chain  "ISRG Root X1" --dnssleep 600
```
Crazy Domain is not quick in the case of reloading DNS zone so it usually take around 10 minutes to new record appear in their name servers. I use option `--dnssleep 600` so script will wait 10 minutes before it checks if `_acme-challenge.domain.com` record was created.

