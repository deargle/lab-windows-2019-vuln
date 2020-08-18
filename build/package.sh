#!/bin/bash
vagrant up
vagrant provision
vagrant provision --provision-with reboot
vagrant halt
#export VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-lvm-uuids"
vagrant package --output package.box --vagrantfile Vagrantfile.template
# vagrant cloud publish...
