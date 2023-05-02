#!/bin/bash

if ! dpkg-query -W curl >/dev/null 2>&1; then
  sudo apt install curl -y
fi

if ! dpkg-query -W salt-minion >/dev/null 2>&1; then
  curl -L https://bootstrap.saltstack.com -o install_salt.sh
  sudo sh install_salt.sh -P
fi


