# adblock
#
# Createa few files
# @summary
#   Create adlist
#
class adblock (
  Stdlib::Absolutepath $pihole_installer,
  Stdlib::Absolutepath $etc_pihole,
  Stdlib::Absolutepath $adlist,
  Stdlib::Absolutepath $whitelist,
  Array[Stdlib::Fqdn] $whitelist_urls,
  Stdlib::Absolutepath $cron_path,
  Stdlib::Absolutepath $setup_vars_path,
  Array[Stdlib::Httpurl] $urls,

  # variables for setupvars.conf
  String $blocking_enabled,
  String $dnsmasq_listening,
  String $dns_fqdn_required,
  String $dns_bogus_priv,
  String $dnssec,
  String $conditional_forwarding,
  String $pihole_interface,
  String $pihole_dns_1,
  String $pihole_dns_2,
  String $pihole_dns_3,
  String $pihole_dns_4,
  String $query_logging,
  String $install_web_server,
  String $install_web_interface,
  String $lighttpd_enabled,
  String $webpassword,

  #calculate ipv4 address
  $ip_addr = "$::ipaddress_eth0",
  $netmask_cidr = netmask_to_masklen( "$::netmask_eth0" ),
  $ipv4_address = "${ip_addr}/${netmask_cidr}",


  # so strange, can't write as ipv6_address, gives out empty thing
  $ipv6address = "${facts['networking']['interfaces']['eth0']['ip6']}",
) {

  # pihole installer script download
  # usage is /root/Pi-hole/automated\ install/basic-install.sh --unattended
  vcsrepo { $pihole_installer :
    ensure   => present,
    provider => git,
    source   => 'https://github.com/pi-hole/pi-hole.git',
  }

  # install pihole, unless already exists
  exec { "pihole_install":
    command => "${pihole_installer}/automated install/basic-install.sh --unattened",
    user    => "root",
    creates => "/usr/local/bin/pihole",
    cwd     => "${pihole_installer}/automated install",
    path    => ['/usr/local/bin', '/usr/bin', '/usr/sbin', '/bin'],
    require => [ Concat['adlist_file', 'whitelist_file'], File['setup_vars'],
              File[$etc_pihole]],
  }

  # drop cron file for updating pihole, it is the default one that
  # comes with package
  file { 'pihole_cron' :
    ensure  => present,
    path    => $cron_path,
    owner   => "root",
    group   => "root",
    mode    => "0644",
    content => template("adblock/pihole.erb"),
  }

  # pihole main directory
  file { 'etc_pihole' :
  path   => $etc_pihole,
  ensure => 'directory',
  group  => 'pihole',
  owner  => 'pihole',
  mode   => '0755',
  }

  # pihole user and group
  user { 'pihole':
  ensure             => 'present',
  gid                => 995,
  groups             => ['www-data'],
  home               => '/home/pihole',
  password           => '!',
  password_max_age   => -1,
  password_min_age   => -1,
  password_warn_days => -1,
  shell              => '/usr/sbin/nologin',
  uid                => 999,
  }

  group { 'pihole':
    ensure => 'present',
    gid    => 995,
  }

  # setup variables of pihole
  file { 'setup_vars' :
    ensure  => present,
    path    => $setup_vars_path,
    owner   => "root",
    group   => "root",
    mode    => "0644",
    content => template("adblock/setupVars.conf.erb"),
    require => File[$etc_pihole],
  }

  concat { 'adlist_file':
    ensure         => present,
    path           => $adlist,
    ensure_newline => true,
    order          => 'numeric',
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    require => File[$etc_pihole],
   }

  # whiltelist file
  concat { 'whitelist_file':
    ensure         => present,
    path           => $whitelist,
    ensure_newline => true,
    order          => 'numeric',
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    require => File[$etc_pihole],
   }

  exec { 'piholeupdate':
    path        => ['/bin/', '/usr/bin', '/usr/local/bin/'],
    command     => "pihole -g",
    user        => "root",
    subscribe   => [ Concat['adlist_file', 'whitelist_file'], File['setup_vars'] ],
    require => File[$etc_pihole],
    refreshonly => true,
  }

  service { "pihole_ftl" :
    name      => 'pihole-FTL',
    ensure    => running,
    enable    => true,
    subscribe => [ Concat['adlist_file', 'whitelist_file'], File['setup_vars'] ],
    require   => [ Exec['piholeupdate'], File[$etc_pihole] ],
  }

  $urls.each | String $url | {
    # $url is the title of the resource
    ensure_resource('adblock::url', $url, {'target_file' => 'adlist_file'})
  }

  $whitelist_urls.each | String $url | {
    ensure_resource('adblock::url', $url, {'target_file'=> 'whitelist_file'})
  }

}
