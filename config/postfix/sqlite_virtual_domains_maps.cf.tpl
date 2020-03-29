dbpath = /etc/postfix/sqlite/postfixadmin.db
query = SELECT domain FROM domain WHERE domain='%s' AND active = '1'