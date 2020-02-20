FROM debian:10-slim

LABEL description "Simple mailserver in a mono Docker image" \
      maintainer "behringer24 <abe@activecube.de>"

ARG DEBIAN_FRONTEND=noninteractive
ARG SQLITE_PATH=/srv/postfixadmin/database

ENV POSTFIXADMIN_DB_TYPE=sqlite \
    POSTFIXADMIN_DB_HOST=/var/mail.db \
    POSTFIXADMIN_DB_USER=user \
    POSTFIXADMIN_DB_PASSWORD=topsecret \
    POSTFIXADMIN_DB_NAME=postfixadmin

# Set PHP install sources
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates apt-transport-https wget gnupg2 && \
    wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add - && \
    echo "deb https://packages.sury.org/php/ buster main" | tee /etc/apt/sources.list.d/php.list && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archive/*.deb

# Install packages
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    postfix postfix-sqlite \
    postfixadmin \
    nginx \
    opendkim opendkim-tools \
    dovecot-core dovecot-imapd dovecot-sqlite dovecot-pop3d \
    php-fpm php-cli php7.0-mbstring php7.0-imap php7.0-sqlite3 \
    && rm -rf /var/spool/postfix \
    && ln -s /var/mail/postfix/spool /var/spool/postfix \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

# Install debug packages // remove in prod
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    procps \
    nano \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

#SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY config/start.sh /usr/local/bin/

#RUN ln -s /srv/postfixadmin/public /var/www/html/postfixadmin
#RUN mkdir /srv/postfixadmin
#RUN mkdir /srv/postfixadmin/database
#RUN touch /srv/postfixadmin/database/postfixadmin.db
#RUN chown -R www-data:www-data /srv/postfixadmin/database

EXPOSE 25 143 465 587 993 4190 11334 80

CMD ["start.sh"]