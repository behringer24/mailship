<?php
$CONF['database_type'] = getenv('POSTFIXADMIN_DB_TYPE');
$CONF['database_name'] = getenv('POSTFIXADMIN_DB_HOST');

$CONF['setup_password'] = getenv('POSTFIXADMIN_SETUP_PASSWORD');

$CONF['configured'] = getenv('POSTFIXADMIN_SETUP_PASSWORD') != '';