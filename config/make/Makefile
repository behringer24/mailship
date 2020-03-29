##
#  Preprocess all makefiles with envproc to replace placeholders with
#  environment variables
##

config:
	envproc /etc/dovecot/dovecot.conf.tpl /etc/dovecot/dovecot.conf
	envproc /etc/dovecot/dovecot-sql.conf.tpl /etc/dovecot/dovecot-sql.conf

	envproc /etc/postfix/sqlite_sender_login_maps.cf.tpl /etc/postfix/sqlite_sender_login_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_domain_catchall_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_domain_catchall_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_domain_mailbox_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_domain_mailbox_maps.cf
	envproc /etc/postfix/sqlite_virtual_alias_domain_maps.cf.tpl /etc/postfix/sqlite_virtual_alias_domain_maps.cf
	envproc /etc/postfix/sqlite_virtual_domains_maps.cf.tpl /etc/postfix/sqlite_virtual_domains_maps.cf
	envproc /etc/postfix/sqlite_virtual_mailbox_maps.cf.tpl /etc/postfix/sqlite_virtual_mailbox_maps.cf
