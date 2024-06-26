---
title: "Integration of a local Cloudflare domain update service for use with Fritz!Box DynDNS feature"
date: 2024-03-22T00:02:18Z
draft: false
websiteURL: https://heyn.dev
websiteName: heyn.dev
---

This is a follow-up of the [How-to-use-Fritz!Box-DynDNS-feature-with-cloudflare]({{< ref "How-to-use-Fritz!Box-DynDNS-feature-with-cloudflare.md" >}}) guide.
As you may have noticed, the solution described in the old guide no longer works with newer versions of Fritz!OS.
This is because the Fritz!Box doesn't allow http DynDNS updates anymore, even if they point to local IPs.
This guide will provide an updated solution and clean up the old solution using docker compose.

## Understanding certificates and challenges

#### Digital certificates and CAs

A digital certificate is a file hosted on a server to enable encryption.
It contains the public key and information about it, information about the identity of its owner (called the subject), and the digital signature of an entity that has verified the contents of the certificate (called the issuer).
This allows others (relying parties) to rely upon signatures or on assertions made about the private key that corresponds to the certified public key.
The issuer, typically a Certificate Authority (CA), acts as a trusted third party, trusted by both the subject (owner) of the certificate and a relying party (client).
A client uses the CA certificate to authenticate the CA signature on the server certificate as part of the authorization before initiating a secure connection.
Typically, client software, such as browsers, includes a set of trusted CA certificates.

Certificates issued and signed by a trusted CA can then be used to establish secure connections to a server.
There are essential in order to circumvent a malicious party which happens to be on the route to a target server which acts as if it were the target, i.e. man-in-the-middle attack.

{{<details title="In other, simpler words">}}

A digital certificate is like a passport for a server, ensuring secure and trustworthy communication over the internet.
It contains:
- A public key for encryption,
- Information about the owner,
- Verification from a trusted entity (like a Certificate Authority).

This helps others trust the website's identity and encryption.
A Certificate Authority (CA) acts as a trusted middleman, verifying the certificate's details.
When you connect to a server, the CA's signature on the certificate gets checked to make sure it's legitimate.
Without these certificates, attackers are able to intercept communication.
{{</details>}}

#### ACME Challenges

The Automatic Certificate Management Environment (ACME) protocol is a communications protocol for automating interactions between certificate authorities and their users' servers, enabling the automated deployment of public key infrastructure.
Let's Encrypt is a certificate authority that uses this protocol to verify that you control the domain names in the certificates you want to get signed using "challenges".
There are two common challenges:

1) **HTTP**:
   With the HTTP challenge, the ACME client proves ownership of a domain by placing a specific file at a specific URL on the web server associated with that domain.
   The ACME server then makes an HTTP request to retrieve this file from the specified URL.
   If the file is found and contains the expected content, the challenge is considered successful. 
2) **DNS**:
   With the DNS challenge, the ACME client proves ownership of a domain by adding a specific DNS record to the domain's DNS zone.
   The ACME server then performs a DNS lookup to verify the presence of this DNS record.
   If the record is found and contains the expected value, the challenge is considered successful.

## Prerequisites

Before proceeding, make sure you have the following:

- A working server on your home network with docker i.e. docker-compose installed on it,
- A Cloudflare account with a domain added to it,
- A Fritz!Box router with the DynDNS feature.

## Step 1: Create a Cloudflare API Token

{{<details title="Exactly as described in the previous guide">}}
1. Login to your cloudflare account https://dash.cloudflare.com/login.
2. Then visit https://dash.cloudflare.com/profile/api-tokens
3. Click on 'Create Token'.
4. Set the permissions to allow "Zone - Zone - Read" and "Zone - DNS - Edit".
5. (optional) You can restrict the access to a specific domain via the Zone Resources. With "Include - Specific
   zone - `<your domain>`" the API key will only work to modify the DNS records of your specified domain.
6. Then click on the 'Continue to summary' button, then click on 'Create token' and copy the token for future use.
{{</details>}}

## Step 2: Write the Python Webserver

{{<details title="Exactly as described in the previous guide">}}
The following python file `app.py` is a minimal example of an IPv4 DNS record update.
An explanation of this file can be found in the previous guide.

```python filename="app.py"
import CloudFlare
import flask

app = flask.Flask(__name__)


@app.route('/', methods=['GET'])
def main():
    token = flask.request.args.get('token')
    zone = flask.request.args.get('zone')
    ipv4 = flask.request.args.get('ipv4')
    
    cf = CloudFlare.CloudFlare(token=token)
    zones = cf.zones.get(params={'name': zone})
    
    a_record = cf.zones.dns_records.get(zones[0]['id'], params={
    'name': '{}'.format(zone), 'match': 'all', 'type': 'A'})
    cf.zones.dns_records.put(zones[0]['id'], a_record[0]['id'], data={
    'name': a_record[0]['name'], 'type': 'A', 'content': ipv4, 'proxied': a_record[0]['proxied'],
    'ttl': a_record[0]['ttl']})
    
    return flask.jsonify({'status': 'success', 'message': 'Update successful.'}), 200

import os
import waitress

app.secret_key = os.urandom(24)
waitress.serve(app, host='0.0.0.0', port=80)
```
{{</details>}}

## Step 3: Setting up Caddy reverse proxy with DNS challenge

Caddy is a powerful and easy-to-use web server that emphasizes simplicity and automatic configuration.
We want to use its reverse proxy capabilities to route incoming requests to different backend servers.
In our case, these different backend servers are different Docker containers.
Caddy has a built-in ACME client to automatically obtain certificates for your website from Let's Encrypt.

Up until now, i.e. since the last guide, the Python web server has been running within the local network.
Ideally, this should remain the case.
However, this means that also the webserver cannot be accessed from the internet.
But this is essential for the HTTP challenge to obtain a trusted certificate for encryption.
However, the DNS challenge is appropriate, because it proves ownership of the domain at the DNS provider.
Unfortunately, the default caddy Docker container does not provide support for the Let's encrypt DNS challenge. 
Thus, we need to customize the caddy installation:

1) First, create a folder with the name `caddy` and cd into it.
   ```shell
   mkdir caddy && cd caddy
   ```
2) Within this folder, create another folder for build purposes and also cd into it.
   Name it `caddy-build`.
   ```shell
   mkdir caddy-build && cd caddy-build
   ```
3) Here, create a `Dockerfile`
   ```shell
   nano Dockerfile
   ```
   with the following content:
   ```dockerfile filename="Dockerfile"
   ARG VERSION=2
   
   FROM caddy:${VERSION}-builder AS builder
   
   RUN xcaddy build \
       --with github.com/caddy-dns/cloudflare
   
   FROM caddy:${VERSION}
   
   COPY --from=builder /usr/bin/caddy /usr/bin/caddy
   ```
4) Go back to the folder below and create the file `container-vars.env`.
   ```shell
   cd .. && nano container-vars.env
   ```
   Fill the file with the following:
   ```text
   MY_DOMAIN=<domain>
   CLOUDFLARE_API_TOKEN=<API token of domain>
   ```
   Of course replace `<domain>` and `<API token of domain>` with your values.
5) Then create the file `docker-compose.yml`
   ```shell
   nano docker-compose.yml
   ```
   with the following content:
   ```dockerfile filename="docker-compose.yml"
   version: "3.7"
   
   services:
     caddy:
       build: ./caddy-build
       hostname: caddy
       container_name: caddy
       restart: unless-stopped
       cap_add:
         - NET_ADMIN
       ports:
         - 80:80
         - 443:443
         - 443:443/udp
       volumes:
         - ./Caddyfile:/etc/caddy/Caddyfile
         - ./site:/srv
         - ./data:/data
         - ./config:/config
         - /etc/localtime:/etc/localtime:ro
       env_file:
         - container-vars.env
       networks:
         - caddynet
   
   networks:
     caddynet:
       external: true
   ```
6) The above docker-compose file specifies an external network.
   Because we want to organize i.e. encapsulate the various docker containers which are sitting behind the reverse proxy we will use a docker network.
   To create it, do the following:
   ```shell
   docker network create caddynet
   ```
7) Now you can start the container running
   ```shell
   docker-compose up -d
   ```

## Step 4: Configure docker compose file for flask server.

1) First, create a folder with the name `dyndns` and cd into it.
   ```shell
   mkdir dyndns && cd dyndns
   ```
2) Within this folder, create another folder for build purposes and also cd into it.
   Name it `dyndns-build`.
   ```shell
   mkdir dyndns-build && cd dyndns-build
   ```
3) Copy or move the Python file containing the webserver code into the lastly created folder.
   ```shell
   cp <path to Python file> .
   ```
4) Then create a `Dockerfile`
   ```shell
   nano Dockerfile
   ```
   with the following content:
   ```dockerfile filename="Dockerfile"
   FROM python:3-alpine
   
   WORKDIR /app
   
   RUN pip install --no-cache-dir cloudflare Flask waitress
   
   COPY app.py ./
   
   CMD [ "python", "./app.py" ]
   
   EXPOSE 80
   ```
5) Go back to the folder below and create the file `docker-compose.yml`.
   ```shell
   cd .. && nano docker-compose.yml
   ```
   Fill the file with the following:
   ```dockerfile filename="docker-compose.yml"
   version: '3.7'
   
   services:
     dyndns:
       container_name: dyndns
       build: ./dyndns-build
       hostname: dyndns
       restart: unless-stopped
       networks:
         - caddynet
   
   networks:
     caddynet:
       external: true
   ```
6) Now you can start the container running
   ```shell
   docker-compose up -d
   ```
   
## Step 5: Associate subdomain with local IP

With the web server and caddy reverse proxy set up, all we need to do is tie everything together to be able to connect to a local IP with https enabled.

1) Log into Fritz!Box and navigate to http://fritz.box/#homeNet.
2) Find your server by its hostname and click Edit.
3) Then move to `IP Adresses` and check the box `Always assign the same IPv4 address to this network device`.
   Also copy the local IP of the server for later use.
4) Go to https://dash.cloudflare.com/ and navigate to `Websites`.
   Then click on your domain and after that on `DNS`.
5) Add a record with type `A`.
   Use `dyndns` for the name and the local IP from above for the IPv4 address.
6) Go to the caddy folder and edit the Caddyfile, adding the following:
   ```text
   dyndns.{$MY_DOMAIN} {
        reverse_proxy dyndns:80
        tls {
                dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
   }
   ```
7) Reload caddy with
   ```shell
   docker exec caddy caddy reload --adapter caddyfile --config /etc/caddy/Caddyfile
   ```
8) Go again to the Fritz!Box web ui and navigate to http://fritz.box/#dyndns.
9) There put in the following values 
   - Update-URL:
     ```text
     https://dyndns.<your doamin>/?token=<pass>&zone=<domain>&ipv4=<ipaddr>
     ```
     Replace `<your domain>` with the domain you bought from Cloudflare.
   - Domainname: The domain you bought from Cloudflare.
   - Benutzername: You can leave it blank, it is not used.
   - Kennwort: The Cloudflare API Token you created earlier.
10) Lastly navigate to http://fritz.box/#netSet.
    Scroll down and click on `more settings`.
    There add `<your domain>` and `dyndns.<your doamin>` to the DNS rebind protection field.

Now that all is set, Fritz!Box can update the IP via the CloudFlare API.
