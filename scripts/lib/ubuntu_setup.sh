#!/bin/bash

# Runs after initial vagrant_setup.sh script when Vagrantfile has been created; called during first boot.
# Presumes sudo access.

install_exim=false

# Set APT sources to point to local UH mirror; covers all possible Ubuntu versions from 12.04 - 16.04
# Safe defaults: 
# deb http://us.archive.ubuntu.com/ubuntu/ xenial main universe multiverse 
# deb http://us.archive.ubuntu.com/ubuntu/ xenial-security main universe multiverse 
# deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates main universe multiverse 
sed 's|archive.ubuntu.com|mirror.pnl.gov/ubuntu/|' -i /etc/apt/sources.list
sed 's|nova.clouds.archive.ubuntu.com|mirror.pnl.gov/ubuntu/|' -i /etc/apt/sources.list
sed 's|zone_10G.clouds.archive.ubuntu.com|mirror.pnl.gov/ubuntu/|' -i /etc/apt/sources.list
sed '/^deb-src/d' -i /etc/apt/sources.list
sed '/^#/d' -i /etc/apt/sources.list
sed '/^$/d' -i /etc/apt/sources.list


# Run full updates on box after booting
apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoclean

# We need debconf to set up MySQL and potentially exim.
apt-get install debconf-utils -y

# Set default git config settings; works under Vagrant.
cat <<EOF >/home/vagrant/.gitconfig
[color]
  ui = 1
[credential]
  helper = cache --timeout=300
[alias]
  lg1 = log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all
  lg2 = log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)' --all
  lg = !"git lg1"
EOF
chown vagrant: /home/vagrant/.gitconfig

# Install exim mail client if requested.
if $install_exim; then
  # Configuration details needed here.
  # debconf-set-selections <<CONF
  #   exim4-config exim4/dc_other_hostnames
  apt-get install exim4 -y
fi

# Install other base tools that we'll want to use.
apt-get install unzip vsftpd -y

# Enable write access via vsftpd (Used for WordPress file operations).
sed 's|#write_enable=YES|write_enable=YES|g' -i /etc/vsftpd.conf
service vsftpd restart

# Change base vagrant user password
echo vagrant:password | chpasswd