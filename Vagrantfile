# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "peru/windows-server-2019-datacenter-x64-eval"
  config.vm.box_version = "20200707.01"
  config.vm.provider "libvirt" do |v|
    v.cpus = "2"
  end
  config.vm.network "forwarded_port", guest: 22, host: 2222

  config.vm.network :private_network,
      :ip => "192.168.56.100",
      :libvirt__network_name => "infosec-net",
      :libvirt__dhcp_enabled => false,
      :libvirt__host_ip => "192.168.56.101",
      :autostart => true

  config.vm.provision "shell", path: "scripts/openssh-builtin.ps1"
  config.vm.provision "shell", path: "scripts/install-chocolatey.ps1"
  config.vm.provision "shell", path: "scripts/windows-updates-disable.ps1"
  config.vm.provision "shell", path: "scripts/disable-firewall.bat"
  config.vm.provision "shell", path: "scripts/disable-win-defend.ps1"
  config.vm.provision "shell", path: "scripts/install-icecast.ps1"
  config.vm.provision "shell", path: "scripts/chocolatey-installs/install-libreoffice.ps1"
  config.vm.provision "shell", path: "scripts/chocolatey-installs/install-hashdeep.ps1"
  config.vm.provision "shell", path: "scripts/configs/enable-audio-services.ps1"

end
