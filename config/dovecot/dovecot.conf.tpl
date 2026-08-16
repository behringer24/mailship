# Template for /etc/dovecot/dovecot.conf, rendered by envproc at container start
# (see /root/Makefile). Written for the Dovecot 2.3 series as shipped by Debian
# 12. Dovecot 2.4 rejects this syntax outright and needs a rewritten config.

auth_mechanisms = plain login
log_timestamp = "%Y-%m-%d %H:%M:%S "

passdb {
  args = /etc/dovecot/dovecot-sql.conf
  driver = sql
}

protocols = imap pop3

service auth {
  unix_listener /var/spool/postfix/private/auth_dovecot {
    group = postfix
    mode = 0660
    user = postfix
  }
  unix_listener auth-master {
    mode = 0600
    user = vmail
  }
  user = root
}

ssl = yes
ssl_cert = <${env:SSL_CERT}
ssl_key = <${env:SSL_KEY}

userdb {
  args = /etc/dovecot/dovecot-sql.conf
  driver = sql
}

protocol pop3 {
  pop3_uidl_format = %08Xu%08Xv
}

protocol lda {
  auth_socket_path = /var/run/dovecot/auth-master
  postmaster_address = ${env:POSTMASTER_ADDRESS}
}

log_path = /dev/stderr

# auth_verbose logs failed logins with the user name, which is what is actually
# useful when debugging. The *_passwords settings below it must stay off: they
# write the submitted password in clear text to stderr and therefore into the
# container logs, for every single login. Turn them on temporarily and never in
# production.
auth_verbose = yes
#auth_debug = yes
#auth_debug_passwords = yes
#auth_verbose_passwords = plain
#verbose_ssl = yes

# Dovecot listens on 143 inside the container without TLS, so that local clients
# (and Postfix SASL) can authenticate over the loopback interface. Anything
# reaching the container from outside arrives on 993/465/587.
disable_plaintext_auth = no

mail_location = maildir:/var/vmail/%d/%n
