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
#  Then prepare Roundcube's writable side -- database schema, des_key, temp and
#  log directories -- which lives in a volume and can therefore not be done at
#  build time. The script is idempotent and only fixes ownership on an existing
#  installation.
#
#  The last steps create missing DKIM keys before supervisord starts. The
#  permission fix, the Roundcube step and the DKIM step are all prefixed with
#  "-" so that none of them can keep the mail server from booting: the
#  container's CMD is "make && supervisord", so a failing recipe line would stop
#  the whole image. A webmailer that fails to initialise must not take mail
#  delivery down with it. Errors are still printed.
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

	-sh /usr/local/bin/roundcube-init.sh

	@-sh /usr/local/bin/dkim-sync.sh
