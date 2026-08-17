FROM debian:12-slim

LABEL description "Simple mailserver in a mono Docker image" \
      maintainer "behringer24 <abe@activecube.de>"

ARG DEBIAN_FRONTEND=noninteractive

# Set early on purpose: several RUN steps below pipe a download into tar, and
# without pipefail a failed download would be masked by tar's exit status and
# silently produce a broken image.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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

# Roundcube. ROUNDCUBE_DES_KEY encrypts session contents and, through the
# identity_switch plugin, the passwords of a user's additional accounts. Left
# empty it is generated once into the volume by roundcube-init.sh, so that an
# unset variable cannot silently leave those passwords unprotected.
ENV ROUNDCUBE_VERSION=1.7.3
ENV IDENTITY_SWITCH_VERSION=3.0.13
ENV ROUNDCUBE_DB=/var/lib/roundcube/roundcube.db
ENV ROUNDCUBE_DES_KEY=""
ENV ROUNDCUBE_PRODUCT_NAME=Webmail

# Install packages
RUN apt-get update && apt-get install -y -q --no-install-recommends \
    ca-certificates wget \
    make \
    postfix postfix-sqlite \
    nginx \
    supervisor \
    opendkim opendkim-tools dns-root-data dnsutils \
    sqlite3 \
    dovecot-core dovecot-imapd dovecot-sqlite dovecot-pop3d dovecot-lmtpd \
    php8.2-fpm php8.2-cli php8.2-mbstring php8.2-imap php8.2-sqlite3 \
    php8.2-xml php8.2-intl php8.2-zip php8.2-gd \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/cache/debconf/*-old

# Setup SQLite database and paths
RUN mkdir -p /run/php \
    && groupadd -g 5000 vmail \
    && useradd -g vmail -u 5000 vmail -d /var/vmail \
    && mkdir /var/vmail \
    && chown vmail:vmail /var/vmail \
    && mkdir ${SQLITE_PATH} \
    && touch ${SQLITE_DB} \
    && chown -R www-data:www-data ${SQLITE_PATH}

# Install postfixadmin from source and extract to docroot.
#
# Stays on the 3.3 branch: it supports PHP 7.0 up to 8.x and its source archive
# runs without a composer install, which is why no composer is needed in this
# image. The 4.0 branch ships PHP-version-specific release tarballs with a
# prebuilt vendor/ instead, and its database upgrade is known to be inconsistent
# with the 3.3 branch (postfixadmin issue #971), so moving to it is a separate
# decision, not part of the Debian bump.
RUN wget -q -O - "https://github.com/postfixadmin/postfixadmin/archive/refs/tags/postfixadmin-3.3.16.tar.gz" \
     | tar -xzf - -C /var/www/html --strip-components=1 \
    && mkdir /var/www/html/templates_c \
    && chown -R www-data:www-data /var/www/html/templates_c 

# Install Roundcube webmail.
#
# The "complete" tarball carries its vendor directory, so no composer is needed
# here. Only public_html is served -- config, temp, logs and vendor are its
# siblings and therefore out of reach from the web by construction, which is why
# no deny rules for them appear in the nginx config.
#
# installer.php is deleted rather than merely disabled through
# enable_installer: a file that is not there cannot be reached at all.
#
# php8.2-xml supplies dom and xmlwriter, php8.2-intl the required intl, zip is
# recommended and gd optional (thumbnails and the QR code for two factor setup).
# ext-curl is deliberately absent: it is not in Roundcube's requirements, and
# guzzle falls back to PHP streams.
RUN mkdir -p /var/www/webmail \
    && wget -qO- "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz" \
     | tar -xzf - -C /var/www/webmail --strip-components=1 \
    && rm -f /var/www/webmail/public_html/installer.php \
    && rm -rf /var/www/webmail/installer \
    && mkdir -p /var/www/webmail/plugins/identity_switch \
    && wget -qO- "https://github.com/toteph42/identity_switch/archive/refs/tags/${IDENTITY_SWITCH_VERSION}.tar.gz" \
     | tar -xzf - -C /var/www/webmail/plugins/identity_switch --strip-components=1 \
    && mkdir -p /var/lib/roundcube \
    && chown -R www-data:www-data /var/lib/roundcube

# Install the envproc config file preprocessor, in its Go flavour
# (behringer24/envprocgo). The original Python envproc starts with
# "/usr/bin/env python", and Debian 12 has no "python" executable any more:
# supervisor pulls in python3 only, so the templates would fail to render and
# the container would not boot. The Go port is a single static binary with the
# same ${env:VAR} syntax and the same abort on an unset variable, which means
# the templates themselves stay untouched.
#
# Upstream publishes linux-386 and linux-amd64 only. That is fine as long as
# .github/workflows/docker-image.yml builds for a single architecture; adding
# another platform there means revisiting this line.
ARG ENVPROC_VERSION=v1.0.7
RUN wget -qO- "https://github.com/behringer24/envprocgo/releases/download/${ENVPROC_VERSION}/envproc-${ENVPROC_VERSION}-linux-amd64.tar.gz" \
     | tar -xzf - -C /usr/local/bin envproc \
    && chmod a+x /usr/local/bin/envproc

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
COPY config/php/* /etc/php/8.2/fpm/pool.d/
COPY config/roundcube/config.inc.php /var/www/webmail/config/
COPY config/roundcube/roundcube-init.sh /usr/local/bin/

# The Debian package does not create the key directory, and /var/run/opendkim is
# normally set up by systemd-tmpfiles, which does not run here -- without it
# opendkim cannot write the PidFile from opendkim.conf.
RUN chmod a+x /usr/local/bin/dkim-sync.sh /usr/local/bin/dkim-watch.sh /usr/local/bin/roundcube-init.sh \
    && mkdir -p /etc/opendkim/keys /var/run/opendkim \
    && chown -R opendkim:opendkim /etc/opendkim /var/run/opendkim \
    && chmod 0700 /etc/opendkim/keys

VOLUME ["/var/vmail", "/var/spool/mail", "/var/spool/postfix", "${SQLITE_PATH}", "/var/lib/roundcube"]

EXPOSE 25 143 465 587 993 4190 11334 80

CMD make -C ~ \
    && /usr/bin/supervisord -n
