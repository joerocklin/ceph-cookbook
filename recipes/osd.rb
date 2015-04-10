#
# Author:: Kyle Bader <kyle.bader@dreamhost.com>
# Cookbook Name:: ceph
# Recipe:: osd
#
# Copyright 2011, DreamHost Web Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# this recipe allows bootstrapping new osds, with help from mon
# Sample environment:
# #knife node edit ceph1
# "osd_devices": [
#   {
#       "device": "/dev/sdc"
#   },
#   {
#       "device": "/dev/sdd",
#       "dmcrypt": true,
#       "journal": "/dev/sdd"
#   }
# ]

include_recipe 'ceph'
include_recipe 'ceph::osd_install'

package 'gdisk' do
  action :upgrade
end

package 'cryptsetup' do
  action :upgrade
  only_if { node['dmcrypt'] }
end

service_type = node['ceph']['osd']['init_style']

directory '/var/lib/ceph/bootstrap-osd' do
  owner 'root'
  group 'root'
  mode '0755'
end

# TODO: cluster name
cluster = 'ceph'

execute 'format bootstrap-osd as keyring' do
  command lazy { "ceph-authtool '/var/lib/ceph/bootstrap-osd/#{cluster}.keyring' --create-keyring --name=client.bootstrap-osd --add-key='#{osd_secret}'" }
  creates "/var/lib/ceph/bootstrap-osd/#{cluster}.keyring"
  only_if { osd_secret }
end

if crowbar?
  node['crowbar']['disks'].each do |disk, _data|
    execute "ceph-disk-prepare #{disk}" do
      command "ceph-disk-prepare /dev/#{disk}"
      only_if { node['crowbar']['disks'][disk]['usage'] == 'Storage' }
      notifies :run, 'execute[udev trigger]', :immediately
    end

    ruby_block "set disk usage for #{disk}" do
      block do
        node.set['crowbar']['disks'][disk]['usage'] = 'ceph-osd'
        node.save
      end
    end
  end

  execute 'udev trigger' do
    command 'udevadm trigger --subsystem-match=block --action=add'
    action :nothing
  end
else
  # Calling ceph-disk-prepare is sufficient for deploying an OSD
  # After ceph-disk-prepare finishes, the new device will be caught
  # by udev which will run ceph-disk-activate on it (udev will map
  # the devices if dm-crypt is used).
  # IMPORTANT:
  #  - Always use the default path for OSD (i.e. /var/lib/ceph/
  # osd/$cluster-$id)
  #  - $cluster should always be ceph
  #  - The --dmcrypt option will be available starting w/ Cuttlefish
  #  - Set zap_disk to true to zap OSD disks before activation
  if node['ceph']['osd_devices']
    devices = node['ceph']['osd_devices']

    devices = Hash[(0...devices.size).zip devices] unless devices.kind_of? Hash

    devices.each do |index, osd_device|
      status = osd_device['status']

      # lets check physical status of the device
      prepared = system "ceph-disk list | grep #{osd_device['device']} | grep prepared -q"
      if prepared
        Log.info("osd: osd_device #{osd_device} has already been setup.")
        next
      end

      active = system "ceph-disk list | grep #{osd_device['device']} | grep active -q"
      if active
        Log.info("osd: osd_device #{osd_device} is already active.")
        next
      end

      directory osd_device['device'] do # ~FC022
        owner 'root'
        group 'root'
        recursive true
        only_if { osd_device['type'] == 'directory' }
      end

      dmcrypt = osd_device['encrypted'] == true ? '--dmcrypt' : ''
      zap_disk = status == 'zap-disk' ? '--zap-disk' : ''
      osd_device['fstype'] = node['ceph']['osd']['fstype'] unless osd_device['fstype']
      fstype = "--fs-type #{osd_device['fstype']}"
      journal = osd_device['journal']
      if osd_device['fstype'] != 'btrfs' && (journal.nil? || journal.size == 0)
        Log.warn("#{osd_device['device']} defined as #{osd_device['fstype']} but no journal device defined")
      end

      Log.debug " ---- #{osd_device['device']} ----"
      Log.debug "  dmcrypt: #{dmcrypt}"
      Log.debug " zap_disk: #{zap_disk}"
      Log.debug "   fstype: #{fstype}"
      Log.debug "  journal: #{journal}"

      execute "ceph-disk-prepare on #{osd_device['device']}" do
        command "ceph-disk-prepare #{dmcrypt} #{zap_disk} #{fstype} #{osd_device['device']} #{journal}"
        action :run
      end

      execute "ceph-disk-activate #{osd_device['device']}" do
        only_if { osd_device['type'] == 'directory' }
      end
    end

    Dir.foreach("/var/lib/ceph/osd") do |osd|
      next unless osd.match "ceph"
      id = osd.split(/-/)[1]

      service "ceph_osd" do
        service_name "ceph-osd@#{id}"
        action [:enable, :start]
        supports :restart => true
        only_if { rhel? && node['platform_version'].to_f >= 7 }
      end
    end

    service 'ceph_osd' do
      service_name 'ceph-osd-all-starter'
      provider Chef::Provider::Service::Upstart
      action [:enable, :start]
      supports :restart => true
      only_if { service_type == 'upstart' }
    end
  else
    Log.info('node["ceph"]["osd_devices"] empty')
  end
end
