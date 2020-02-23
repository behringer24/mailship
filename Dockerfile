FROM debian:10-slim

LABEL description "Simple mailserver in a mono Docker image" \
      maintainer "behringer24 <abe@activecube.de>"

ARG DEBIAN_FRONTEND=noninteractive
ARG SQLITE_PATH=/srv/postfixadmin/database

ENV POSTFIXADMIN_DB_TYPE=sqlite \
    POSTFIXADMIN_DB_HOST=/etc/postfix/sqlite/postfixadmin.db \
    POSTFIXADMIN_DB_USER=user \
    POSTFIXADMIN_DB_PASSWORD=topsecret \
    POSTFIXADMIN_DB_NAME=postfixadmin

# Set PHP install sources
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates apt-transport-https wget gnupg2 \
    && wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add - \
    && echo "deb https://packages.sury.org/php/ buster main" | tee /etc/apt/sources.list.d/php.list \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archive/*.deb

# Install packages
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    postfix postfix-sqlite \
    nginx \
    supervisor \
    opendkim opendkim-tools \
    dovecot-core dovecot-imapd dovecot-sqlite dovecot-pop3d \
    php-fpm php-cli php-mbstring php-imap php-sqlite3

# Setup database and path
RUN mkdir /run/php \
    && mkdir /etc/postfix/sqlite \
    && touch /etc/postfix/sqlite/postfixadmin.db \
    && chown -R www-data:www-data /etc/postfix/sqlite \
    && mkdir /var/www/html/templates_c \
    && chown -R www-data:www-data /var/www/html/templates_c \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

# Install postfixadmin
RUN wget -q -O - "https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-3.2.3.tar.gz" \
     | tar -xvzf - -C /var/www/html --strip-components=1

# Install debug packages // remove in prod
RUN apt-get update && apt-get install -y -q \
    procps \
    nano

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY config/entrypoint.sh /usr/local/bin/
COPY config/default /etc/nginx/sites-available
COPY config/supervisord.conf /etc/supervisord.conf
COPY config/config.local.php /var/www/html

EXPOSE 25 143 465 587 993 4190 11334 80

CMD ["/usr/bin/supervisord", "-n"]