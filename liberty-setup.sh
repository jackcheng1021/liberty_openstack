#!/bin/bash

menu() {
  clear
  echo "----Welcome Use Liberty OpenStack One Key System----"
  echo "    inpute 1: one key install openstack"
  echo "    inpute 2: config environment"
  echo "    inpute 3: restore configuration"
  echo "    inpute 4: reinstall database"
  echo "    inpute 5: reinstall keystone"
  echo "    inpute 6: reinstall glance"
  echo "    inpute 7: reinstall nova"
  echo "    inpute 8: reinstall neutron"
  echo "    inpute 9: reinstall dashboard"
  echo "    inpute 0: reinstall Cinder"
  echo "    inpute 11 show menu"
  echo "    inpute 10: quit"
  echo "----------------------------------------------------"
}


while [ 1 -eq 1 ]
do
  menu
  read -p "pleae input key: " key
  if [ $key -eq 10 ]; then
    echo "welcome to use again，bye"
    break
  fi 
  if [ $key -eq 11 ]; then
    menu
  fi
  
  if [ $key -eq 1 ]; then
    echo "start one key install liberty-openstack"
    ln -s liberty-env-config.sh /usr/local/bin/liberty-env-config
    liberty-env-config

    source liberty-openrc

    liberty-pre-controller

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute01_user}@${compute01_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute01_user_pass}\r"}
}
expect "${compute01_user}@*" {send "liberty-pre-compute \r"}
expect "${compute01_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute02_user}@${compute02_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute02_user_pass}\r"}
}
expect "${compute02_user}@*" {send "liberty-pre-compute \r"}
expect "${compute02_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    liberty-database-controller
    liberty-keystone-controller
    liberty-glance-controller
    liberty-nova-controller

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute01_user}@${compute01_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute01_user_pass}\r"}
}
expect "${compute01_user}@*" {send "liberty-nova-compute \r"}
expect "${compute01_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute02_user}@${compute02_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute02_user_pass}\r"}
}
expect "${compute02_user}@*" {send "liberty-nova-compute \r"}
expect "${compute02_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    liberty-neutron-controller

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute01_user}@${compute01_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute01_user_pass}\r"}
}
expect "${compute01_user}@*" {send "liberty-neutron-compute \r"}
expect "${compute01_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute02_user}@${compute02_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute02_user_pass}\r"}
}
expect "${compute02_user}@*" {send "liberty-neutron-compute \r"}
expect "${compute02_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF
    
    liberty-dashboard-controller
    liberty-cinder-controller

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute01_user}@${compute01_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute01_user_pass}\r"}
}
expect "${compute01_user}@*" {send "liberty-cinder-compute \r"}
expect "${compute01_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    /usr/bin/expect << FLAGEOF
set timeout 60
spawn ssh ${compute02_user}@${compute02_ip}
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${compute02_user_pass}\r"}
}
expect "${compute02_user}@*" {send "liberty-cinder-compute \r"}
expect "${compute02_user}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

    echo "create default tenant user"
    liberty-tenant-create

    echo "create default tenant network"
    liberty-tenant-network-create

    echo "create default tenant instance"
    liberty-tenant-instance-create
    
    echo "one key install liberty-openstack finish"
    
  fi
done
