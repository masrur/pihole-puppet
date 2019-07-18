# add url to adlist
define adblock::url (
  String $url = $title,
  String $target_file,
  $order = '10',
) {
  include adblock

  concat::fragment { "adblock_fragment_url_${url}":
    target  => $target_file,
    order   => $order,
    content => "${url}",
  }
}
