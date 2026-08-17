##
#  Preprocess all makefiles with envproc to replace placeholders with
#  environment variables
#
#  Then repair the ownership of Postfix' local submission directories. They live
#  in a volume, and group ownership is stored numerically: a volume created
#  under an older Debian carries a group id that maps to a different name here,
#  typically "postfix" instead of "postdrop". The setgid postdrop binary then
#  cannot write, and every locally injected mail fails -- DKIM notifications and
#  cron mail, while SMTP from outside keeps working, which makes it easy to
#  miss. The chmod after the chgrp is required, not cosmetic: changing the group
#  clears the sticky and setgid bits these two directories depend on.
#
#  "postfix set-permissions" would be the obvious tool and is deliberately not
#  used: it also chowns manual pages, which this slim image does not ship, and
#  aborts there.
#
#  The last steps create missing DKIM keys before supervisord starts. Both the
#  permission fix and the DKIM step are prefixed with "-" so that neither can
#  keep the mail server from booting: the container's CMD is
#  "make && supervisord", so a failing recipe line would stop the whole image.
#  Errors are still printed.
##

config:
	envproc /etc/dovecot/dovecot.conf.tpl /etc/dovecot/dovecot.conf
	envproc /etc/dovecot/dovecot-sql.conf.tpl /etc/dovecot/dovecot-sql.conf

	envproc /etc/postfix/main.cf.tpl /etc/postfix/main.cf
	envproc /etc/postfix/sqlite_sender_login_maps.cf.tpl /etc/postfix/sqlite_sender_login_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_domain_catchall_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_domain_catchall_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_domain_mailbox_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_domain_mailbox_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_domain_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_domain_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_maps.cf
	envproc /etc/postfix/sqlite_virtual_domains_maps.cf.tpl /etc/postfix/sqlite_virtual_domains_maps.cf
	envproc /etc/postfix/sqlite_virtual_mailbox_maps.cf.tpl /etc/postfix/sqlite_virtual_mailbox_maps.cf

	envproc /etc/opendkim/key.table.tpl /etc/opendkim/key.table

	-chgrp postdrop /var/spool/postfix/maildrop /var/spool/postfix/public
	-chmod 1730 /var/spool/postfix/maildrop
	-chmod 2710 /var/spool/postfix/public

	@-sh /usr/local/bin/dkim-sync.sh
