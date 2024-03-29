# 2.3.4.1 (f79e8e7e4): /etc/dovecot/dovecot.conf
# Pigeonhole version 0.5.4 ()
# OS: Linux 4.19.76-linuxkit x86_64 Debian 10.2
# Hostname: 53941c6a59af

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

# If you are having problems, try uncommenting these:
auth_debug = yes
auth_debug_passwords = yes
auth_verbose = yes
auth_verbose_passwords = plain
verbose_ssl = yes
disable_plaintext_auth = no

mail_location = maildir:/var/vmail/%d/%n
