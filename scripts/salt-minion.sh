#!/bin/bash

if ! dpkg-query -W curl >/dev/null 2>&1; then
  sudo apt install curl -y
fi

curl -L https://bootstrap.saltstack.com -o install_salt.sh
sudo sh install_salt.sh -P

cp /lxd/saltconfig/minion.local.conf /etc/salt/minion.d/local.conf
systemctl restart salt-minion
