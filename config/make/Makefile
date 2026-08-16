##
#  Preprocess all makefiles with envproc to replace placeholders with
#  environment variables
#
#  The last step creates missing DKIM keys before supervisord starts. It is
#  prefixed with "-" so that a DKIM problem can never keep the mail server from
#  booting: the container's CMD is "make && supervisord", so a failing recipe
#  line would stop the whole image.
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

	@-sh /usr/local/bin/dkim-sync.sh
