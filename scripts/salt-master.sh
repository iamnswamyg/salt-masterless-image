#!/bin/bash


if ! dpkg-query -W curl >/dev/null 2>&1; then
  sudo apt install curl -y
fi

mkdir -p /var/lxd-provision
cd /var/lxd-provision
curl -L https://bootstrap.saltstack.com -o install_salt.sh

# Install Master
sudo sh install_salt.sh -P -M -N
cp /lxd/saltconfig/master.local.conf /etc/salt/master.d/local.conf
systemctl restart salt-master


