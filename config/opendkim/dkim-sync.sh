#!/bin/sh
#
# dkim-sync.sh [--notify]
#
# Keeps the OpenDKIM key files in sync with the domains this server handles and
# reports which DNS records still have to be published.
#
# Domains come from two sources, which are merged:
#   * $DKIM_DOMAINS          -- extra domains, e.g. the value of MAIL_HOST,
#                               which is not a virtual domain in Postfixadmin
#   * the Postfixadmin database, unless DKIM_AUTODISCOVER is turned off
#
# The OpenDKIM tables themselves are static and domain independent (see
# key.table.tpl), so a new domain only needs a key file -- no table rewrite and
# no reload. OpenDKIM does cache key material though, so it is restarted after a
# key was created.
#
# Called twice: once from the Makefile at container start (before supervisord,
# so no restart and no mail is possible yet) and then periodically by
# dkim-watch.sh with --notify.
#
# This script must never exit non-zero: the Makefile runs before supervisord and
# a DKIM problem must not stop the mail server from starting.

set -u

DKIM_DIR=/etc/opendkim
KEY_DIR="$DKIM_DIR/keys"
RECORDS="$KEY_DIR/dns-records.txt"
STAMP_DIR="$KEY_DIR/.notified"
SUPERVISOR_SOCK=/var/run/supervisor.sock

SELECTOR=${DKIM_SELECTOR:-mail}
KEY_SIZE=${DKIM_KEY_SIZE:-2048}
AUTODISCOVER=${DKIM_AUTODISCOVER:-true}
NOTIFY_INTERVAL=${DKIM_NOTIFY_INTERVAL:-86400}
POSTMASTER=${POSTMASTER_ADDRESS:-}
DB=${SQLITE_DB:-/etc/postfix/sqlite/postfixadmin.db}

NOTIFY=no
[ "${1:-}" = "--notify" ] && NOTIFY=yes

log() { echo "dkim-sync: $*"; }

##
#  Collect the domains to sign for.
##
collect_domains() {
	printf '%s\n' ${DKIM_DOMAINS:-}

	# The "ALL" row is a Postfixadmin pseudo domain for superadmins.
	if [ "$AUTODISCOVER" = "true" ] && command -v sqlite3 >/dev/null 2>&1 && [ -r "$DB" ]; then
		sqlite3 "$DB" \
			"SELECT domain FROM domain WHERE active = '1' AND domain <> 'ALL';" \
			2>/dev/null
	fi
}

##
#  Reject anything that is not a plain fully qualified domain name, so that a
#  stray "/" or ".." can never escape $KEY_DIR.
##
valid_domain() {
	case "$1" in
		*[!a-z0-9.-]*) return 1 ;;
		.*|-*|*.|*-)   return 1 ;;
		*..*)          return 1 ;;
		*.*)           return 0 ;;
		*)             return 1 ;;
	esac
}

##
#  Print the base64 public key belonging to a private key. Derived from the key
#  itself rather than parsing opendkim-genkey's .txt output, so it also works
#  for keys that were imported by hand.
##
public_key() {
	openssl rsa -in "$1" -pubout -outform PEM 2>/dev/null \
		| sed '/-----/d' | tr -d '\n'
}

##
#  Is the matching TXT record live in DNS?
#
#  Compares the published p= value against the local key instead of relying on
#  the exit status of opendkim-testkey, which also fails for perfectly good
#  records in zones that are not DNSSEC signed ("key not secure").
#
#  Stripping quotes and spaces also reassembles records that DNS splits into
#  several character strings, which every 2048 bit key is.
##
is_published() {
	_name="${SELECTOR}._domainkey.$1"
	command -v dig >/dev/null 2>&1 || return 0
	dig +short TXT "$_name" 2>/dev/null | tr -d '" ' | grep -qF "p=$2"
}

##
#  Rate limited mail to the postmaster. One reminder per domain per
#  $DKIM_NOTIFY_INTERVAL seconds.
##
notify() {
	_domain=$1
	_record=$2
	_stamp="$STAMP_DIR/$_domain"

	[ "$NOTIFY" = yes ] || return 0
	[ -n "$POSTMASTER" ] || return 0
	command -v sendmail >/dev/null 2>&1 || return 0

	if [ -f "$_stamp" ]; then
		_age=$(( $(date +%s) - $(stat -c %Y "$_stamp" 2>/dev/null || echo 0) ))
		[ "$_age" -lt "$NOTIFY_INTERVAL" ] && return 0
	fi

	mkdir -p "$STAMP_DIR" 2>/dev/null
	sendmail -t <<-EOF 2>/dev/null && : > "$_stamp"
		To: $POSTMASTER
		Subject: [mailship] DKIM record missing for $_domain
		Content-Type: text/plain; charset=utf-8

		Mail from $_domain is not DKIM signed yet, because this TXT record is
		not published or does not match the local key:

		  Name:  ${SELECTOR}._domainkey.$_domain
		  Type:  TXT
		  Value: $_record

		Publish it at your DNS provider, then verify with:

		  opendkim-testkey -d $_domain -s $SELECTOR -vvv

		This reminder repeats about every $NOTIFY_INTERVAL seconds until the
		record resolves correctly.
	EOF
}

##
#  Main
##
DOMAINS=$(collect_domains | tr ',;' '\n\n' | tr 'A-Z' 'a-z' | tr -d ' \t\r' | sort -u)

if [ -z "$DOMAINS" ]; then
	log "no domains configured (DKIM_DOMAINS empty, no active Postfixadmin domains) -- nothing to do."
	exit 0
fi

if ! mkdir -p "$KEY_DIR" 2>/dev/null; then
	log "ERROR: cannot create $KEY_DIR -- skipping."
	exit 0
fi

created=no
pending=""
: > "$RECORDS.new"

for d in $DOMAINS; do
	if ! valid_domain "$d"; then
		log "WARNING: '$d' is not a valid domain name -- ignored."
		continue
	fi

	dir="$KEY_DIR/$d"
	key="$dir/$SELECTOR.private"

	if [ ! -f "$key" ]; then
		if ! mkdir -p "$dir" 2>/dev/null; then
			log "ERROR: cannot create $dir -- skipping $d."
			continue
		fi
		if opendkim-genkey -b "$KEY_SIZE" -s "$SELECTOR" -d "$d" -D "$dir" 2>&1; then
			log "created a new $KEY_SIZE bit key for $d (selector '$SELECTOR')."
			created=yes
		else
			log "ERROR: opendkim-genkey failed for $d -- skipping."
			continue
		fi
	fi

	pub=$(public_key "$key")
	if [ -z "$pub" ]; then
		log "WARNING: cannot derive the public key for $d, see $dir/$SELECTOR.txt"
		continue
	fi
	record="v=DKIM1; h=sha256; k=rsa; p=$pub"

	printf '%s._domainkey.%s\tIN\tTXT\t"%s"\n' "$SELECTOR" "$d" "$record" >> "$RECORDS.new"

	is_published "$d" "$pub" && continue

	pending="$pending $d"
	notify "$d" "$record"
done

mv -f "$RECORDS.new" "$RECORDS" 2>/dev/null || rm -f "$RECORDS.new"

# OpenDKIM drops privileges to uid opendkim and has to read the keys. The tables
# in $DKIM_DIR must stay readable for it -- a blanket umask here would silently
# stop all signing.
chown -R opendkim:opendkim "$KEY_DIR" 2>/dev/null
chmod 0700 "$KEY_DIR" 2>/dev/null
find "$KEY_DIR" -name "*.private" -exec chmod 0600 {} + 2>/dev/null

if [ -n "$pending" ]; then
	echo "=================================================================="
	echo " OpenDKIM: publish these TXT records at your DNS provider."
	echo " Missing or mismatched:$pending"
	echo "------------------------------------------------------------------"
	cat "$RECORDS" 2>/dev/null
	echo "------------------------------------------------------------------"
	echo " Verify with: opendkim-testkey -d <domain> -s $SELECTOR -vvv"
	echo " Note: in a zone with a wildcard TXT record the lookup returns the"
	echo " wildcard value instead of NXDOMAIN, so errors reported there can be"
	echo " misleading until the explicit record exists."
	echo "=================================================================="
fi

# Key material is cached by the running daemon, so pick up newly created keys.
# During the Makefile run supervisord is not up yet and this is skipped.
if [ "$created" = yes ] && [ -S "$SUPERVISOR_SOCK" ]; then
	log "restarting opendkim to pick up the new key(s)."
	supervisorctl restart opendkim >/dev/null 2>&1 \
		|| log "WARNING: could not restart opendkim via supervisorctl."
fi

exit 0
