#!/bin/sh
#
# cert-watch.sh
#
# Reloads Dovecot and Postfix when the certificate or key behind $SSL_CERT and
# $SSL_KEY changes on disk.
#
# Both daemons read these files only when they start or reload. Behind
# nginx-proxy/acme-companion the certificate is renewed in place about every
# 60 days while the container keeps running, so without a reload Dovecot goes
# on presenting the old certificate until it expires. IMAP and POP3 clients
# then fail, while the web interface -- TLS terminated by the proxy -- still
# looks fine, which makes it easy to miss. Postfix would pick the new files up
# by itself as smtpd processes are recycled, but is reloaded as well so that
# both switch at the same moment.
#
# Polls a checksum instead of using inotify: acme-companion's files are
# symlinks into a per-domain directory on a volume that is mounted read-only
# here, and whether a renewal replaces the link target or rewrites it in place
# is an implementation detail of acme.sh. Reading through the symlink catches
# both.
#
# A renewal writes key and certificate one after the other. A change is
# therefore only acted on once both files have stopped changing and belong
# together -- reloading with a mismatched pair would break the TLS handshake
# for every new connection, which is worse than serving the old certificate a
# little longer.
#
# Started by supervisord after Dovecot and Postfix. Exits 0, and supervisord
# leaves it stopped, if SSL_CERT or SSL_KEY are not set.

set -u

CERT=${SSL_CERT:-}
KEY=${SSL_KEY:-}
INTERVAL=${CERT_CHECK_INTERVAL:-900}
SETTLE=${CERT_SETTLE_DELAY:-30}

log() { echo "cert-watch: $*"; }

##
#  Checksum over certificate and key, read through any symlink. Fails if one
#  of them cannot be read, so that a missing file is never mistaken for a
#  change.
##
fingerprint() {
	[ -r "$CERT" ] && [ -r "$KEY" ] || return 1
	cat "$CERT" "$KEY" | sha256sum | cut -d' ' -f1
}

##
#  Do certificate and key belong together? Compares the public keys, which
#  works for RSA and EC keys alike. For a full chain file openssl reads the
#  first certificate, which is the server's own.
##
pair_ok() {
	_cert_pub=$(openssl x509 -in "$CERT" -noout -pubkey 2>/dev/null) || return 1
	_key_pub=$(openssl pkey -in "$KEY" -pubout 2>/dev/null) || return 1
	[ -n "$_cert_pub" ] && [ "$_cert_pub" = "$_key_pub" ]
}

##
#  Reload both daemons. Existing connections keep their session, new ones get
#  the new certificate. Fails if either reload failed, so that the change is
#  tried again on the next round.
##
reload_daemons() {
	_ok=yes
	if doveadm reload >/dev/null 2>&1; then
		log "dovecot reloaded."
	else
		log "WARNING: 'doveadm reload' failed."
		_ok=no
	fi
	if postfix -c /etc/postfix reload >/dev/null 2>&1; then
		log "postfix reloaded."
	else
		log "WARNING: 'postfix reload' failed."
		_ok=no
	fi
	[ "$_ok" = yes ]
}

##
#  Main
##
if [ -z "$CERT" ] || [ -z "$KEY" ]; then
	log "SSL_CERT or SSL_KEY is not set -- nothing to watch."
	exit 0
fi

# The daemons have just loaded whatever is on disk now, so this is the
# baseline. If the files are not readable yet, the first readable state counts
# as a change and triggers a reload.
current=$(fingerprint) || current=""
[ -n "$current" ] || log "WARNING: cannot read $CERT or $KEY -- will keep checking."
log "watching $CERT and $KEY every ${INTERVAL}s."

while true; do
	sleep "$INTERVAL"

	new=$(fingerprint) || continue
	[ "$new" = "$current" ] && continue

	# Give a renewal in progress time to finish writing both files. Still
	# changing after that means: look again on the next round.
	sleep "$SETTLE"
	settled=$(fingerprint) || continue
	[ "$settled" = "$new" ] || continue

	if ! pair_ok; then
		log "WARNING: $CERT and $KEY have changed but do not belong together -- not reloading, checking again in ${INTERVAL}s."
		continue
	fi

	valid_until=$(openssl x509 -in "$CERT" -noout -enddate 2>/dev/null | cut -d= -f2)
	log "certificate changed (valid until ${valid_until:-unknown}) -- reloading dovecot and postfix."
	reload_daemons && current=$settled
done
