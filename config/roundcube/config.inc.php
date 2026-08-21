<?php

/*
 * Roundcube configuration for this image.
 *
 * Values that differ per installation come from the environment, which works
 * because config/php/php.conf sets clear_env = no for the FPM pool.
 */

// Written data goes into the /var/lib/roundcube volume, not into the container
// layer: the database has to survive recreating the container, and keeping
// temp and logs beside it stops the writable layer from growing unnoticed.
$config['db_dsnw'] = 'sqlite:///' . (getenv('ROUNDCUBE_DB') ?: '/var/lib/roundcube/roundcube.db') . '?mode=0640';
$config['temp_dir'] = '/var/lib/roundcube/temp';
$config['log_dir']  = '/var/lib/roundcube/logs';

// Dovecot and Postfix run in this very container, so both are reached over the
// loopback interface.
$config['imap_host'] = 'localhost:143';

// Deliberately submission on 587 and not plain 25. Port 25 would accept mail
// from 127.0.0.0/8 through permit_mynetworks without authenticating, and
// Postfix' reject_authenticated_sender_login_mismatch only applies to
// authenticated senders -- a user could then send as any other mailbox on this
// server. Going through submission with the credentials of the logged in user
// makes Postfix enforce that the From address belongs to that account.
$config['smtp_host'] = 'tls://localhost:587';
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';

// Submission demands STARTTLS (smtpd_tls_security_level=encrypt), but the
// certificate is issued for the mail host name while we connect to localhost,
// so verification would always fail. Switching it off is sound here and only
// here: the connection never leaves this container, so there is no position
// from which anyone could intercept it.
$config['smtp_conn_options'] = [
    'ssl' => [
        'verify_peer'      => false,
        'verify_peer_name' => false,
    ],
];

// Encrypts what is stored in the session and, with the identity_switch plugin,
// the passwords of the additional accounts. Generated once into the volume by
// roundcube-init.sh unless ROUNDCUBE_DES_KEY is set, because an empty key would
// silently leave those passwords unprotected.
$des_key = getenv('ROUNDCUBE_DES_KEY');
if (!$des_key && is_readable('/var/lib/roundcube/des_key')) {
    $des_key = trim(file_get_contents('/var/lib/roundcube/des_key'));
}
$config['des_key'] = $des_key;

// Lets a user reach their other mailboxes on this server without logging out.
// The plugin ships its own defaults.inc.php, so no separate config is needed.
$config['plugins'] = ['identity_switch'];

// identity_switch supports the Elastic skin only. It is the default in 1.7, but
// spelled out so a future default change cannot break the account switcher.
$config['skin'] = 'elastic';

$config['product_name'] = getenv('ROUNDCUBE_PRODUCT_NAME') ?: 'Webmail';

// The web installer is removed from the image, this only closes the door twice.
$config['enable_installer'] = false;

// TLS is terminated by the reverse proxy, so PHP would not recognise the
// connection as secure on its own. nginx derives HTTPS from X-Forwarded-Proto
// (see config/nginx/default), which is why Roundcube's own use_https is not
// needed here. force_https has to stay off: it would redirect and, behind a
// proxy that already serves HTTPS, produce a redirect loop.
$config['force_https'] = false;
