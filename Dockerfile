FROM debian:10-slim

LABEL description "Simple mailserver in a mono Docker image" \
      maintainer "behringer24 <abe@activecube.de"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y -q --no-install-recommends \
    postfix postfix-mysql \
    dovecot-core dovecot-imapd dovecot-mysql dovecot-pop3d \
    && rm -rf /var/spool/postfix \
    && ln -s /var/mail/postfix/spool /var/spool/postfix \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

EXPOSE 25 143 465 587 993 4190 11334
