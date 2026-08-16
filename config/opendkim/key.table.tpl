# Single, domain independent key record.
#
# OpenDKIM replaces a "%" in the domain field and in the key path with the
# apparent domain of the sender, so this one line covers every domain that has
# a key file below /etc/opendkim/keys/. dkim-sync.sh creates those key files;
# nothing here has to be rewritten when a domain is added or removed.
#
# Domains without a key file simply stay unsigned (see On-KeyNotFound in
# /etc/opendkim.conf) instead of failing.
dkim %:${env:DKIM_SELECTOR}:/etc/opendkim/keys/%/${env:DKIM_SELECTOR}.private
