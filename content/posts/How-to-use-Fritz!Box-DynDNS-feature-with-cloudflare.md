---
title: "How to Use Fritz!Box DynDNS Feature With Cloudflare"
date: 2023-12-29T00:58:23Z
draft: false
websiteURL: https://heyn.dev
websiteName: heyn.dev
---

In the age of cloud storage services like Google Drive and Dropbox, it has become easier than ever to store data online.
However, the convenience of these tools comes at a significant cost: your privacy.
Despite frequent reports of data breaches, corporate and government surveillance, and other privacy violations, many
people still use these services not because they agree to it, but because setting up their own servers is an incredibly
challenging.
This guide and following ones will help to do just do that.
In this guide, we'll explore how to seamlessly integrate Fritz!Box's DynDNS feature with Cloudflare, allowing you to
access your home network remotely.

## Understanding DynDNS

Before we delve into the setup process, let's briefly understand the key components:

### Dynamic IP

In the early days of ISPs, most Internet usage was typically limited to a few minutes to a few hours per week.
Providing each subscriber with a static IP address for such infrequent use would have been prohibitively expensive.
As broadband connections have become more common and most connections remain "always-on," even when users are not
actively using the Internet, the practical reasons for not assigning a static IP have shifted.
Dynamic addressing streamlines administration for ISPs by eliminating the need to manually assign and manage IPs on a
per-customer basis.
It also increases security by making it more difficult for malicious actors to target specific devices based on their IP
addresses.
Because dynamic IPs are periodically reassigned, it becomes more difficult for attackers to track and target individual
devices over time.

### DynDNS

DNS is used to associate a particular name with a particular static IP address.
As the IP is constantly changing with a dynamic IP, DynDNS comes into play.
The DNS provider must be informed each time there is a change so that it forwards to the new IP.
Most routers have a build in DynDNS function, that will do that automatically for you.

## Problem with Cloudflare and Fritz!Box DynDNS feature

Fritz!Box DynDNS works by visiting an address of the DNS provider when the IP of the Fritz!Box changes.
It is passed through the URL, which updates the DNS redirection.
With most DNS providers you set up the specific update URL and it just works.
With Cloudflare, unfortunately, you have to use their API to do the update manually.
Their API scheme needs json encoded headers and content and other things, so it cannot use a single URL.

```bash
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records/<dns_record_id>" -d '{"content":"<new public IP>","name":"<domain>","type":"<A for IPv4 and AAAA for IPv6>"}' --header "Authorization: Bearer <API token of domain>"
```

But since there is no other viable option to update the IP via the Fritz!Box, we need to set up our own server to act as
a middleware/translator.
We’ll do this via Python using Flask and the Cloudflare API library.

## Prerequisites

Before proceeding, make sure you have the following:

- A working server on your home network,
- A python installation with cloudflare, flask and waitress packages,
- A Cloudflare account with a domain added to it,
- A Fritz!Box router with the DynDNS feature.

## Step 1: Create a Cloudflare API Token

1. Login to your cloudflare account https://dash.cloudflare.com/login.
2. Then visit https://dash.cloudflare.com/profile/api-tokens
3. Click on 'Create Token'.
4. Set the permissions to allow "Zone - Zone - Read" and "Zone - DNS - Edit".
5. (optional) You can restrict the access to a specific domain via the Zone Resources. With "Include - Specific
   zone - `<your domain>`" the API key will only work to modify the DNS records of `<your domain>`.
6. Then click on the 'Continue to summary' button, then click on 'Create token' and copy the token for future use.

## Step 2: Create the Python Webserver

We first create a file `app.py`.
In the Fritz!Box DynDNS tab you have to specify an update URL.
Here you can include certain placeholders to send the required information to the DynDNS provider (
See https://avm.de/service/wissensdatenbank/dok/FRITZ-Box-7590-AX/30_Dynamic-DNS-in-FRITZ-Box-einrichten/ for more
infos).
For Cloudflare, we only need the domain aka the zone, the API token and either the new ipv4, the new ipv6 or both
addresses.
To retrieve the arguments from the update URL, we use:

```python filename="app.py"
import CloudFlare
import flask

app = flask.Flask(__name__)


@app.route('/', methods=['GET'])
def main():
    token = flask.request.args.get('token')
    zone = flask.request.args.get('zone')
    ipv4 = flask.request.args.get('ipv4')
    ipv6 = flask.request.args.get('ipv6')
```

With the necessary arguments, we can call the Cloudflare API via its library:

```python filename="app.py"
    cf = CloudFlare.CloudFlare(token=token)
    zones = cf.zones.get(params={'name': zone})
```

For ipv4 use:

```python filename="app.py"
    a_record = cf.zones.dns_records.get(zones[0]['id'], params={
        'name': '{}'.format(zone), 'match': 'all', 'type': 'A'})
    cf.zones.dns_records.put(zones[0]['id'], a_record[0]['id'], data={
        'name': a_record[0]['name'], 'type': 'A', 'content': ipv4, 'proxied': a_record[0]['proxied'],
        'ttl': a_record[0]['ttl']})
```

For ipv6 use:

```python filename="app.py"
    aaaa_record = cf.zones.dns_records.get(zones[0]['id'], params={
        'name': '{}'.format(zone), 'match': 'all', 'type': 'AAAA'})
    cf.zones.dns_records.put(zones[0]['id'], aaaa_record[0]['id'], data={
        'name': aaaa_record[0]['name'], 'type': 'AAAA', 'content': ipv6, 'proxied': aaaa_record[0]['proxied'],
        'ttl': aaaa_record[0]['ttl']})
```

To signal success we do the following:

```python filename="app.py"
    return flask.jsonify({'status': 'success', 'message': 'Update successful.'}), 200
```

Now the only thing left is to serve the flask application.
While flaks has its own small built-in server, the flask documentation suggests using alternatives such as waitress:

```python filename="app.py"
import os
import waitress

app.secret_key = os.urandom(24)
waitress.serve(app, host='0.0.0.0', port=<webserver port>)
```

That is all.
`<webserver port>` should be chosen such that it won't interfere with other things you have running locally.
Of course, it is a good idea to have some sort of error handling.
Now you can launch the webserver.

```bash
python app.py
```

I also distribute a docker container via GitHub.
The repository can be found at https://github.com/sneakyHulk/cloudflare-dyndns.

## Step 3: Set up Fritz!Box

In the DynDNS tab paste the following values:

- Update URL:
  ```text
  http://<server host name or ip address>:<webserver port>?token=<pass>&zone=<domain>&ipv4=<ipaddr>&ipv6=<ip6addr>
  ```
  Replace `<server host name or ip address>` with the hostname or the local ip of the server and `<webserver port>` with
  the port on which the webserver is running.
- Domainname: The domain you bought from Cloudflare.
- Benutzername: You can leave it blank, it is not used.
- Kennwort: The Cloudflare API Token you created earlier.

Now the Fritz!Box should update the DNS entry every time the ISP change the IP.

## Update

Since after the 7.50 Fritz!OS update http updates don't work anymore.
Also, we want to create a more organised working context.
There is another guide on how to integrate this into a docker compose enabled caddy reverse proxied system.
It can be found at [Integration-of-a-local-Cloudflare-domain-update-service-for-use-with-Fritz!Box-DynDNS-feature]({{< ref "Integration-of-a-local-Cloudflare-domain-update-service-for-use-with-Fritz!Box-DynDNS-feature.md" >}}).
