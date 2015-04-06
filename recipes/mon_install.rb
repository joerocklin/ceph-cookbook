include_recipe 'ceph'

node['ceph']['mon']['packages'].each do |pck|
  package pck
end

# CentOS 7 has some extra work until ceph supports systemd from the RPMs
if node['platform'] == 'centos' && node['platform_version'] == '7.0.1406'
  # Put the necessary systemd files in place
  cookbook_file '/etc/systemd/system/ceph-mon@.service' do
    mode  '0644'
    action :create
    source 'ceph-mon@.service'
  end

  cookbook_file '/etc/systemd/system/ceph.target' do
    mode  '0644'
    action :create
    source 'ceph.target'
  end

  service 'ceph.target' do
    action :enable
  end

  bash "move ceph initscript" do
    code <<-EOL
    systemctl disable ceph || true
    mv /etc/init.d/ceph #{Chef::Config[:file_cache_path]}/ceph-initscript
    EOL
    only_if { File.exists?("/etc/init.d/ceph") }
  end
end
