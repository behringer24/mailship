maillog_file = /dev/stdout

import_environment = MAIL_CONFIG MAIL_DEBUG MAIL_LOGTAG TZ XAUTHORITY DISPLAY LANG=C POSTLOG_SERVICE POSTLOG_HOSTNAME POSTFIXADMIN_DB_TYPE SQLITE_DB SSL_CERT SSL_KEY POSTMASTER_ADDRESS
export_environment = TZ MAIL_CONFIG LANG POSTFIXADMIN_DB_TYPE SQLITE_DB SSL_CERT SSL_KEY POSTMASTER_ADDRESS

disable_vrfy_command = yes

virtual_mailbox_domains = ${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_virtual_domains_maps.cf
virtual_alias_maps =  ${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_virtual_alias_maps.cf, ${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_virtual_alias_domain_maps.cf, ${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_virtual_alias_domain_catchall_maps.cf
virtual_mailbox_maps = ${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_virtual_mailbox_maps.cf, ${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_virtual_alias_domain_mailbox_maps.cf
virtual_mailbox_base = /var/vmail/
virtual_mailbox_limit = 124000000
virtual_minimum_uid = 104
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
virtual_transport = dovecot

smtpd_tls_cert_file = ${env:SSL_CERT}
smtpd_tls_key_file = ${env:SSL_KEY}
smtpd_use_tls = yes
smtpd_tls_auth_only = yes

smtp_tls_security_level = may

smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth_dovecot
smtpd_sasl_auth_enable = yes
smtpd_sasl_authenticated_header = yes
smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination
smtpd_sender_restrictions = reject_authenticated_sender_login_mismatch, reject_unknown_sender_domain
smtpd_sender_login_maps = proxy:${env:POSTFIXADMIN_DB_TYPE}:/etc/postfix/sqlite_sender_login_maps.cf
broken_sasl_auth_clients = yes

myorigin = ${env:MAIL_HOST}
mydestination = ${env:MAIL_HOST}, $myhostname, localhost.$mydomain, localhost
mynetworks = 127.0.0.0/8
inet_protocols = ipv4

dovecot_destination_recipient_limit = 1