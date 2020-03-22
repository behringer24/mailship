dbpath = /etc/postfix/sqlite/postfixadmin.db
query = SELECT username AS allowedUser FROM mailbox WHERE username='%s' AND active = 1 UNION SELECT goto FROM alias WHERE address='%s' AND active = 1