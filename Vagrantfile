# -*- mode: ruby -*-
# vi: set ft=ruby :

provider = ENV['BOX_PROVIDER'] || "one"
box_site = ENV['BOX_SITE'] || "http://archive.ai-traders.com/lab/1.0/boxes/"
chef_version = ENV['CHEF_VERSION'] || "11.16.4"

VAGRANTFILE_API_VERSION = "2"
Vagrant.require_version ">= 1.5.0"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.omnibus.chef_version = chef_version
  config.vm.box = ENV['BOX'] || "#{provider}-ai-wheezy"
  config.vm.box_url = "#{box_site}/#{config.vm.box}.box"
  config.berkshelf.enabled = true

  config.vm.provision :chef_solo do |chef|
    chef.json = {
      ceph:{
        config:{
          fsid: '5973e096-0430-4e9b-b10c-a414737639d2',
          global:{
            # to ensure ceph can become active+clean on single node
            'osd crush chooseleaf type' => 0,
            'osd pool default size' => 2,
            'osd pool default min size' => 1
          }
        },
        'monitor-secret' => 'AQDVEfNUeEv9KhAACFaBYeJUhGY09Gwo5kdBDg==',
        'admin-secret' => 'AQCPZfNUuP5WHxAAMcUqobR4wzTmiTp1KlLofQ==',
        osd_devices: [ { 'device' => '/dev/vdb', 'fs-type' => 'btrfs' }, { 'device' => '/dev/vdc'}, { 'device' => '/dev/vdd'}  ]
      }
    }

    chef.add_recipe "ceph::default"
    chef.add_recipe "ceph::mon"
    chef.add_recipe "ceph::osd"
    
  end
end
