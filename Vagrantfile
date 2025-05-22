# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure("2") do |config|

  config.vm.box = "almalinux/8"
  config.vm.box_version = "8.10.20250220"
  
  config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
  end

  # WordPress setup
  config.vm.provision :shell, :path => "provision/bootstrap-wordpress.sh"
end
