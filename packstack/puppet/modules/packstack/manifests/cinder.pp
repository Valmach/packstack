class packstack::cinder ()
{
    create_resources(packstack::firewall, hiera('FIREWALL_CINDER_RULES', {}))
    create_resources(packstack::firewall, hiera('FIREWALL_CINDER_API_RULES', {}))

    case hiera('CONFIG_CINDER_BACKEND') {
      'lvm':       { $default_volume_type = 'iscsi' }
      'gluster':   { $default_volume_type = 'glusterfs' }
      'nfs':       { $default_volume_type = 'nfs' }
      'vmdk':      { $default_volume_type = 'vmdk' }
      'netapp':    { $default_volume_type = 'netapp' }
      'solidfire': { $default_volume_type = 'solidfire' }
      default:     { $default_volume_type = 'iscsi' }
    }

    cinder_config {
      'DEFAULT/glance_host': value => hiera('CONFIG_STORAGE_HOST_URL');
    }

    $bind_host = hiera('CONFIG_IP_VERSION') ? {
      'ipv6'  => '::0',
      default => '0.0.0.0',
      # TO-DO(mmagr): Add IPv6 support when hostnames are used
    }

    $cinder_keystone_url = regsubst(regsubst(hiera('CONFIG_KEYSTONE_PUBLIC_URL'),'/v2.0',''),'/v3','')

    class { '::cinder::api':
      bind_host               => $bind_host,
      keystone_password       => hiera('CONFIG_CINDER_KS_PW'),
      keystone_tenant         => 'services',
      keystone_user           => 'cinder',
      auth_uri                => $cinder_keystone_url,
      identity_uri            => hiera('CONFIG_KEYSTONE_ADMIN_URL'),
      nova_catalog_info       => 'compute:nova:publicURL',
      nova_catalog_admin_info => 'compute:nova:adminURL',
      service_workers         => hiera('CONFIG_SERVICE_WORKERS'),
      default_volume_type     => $default_volume_type,
    }

    class { '::cinder::scheduler': }

    class { '::cinder::volume': }

    class { '::cinder::client': }

    $cinder_keystone_admin_username = hiera('CONFIG_KEYSTONE_ADMIN_USERNAME')
    $cinder_keystone_admin_password = hiera('CONFIG_KEYSTONE_ADMIN_PW')
    $cinder_keystone_auth_url = hiera('CONFIG_KEYSTONE_PUBLIC_URL')
    $cinder_keystone_api = hiera('CONFIG_KEYSTONE_API_VERSION')

    # Cinder::Type requires keystone credentials
    Cinder::Type {
      os_password    => hiera('CONFIG_CINDER_KS_PW'),
      os_tenant_name => 'services',
      os_username    => 'cinder',
      os_auth_url    => hiera('CONFIG_KEYSTONE_PUBLIC_URL'),
    }

    class { '::cinder::backends':
      enabled_backends => hiera_array('CONFIG_CINDER_BACKEND'),
    }

    $db_purge = hiera('CONFIG_CINDER_DB_PURGE_ENABLE')
    if $db_purge {
      class { '::cinder::cron::db_purge':
        hour        => '*/24',
        destination => '/dev/null',
        age         => 1
      }
    }
}
