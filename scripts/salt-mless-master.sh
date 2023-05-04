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
  
  sudo apt install git autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev -y
  curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
  source ~/.bashrc
  ~/.rbenv/bin/rbenv install 3.2.2
  ~/.rbenv/bin/rbenv global 3.2.2
  ruby --version
fi




