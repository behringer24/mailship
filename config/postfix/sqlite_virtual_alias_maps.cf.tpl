dbpath = /etc/postfix/sqlite/postfixadmin.db
query = SELECT goto FROM alias WHERE address='%s' AND active = '1'