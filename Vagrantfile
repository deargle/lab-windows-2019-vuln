Vagrant.configure("2") do |config|

  config.vm.box = "security-assignments/vuln-windows-2019"
  config.vm.box_version = "0.0.5"
  config.vm.box_url     = "https://storage.googleapis.com/security-assignments-vagrant-boxes/registry/vuln-windows-2019/metadata.json"

  config.vm.provider "libvirt" do |libvirt|
    libvirt.cpus = 4
    libvirt.memory = 4096
    libvirt.management_network_name = 'vagrant-libvirt'
    libvirt.management_network_autostart = true
    # Keep the shared 'vagrant-libvirt' management network on `vagrant destroy`.
    # Without it, destroying this VM deletes the network the other lab VMs'
    # domains still reference, and their next boot fails.
    libvirt.management_network_keep = true
  end

  # Declared here rather than in the box, same rationale as the other lab VMs.
  # always_destroy false stops `vagrant destroy` of this VM deleting
  # infosec-net out from under Metasploitable2.
  config.vm.network :private_network,
      :ip => "192.168.56.100",
      :libvirt__network_name => "infosec-net",
      :libvirt__dhcp_enabled => false,
      :libvirt__host_ip => "192.168.56.101",
      :libvirt__always_destroy => false,
      :autostart => true

  # to trigger, run `vagrant provision --provision-with install-word`
  config.vm.provision "install-word", type: "shell", run: "never", path: "build/scripts/chocolatey-installs/install-word.ps1"

  # to trigger, run `vagrant provision --provision-with reboot`
  config.vm.provision "reboot", type: "shell", run: "never" do |s|
    s.inline = "echo 'rebooting'"
    s.reboot = true
  end

  # to trigger, run `vagrant provision --provision-with rearm`
  config.vm.provision "rearm", type: "shell", run: "never" do |s|
    s.inline = "slmgr /rearm"
    s.reboot = true
  end
end
