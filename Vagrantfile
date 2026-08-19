Vagrant.configure("2") do |config|

  config.vm.box = "deargle/vuln-windows-2019"
  config.vm.box_version = "0.0.4"

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

  # No private_network is declared here: this VM's infosec-net interface comes
  # from the box's embedded Vagrantfile (see build/Vagrantfile.template), so it
  # cannot be given :libvirt__always_destroy => false from this file. Declaring
  # the network here would ACCUMULATE a second NIC rather than merge.

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
