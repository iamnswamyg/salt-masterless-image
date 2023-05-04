#!/bin/bash


if ! dpkg-query -W curl >/dev/null 2>&1; then
  sudo apt install curl -y
fi

if ! dpkg-query -W salt-master >/dev/null 2>&1; then
  mkdir -p /var/lxd-provision
  cd /var/lxd-provision
  curl -L https://bootstrap.saltstack.com -o install_salt.sh

  # Install Master
  sudo sh install_salt.sh stable 3005.1
  
  sudo apt update
  sudo apt install gnupg2
  gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
  \curl -sSL https://get.rvm.io -o rvm.sh
  cat rvm.sh | bash -s stable --rails
  source ~/.rvm/scripts/rvm
  
fi




