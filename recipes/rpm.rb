platform_family = node['platform_family']

case platform_family
when 'rhel'
  include_recipe 'yum-epel' if node['ceph']['el_add_epel']
end

branch = node['ceph']['branch']
if branch == 'dev' && platform_family != 'centos' && platform_family != 'fedora'
  fail "Dev branch for #{platform_family} is not yet supported"
end

package 'yum-priorities'

# Packaging by RHEL/CentOS/Fedora (and maybe others?) causes problems with the
# using the Ceph repos. According to the issue in the Ceph tracking system below,
# the solution is to inform the priorities config to not perform obsolete checks.
#
# see http://tracker.ceph.com/issues/10476
replace_or_add 'Ignore obsoletes in yum priority checks' do
  path '/etc/yum/pluginconf.d/priorities.conf'
  pattern 'check_obsoletes=*'
  line 'check_obsoletes=1'
end

yum_repository 'ceph' do
  description 'Ceph Packages'
  baseurl node['ceph'][platform_family][branch]['repository']
  gpgkey node['ceph'][platform_family][branch]['repository_key']
  priority '10'
end

yum_repository 'ceph-extra' do
  description 'Ceph Extra Packages'
  baseurl node['ceph'][platform_family]['extras']['repository']
  gpgkey node['ceph'][platform_family]['extras']['repository_key']
  priority '10'
  only_if { node['ceph']['extras_repo'] }
end

yum_repository 'ceph-testing' do
  description 'Ceph Testing Packages'
  baseurl node['ceph'][platform_family]['testing']['repository']
  gpgkey node['ceph'][platform_family]['testing']['repository_key']
  priority '20'
  enabled node['ceph']['testing_repo_enable']
  only_if { node['ceph']['testing_repo'] }
end

package 'parted'    # needed by ceph-disk-prepare to run partprobe
package 'hdparm'    # used by ceph-disk activate
package 'xfsprogs'  # needed by ceph-disk-prepare to format as xfs
if node['platform_family'] == 'rhel' && node['platform_version'].to_f > 6
  package 'btrfs-progs' # needed to format as btrfs, in the future
end
if node['platform_family'] == 'rhel' && node['platform_version'].to_f < 7
  package 'python-argparse'
end
