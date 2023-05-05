#!/bin/bash


if ! dpkg-query -W curl >/dev/null 2>&1; then
  sudo apt install curl -y
fi

if ! dpkg-query -W salt-minion >/dev/null 2>&1; then
  
  echo "No Minion Found, Skipping installation"
   
fi

cat /lxd/saltconfig/minion.local.conf
cp /lxd/saltconfig/minion.local.conf /etc/salt/minion.d/local.conf
systemctl restart salt-minion



