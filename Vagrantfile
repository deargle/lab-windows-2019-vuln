Vagrant.configure("2") do |config|

  config.vm.box = "deargle/vuln-windows-2019"


  config.vm.provider "libvirt" do |libvirt|
    libvirt.cpus = 4
    libvirt.memory = 4096
  end

  config.vm.provision "shell", path: "build/scripts/create-labuser.ps1"
  config.vm.provision "shell", path: "build/scripts/disable-dep.bat"
  config.vm.provision "shell", path: "build/scripts/install-icecast.ps1"
  config.vm.provision "shell", path: "build/scripts/set-password-not-expired.bat"
end
