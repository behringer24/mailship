#!/bin/sh
#
# Prepares the writable side of Roundcube before supervisord starts.
#
# Everything here lives in the /var/lib/roundcube volume and therefore cannot be
# done at build time. The script is idempotent: on an existing installation it
# only fixes ownership and exits.

set -eu

DB="${ROUNDCUBE_DB:-/var/lib/roundcube/roundcube.db}"
DIR="$(dirname "$DB")"
WEBMAIL=/var/www/webmail

mkdir -p "$DIR/temp" "$DIR/logs"

# The des_key encrypts session contents and, through identity_switch, the
# passwords of a user's additional accounts. An empty key would leave those
# unprotected without any visible error, so generate one rather than start
# without. ROUNDCUBE_DES_KEY takes precedence when set, which lets the key be
# managed outside the volume.
if [ -z "${ROUNDCUBE_DES_KEY:-}" ] && [ ! -s "$DIR/des_key" ]; then
    openssl rand -base64 24 | tr -d '\n' > "$DIR/des_key"
    chmod 0640 "$DIR/des_key"
    echo "roundcube-init: generated a des_key in $DIR/des_key"
fi

# "Has a schema" rather than "file exists": Postfixadmin's pattern of touching
# the database file means an empty file is a real possibility, and feeding the
# initial schema into a populated database would fail on existing tables.
if ! sqlite3 "$DB" ".tables" 2>/dev/null | grep -q users; then
    echo "roundcube-init: creating the database schema in $DB"
    sqlite3 "$DB" < "$WEBMAIL/SQL/sqlite.initial.sql"
    # Adds identity_switch's column to the identities table. Only ever on a
    # fresh database -- ALTER TABLE ADD COLUMN fails if the column is there.
    sqlite3 "$DB" < "$WEBMAIL/plugins/identity_switch/SQL/sqlite.initial.sql"
fi

chown -R www-data:www-data "$DIR"
chmod 0640 "$DB"
