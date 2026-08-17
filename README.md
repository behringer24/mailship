![behringer24/mailship](https://img.shields.io/badge/behringer24-mailship-blue)
![Docker build](https://github.com/behringer24/mailship/actions/workflows/docker-image.yml/badge.svg)
![Docker pulls](https://img.shields.io/docker/pulls/behringer24/mailship.svg)
![Github stars](https://img.shields.io/github/stars/behringer24/mailship.svg?label=github%20%E2%98%85)

# mailship
Mailship is a single Docker container e-mail solution. Mailship can be used as simple standalone server or just as a solution for pulling e-mails to the big webmail providers. Configuration is done by postfixadmin, a simple web UI to configure domains and mailboxes. The data is stored in sqlite and for the mail serving postfix and dovecot is used.

## Usecase
* Hosting your own webpage and info@your-domain.com style e-mail adresses.
* Have this server behind a reverse proxy that handles all the SSL stuff.
* Roundcube webmail is included and served under `/webmail`. No antivirus or spam protection is included.
* Having multiple services in one container is an antipattern and I know that. Just interpret "mail" as one service ;-)

## Images

Images are built by GitHub Actions and published to both registries:

| Tag | Built from | Pull |
|---|---|---|
| `latest` | `master` | `ghcr.io/behringer24/mailship:latest` |
| `canary` | `development` | `ghcr.io/behringer24/mailship:canary` |
| `sha-<commit>` | every build | pin this to make a deployment reproducible |

The same tags are pushed to Docker Hub as `behringer24/mailship`.

## Getting set up
### docker-compose.yml
Use this docker compose file as an example how to set up mailship in your environment. 

``` yml
version: "3"

services:
  mailship:
    build: .
    image: behringer24/mailship
    environment: 
      POSTFIXADMIN_SETUP_PASSWORD: 
    volumes:
      - mail_dir:/var/vmail
      - spool_mail:/var/spool/mail
      - spool_postfix:/var/spool/postfix
      - sqlite:/etc/postfix/sqlite
      - dkim:/etc/opendkim/keys
      - roundcube:/var/lib/roundcube
    ports:
      - "80:80"
      - "25:25"
      - "110:110"
      - "143:143"
      - "465:465"
      - "587:587"
      - "993:993"
      - "995:995"
      - "4190:4190"
      - "11334:11334"
    restart: always
    container_name: mailship

volumes:
  mail_dir:
  spool_mail:
  spool_postfix:
  sqlite:
  dkim:
  roundcube:
```

If you want to run the port 80 behind a reverse proxy, then expose port 80 instead of the configuration

``` yml
[...]
    expose:
      - 80
    ports:
      - "25:25"
      - "110:110"
      - "143:143"
      - "465:465"
      - "587:587"
      - "993:993"
      - "995:995"
      - "4190:4190"
      - "11334:11334"
[...]
```

The volumes are importand to persist the emails and configuration.

When the server is running the container go to your <postfixadmin domain>/setup.php (port 80 of the container) and set a setup password. Postfixadmin tells you to put the generated hash into the config.php file. Please copy that hash into your docker-compose.yml behind POSTFIXADMIN_SETUP_PASSWORD:

``` yml
[...]
services:
  mailship:
    build: .
    image: behringer24/mailship
    environment: 
      POSTFIXADMIN_SETUP_PASSWORD: <yourhashhere>
    volumes:
      - mail_dir:/var/vmail
      - spool_mail:/var/spool/mail
      - spool_postfix:/var/spool/postfix
      - sqlite:/etc/postfix/sqlite
[...]
```

IMPORTANT: Postfixadmin since version 3 generates Hashes with '$'. You have to make them double $ so it works in the docker-compose.yml! Every $ in the hash must be changed to $$. Otherwise you get an error when you do docker-compose up -d
  
Now go to your <postfixadmin domain>/setup.php again and set up an admin account. after that you can go to /login.php and start configuring your server.

## Webmail

Roundcube is served under `/webmail`, next to postfixadmin at `/`. Users log in
with their full e-mail address and mailbox password -- the same credentials
postfixadmin issues, no separate account.

Outgoing mail goes through submission on port 587 with the credentials of the
logged in user, not through port 25. That is deliberate: port 25 accepts mail
from `127.0.0.0/8` via `permit_mynetworks` without authenticating, and Postfix'
`reject_authenticated_sender_login_mismatch` only applies to authenticated
senders. Going through submission makes Postfix enforce that the From address
belongs to the account, so one user cannot send as another mailbox on the same
server.

The `identity_switch` plugin is enabled, which is what makes several mailboxes
usable in one session: a user adds their other mailboxes under Settings ->
Identities and then finds an account switcher in the user menu, including an
unread counter per account. Since every mailbox lives on this server, the host
for each additional account is `localhost:143`.

Mount a volume at `/var/lib/roundcube`. It holds the database, the generated
`des_key`, and Roundcube's temp and log directories. Without it, user settings,
address books and the configured additional accounts are lost whenever the
container is recreated.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `ROUNDCUBE_DES_KEY` | *(empty)* | Encrypts session contents and, through `identity_switch`, the stored passwords of a user's additional accounts. Left empty, a key is generated once into the volume, because an empty key would leave those passwords unprotected without any visible error. Set it to manage the key outside the volume -- and treat it like a production secret: whoever has it and the database has every mailbox a user added. |
| `ROUNDCUBE_PRODUCT_NAME` | `Webmail` | Name shown in the browser title and on the login page. |
| `ROUNDCUBE_DB` | `/var/lib/roundcube/roundcube.db` | Path to the sqlite database. |

### Notes

* Server side filters and vacation replies are not available: this image runs
  neither sieve nor managesieve, so Roundcube's `managesieve` plugin is off.
* The web installer is removed from the image rather than only disabled.
* TLS is expected to be terminated by the reverse proxy in front of the
  container. nginx derives `HTTPS` from `X-Forwarded-Proto` so that PHP marks
  session cookies as `secure` and builds `https://` URLs -- which is why
  Roundcube's own `use_https` is not needed, and why `force_https` has to stay
  off: it would redirect and, behind a proxy that already serves HTTPS, produce
  a redirect loop.

## DKIM

Mailship signs outgoing mail with DKIM. Keys are created automatically for every
active domain in postfixadmin, so adding a domain in the web UI is enough — you
only have to publish its DNS record.

### Setting it up

1. Mount the `dkim` volume as shown above. **Mount `/etc/opendkim/keys`, never
   `/etc/opendkim`** — the latter hides the tables that live in the image. Without
   the volume the keys are recreated whenever the container is recreated, and
   your published DNS records silently stop matching.
2. Start the container and read the TXT records from the log:

   ``` bash
   docker logs mailship 2>&1 | grep -A20 "publish these TXT records"
   ```

   They are also written to `dns-records.txt` inside the volume:

   ``` bash
   docker exec mailship cat /etc/opendkim/keys/dns-records.txt
   ```
3. Publish each record at your DNS provider and verify it:

   ``` bash
   docker exec mailship opendkim-testkey -d example.com -s mail -vvv
   ```

Until a record resolves correctly, mailship logs a warning every few minutes and
mails a reminder to `POSTMASTER_ADDRESS` about once a day, containing the record
to publish. A domain without a matching record is simply left unsigned, it is
never rejected or deferred.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `DKIM_DOMAINS` | *(empty)* | Extra domains to sign for, separated by space, comma or semicolon. Use it for names that are not virtual domains in postfixadmin, in particular the host name in `MAIL_HOST`, which is where cron and bounce mail comes from. |
| `DKIM_SELECTOR` | `mail` | DNS selector, giving `<selector>._domainkey.<domain>`. |
| `DKIM_KEY_SIZE` | `2048` | RSA key size. A 2048 bit key produces a TXT value of roughly 400 characters; use `1024` if your DNS provider refuses it. |
| `DKIM_MILTER` | `inet:127.0.0.1:12345` | Milter endpoint Postfix talks to. Set it to `""` to disable signing and verification entirely. |
| `DKIM_AUTODISCOVER` | `true` | Set to anything else to ignore the postfixadmin database and use `DKIM_DOMAINS` only. |
| `DKIM_CHECK_INTERVAL` | `300` | Seconds between reconciliation runs. |
| `DKIM_NOTIFY_INTERVAL` | `86400` | Minimum seconds between two reminder mails for the same domain. |

### Notes

* The `dkim` volume holds private key material and deserves the same backup and
  access treatment as the `sqlite` volume.
* Incoming mail is verified as well and gets an `Authentication-Results` header,
  but the result is never used to reject or defer a message.
* If your DNS zone has a wildcard TXT record, lookups for
  `<selector>._domainkey.<domain>` return the wildcard value instead of NXDOMAIN
  until the real record exists. An explicit record always wins over a wildcard,
  so DKIM still works — but checking tools report confusing errors in the
  meantime.
