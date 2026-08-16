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

# OpenDKIM. DKIM_DOMAINS adds domains on top of the ones discovered in the
# Postfixadmin database, for example the host name in MAIL_HOST.
# DKIM_SELECTOR and DKIM_MILTER are referenced from templates and must always be
# defined, because envproc aborts on an unknown variable and the container would
# not start. The others are only read by the shell.
ENV DKIM_DOMAINS=""
ENV DKIM_SELECTOR=mail
ENV DKIM_KEY_SIZE=2048
ENV DKIM_MILTER=inet:127.0.0.1:12345
ENV DKIM_AUTODISCOVER=true
ENV DKIM_CHECK_INTERVAL=300
ENV DKIM_NOTIFY_INTERVAL=86400

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
    opendkim opendkim-tools dns-root-data dnsutils \
    sqlite3 \
    dovecot-core dovecot-imapd dovecot-sqlite dovecot-pop3d dovecot-lmtpd \
    php7.4-fpm php7.4-cli php7.4-mbstring php7.4-imap php7.4-sqlite3 \
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
RUN wget -q -O - "https://github.com/postfixadmin/postfixadmin/archive/refs/tags/postfixadmin-3.3.10.tar.gz" \
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
COPY config/opendkim/key.table.tpl /etc/opendkim/
COPY config/opendkim/signing.table /etc/opendkim/
COPY config/opendkim/trusted /etc/opendkim/
COPY config/opendkim/dkim-sync.sh config/opendkim/dkim-watch.sh /usr/local/bin/
COPY config/php/* /etc/php/7.4/fpm/pool.d/

# The Debian package does not create the key directory, and /var/run/opendkim is
# normally set up by systemd-tmpfiles, which does not run here -- without it
# opendkim cannot write the PidFile from opendkim.conf.
RUN chmod a+x /usr/local/bin/dkim-sync.sh /usr/local/bin/dkim-watch.sh \
    && mkdir -p /etc/opendkim/keys /var/run/opendkim \
    && chown -R opendkim:opendkim /etc/opendkim /var/run/opendkim \
    && chmod 0700 /etc/opendkim/keys

VOLUME ["/var/vmail", "/var/spool/mail", "/var/spool/postfix", "${SQLITE_PATH}"]

EXPOSE 25 143 465 587 993 4190 11334 80

CMD make -C ~ \
    && /usr/bin/supervisord -n
