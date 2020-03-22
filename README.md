![behringer24/mailship](https://img.shields.io/badge/behringer24-mailship-blue)
![Docker build](https://img.shields.io/docker/cloud/build/behringer24/mailship.svg)
![Docker automated builds](https://img.shields.io/docker/cloud/automated/behringer24/mailship.svg)
![Docker pulls](https://img.shields.io/docker/pulls/behringer24/mailship.svg)
![Github stars](https://img.shields.io/github/stars/behringer24/mailship.svg?label=github%20%E2%98%85)

# mailship
Mailship is a single Docker container e-mail solution. Mailship can be used as simple standalone server or just as a solution for pulling e-mails to the big webail providers. Configuration is done by postfixadmin, a simple web UI to configure domains and mailboxes. The data is stored in sqlite and for the mail serving postfix and dovecot is used.

## Usecase
* Hosting your own webpage and info@your-domain.com style e-mail adresses.
* Have this server behind a reverse proxy that handles all the SSL stuff.
* No webmailer, antivirus or spam protection is included as the e-mails are pulled into well known big e-mail providers who know that stuff better.

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
# Uncomment to use postfixadmin behind a reverse proxy but
# expose the mail ports directly
#    expose:
#      - 80:
    ports:
      - "80:80"
      - "25:25"
      - "143:143"
      - "465:465"
      - "587:587"
      - "993:993"
      - "4190:4190"
      - "11334:11334"
    restart: always
    container_name: mailship

volumes:
  mail_dir:
  spool_mail:
  spool_postfix:
  sqlite:
```

If you want to run the port 80 behind a reverse proxy, then expose port 80 instead of the configuration

``` yml
[...]
    expose:
      - 80
    ports:
      - "25:25"
      - "143:143"
      - "465:465"
      - "587:587"
      - "993:993"
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

Now go to your <postfixadmin domain>/setup.php again and set up an admin account. after that you can go to /login.php and start configuring your server.