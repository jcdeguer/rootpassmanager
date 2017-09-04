# == Class: rootpassmanager
# Full description of class rootpassmanager here.
#
# === Parameters
# Document parameters here.
#
# === Variables
# Here you should define a list of variables that this module would require.
#
# === Examples
#
# === Authors
#
# === Copyright
#
class rootpassmanager (

  $change_enable        = $::rootpassmanager::params::change_enable,
  $root_user_name       = $::rootpassmanager::params::root_user_name,
  $root_password        = $::rootpassmanager::params::root_password,

) inherits rootpassmanager::params {

  include rootpassmanager::changer
  include rootpassmanager::generator

  Class['rootpassmanager::generator']
  -> Class['rootpassmanager::changer']

}
