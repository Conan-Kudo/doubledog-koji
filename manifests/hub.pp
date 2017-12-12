# == Class: koji::hub
#
# Manages the Koji Hub component on a host.
#
# === Authors
#
#   John Florian <jflorian@doubledog.org>
#
# === Copyright
#
# Copyright 2016-2017 John Florian


class koji::hub (
        String[1]           $client_ca_cert,
        String[1]           $db_host,
        String[1]           $db_passwd,
        String[1]           $db_user,
        String[1]           $hub_ca_cert,
        String[1]           $hub_cert,
        String[1]           $hub_key,
        String[1]           $top_dir,
        Array[String[1], 1] $packages,
        Array[String[1]]    $proxy_auth_dns,
        Boolean             $debug,
        String[1]           $email_domain,
        Array[String[1]]    $plugins,
        Enum['normal', 'extended', 'message'] $traceback,
    ) {

    package { $packages:
        ensure  => installed,
    }

    include '::koji::httpd'

    ::apache::module_config {
        '99-prefork':
            source => 'puppet:///modules/koji/httpd/99-prefork.conf',
            ;
        '99-worker':
            source => 'puppet:///modules/koji/httpd/99-worker.conf',
            ;
    }

    ::apache::site_config {
        'kojihub':
            content   => template('koji/hub/kojihub.conf'),
            subscribe => Package[$packages],
            ;
    }

    # The CA certificates are correct to use openssl::tls_certificate instead
    # of openssl::tls_ca_certificate because they don't need to be general
    # trust anchors.
    ::openssl::tls_certificate {
        default:
            notify => Class['::apache::service'],
            ;
        'koji-client-ca-chain':
            cert_source => $client_ca_cert,
            ;
        'koji-hub-ca-chain':
            cert_source => $hub_ca_cert,
            ;
        'koji-hub':
            cert_source => $hub_cert,
            key_source  => $hub_key,
            ;
    }

    file {
        default:
            owner     => 'root',
            group     => 'root',
            mode      => '0644',
            seluser   => 'system_u',
            selrole   => 'object_r',
            seltype   => 'etc_t',
            before    => Class['::apache::service'],
            notify    => Class['::apache::service'],
            subscribe => Package[$packages],
            ;
        [
            $top_dir,
            "${top_dir}/images",
            "${top_dir}/packages",
            "${top_dir}/repos",
            "${top_dir}/repos-dist",
            "${top_dir}/repos/signed",
            "${top_dir}/scratch",
            "${top_dir}/work",
        ]:
            ensure  => directory,
            owner   => 'apache',
            group   => 'apache',
            mode    => '0755',
            seltype => 'public_content_rw_t',
            ;
        '/etc/koji-hub/hub.conf':
            content => template('koji/hub/hub.conf'),
            ;
    }

}
