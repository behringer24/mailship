FROM debian:10-slim

LABEL description "Simple mailserver in a mono Docker image" \
      maintainer "behringer24 <abe@activecube.de>"

ARG DEBIAN_FRONTEND=noninteractive

ENV SQLITE_PATH=/etc/postfix/sqlite
ENV SQLITE_DB=${SQLITE_PATH}/postfixadmin.db
ENV POSTFIXADMIN_DB_TYPE=sqlite
ENV POSTFIXADMIN_DB_HOST=${SQLITE_DB}
ENV POSTFIXADMIN_DB_USER=user
ENV POSTFIXADMIN_DB_PASSWORD=topsecret
ENV POSTFIXADMIN_DB_NAME=postfixadmin
    
# Set PHP install sources
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates apt-transport-https wget gnupg2 \
    && wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add - \
    && echo "deb https://packages.sury.org/php/ buster main" | tee /etc/apt/sources.list.d/php.list \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archive/*.deb

# Install packages
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    make \
    postfix postfix-sqlite \
    nginx \
    supervisor \
    opendkim opendkim-tools \
    dovecot-core dovecot-imapd dovecot-sqlite dovecot-pop3d dovecot-lmtpd \
    php-fpm php-cli php-mbstring php-imap php-sqlite3 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

# Setup SQLite database and paths
RUN mkdir /run/php \
    && groupadd -g 5000 vmail \
    && useradd -g vmail -u 5000 vmail -d /var/vmail \
    && mkdir /var/vmail \
    && chown vmail:vmail /var/vmail \
    && mkdir ${SQLITE_PATH} \
    && touch ${SQLITE_DB} \
    && chown -R www-data:www-data ${SQLITE_PATH}

# Install postfixadmin from source and extract to docroot
RUN wget -q -O - "https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-3.2.3.tar.gz" \
     | tar -xvzf - -C /var/www/html --strip-components=1 \
    && mkdir /var/www/html/templates_c \
    && chown -R www-data:www-data /var/www/html/templates_c 

# Install envproc config file preprocessor
ADD https://raw.githubusercontent.com/behringer24/envproc/master/envproc /usr/local/bin/
RUN chmod a+x /usr/local/bin/envproc

# Install debug packages // remove in prod
RUN apt-get update && apt-get install -y -q \
    procps \
    nano \
    sqlite3 \
    less

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY config/make/Makefile /root/
COPY config/nginx/default /etc/nginx/sites-available
COPY config/supervisor/supervisord.conf /etc/supervisord.conf
COPY config/postfixadmin/config.local.php /var/www/html/
COPY config/dovecot/* /etc/dovecot/
COPY config/postfix/* /etc/postfix/
COPY config/opendkim/opendkim /etc/default/
COPY config/opendkim/opendkim.conf /etc/
COPY config/opendkim/key.table /etc/opendkim/
COPY config/opendkim/signing.table /etc/opendkim/
COPY config/opendkim/trusted /etc/opendkim/
COPY config/php/* /etc/php/7.4/fpm/pool.d/

VOLUME ["maildir:/var/vmail", "spool_mail:/var/spool/mail", "spool_postfix:/var/spool/postfix", "sqlite:${SQLITE_PATH}"]

EXPOSE 25 143 465 587 993 4190 11334 80

CMD make -C ~ \
    && /usr/bin/supervisord -n
