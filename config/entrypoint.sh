#!/bin/sh
php-fpm7.4
service nginx start
service postfix start
service dovecot start

/bin/bash