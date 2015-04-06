include_recipe 'ceph::default'

admin_keyring_file = '/etc/ceph/ceph.client.admin.keyring'
gen_command = "ceph-authtool --create-keyring #{admin_keyring_file} --gen-key -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'"

#TODO admin secret is set already or generate

execute 'format admin secret as keyring' do
  command lazy { "ceph-authtool '#{admin_keyring_file}' --create-keyring --name=client.admin --add-key='#{admin_secret}' --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'" }
  creates admin_keyring_file
  only_if { admin_secret }
end

if Chef::Config['solo']
  fail 'Admin secret must be set' unless admin_secret
else
  execute 'Generate client.admin keyring' do
    command gen_command
    creates admin_keyring_file
    notifies :create, 'ruby_block[save admin_secret]', :immediately
  end
  ruby_block 'save admin_secret' do
    block do
      fetch = Mixlib::ShellOut.new("ceph-authtool '#{admin_keyring_file}' --print-key --name=client.admin")
      fetch.run_command
      key = fetch.stdout
      node.set['ceph']['admin-secret'] = key
      node.save
    end
    action :nothing
  end
end

