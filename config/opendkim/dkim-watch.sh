#!/bin/sh
#
# Reconcile DKIM keys with the domains configured in Postfixadmin, so that a
# domain added through the web interface gets a key without anyone having to
# touch docker-compose.yml or restart the container.
#
# Started by supervisord. The initial delay gives Postfix time to come up,
# because dkim-sync.sh mails the postmaster about missing DNS records.

set -u

sleep "${DKIM_WATCH_DELAY:-60}"

while true; do
	sh /usr/local/bin/dkim-sync.sh --notify
	sleep "${DKIM_CHECK_INTERVAL:-300}"
done
