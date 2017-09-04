# Class: rootpassmanager::changer
#
# This class manage the pass of root user.
#

class rootpassmanager::changer {

  $change_enable        = $::rootpassmanager::change_enable
  $root_user_name       = $::rootpassmanager::root_user_name
  $root_password        = $::rootpassmanager::root_password

  if $change_enable == true {
    user { $root_user_name:
      ensure  => present,
      comment => "Actualizado el ${::uptime_seconds} ",
      password => pw_hash($root_password, 'SHA-512', $root_user_name),
      managehome => true,
    }
  }
}
