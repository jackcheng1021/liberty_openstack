#!/bin/bash

echo "$(hostname): config liberty-env"

source liberty-openrc.sh
rpm -q expect &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install expect &> /dev/null
  if [ $? -ne 0 ]; then
    echo "network connect error"
    exit
  fi
fi

echo "prepare scripts to controller"

chmod +x *.sh
/usr/bin/expect << FLAGEOF
set timeout 2
spawn ssh $controller_user@$controller_ip   
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "$controller_user_pass\r"}
}
expect "${controller_user}@*" {send "ln -s liberty-openrc.sh /usr/local/bin/liberty-openrc\r"}
expect "${controller_user}@*" {send "ln -s liberty-pre-controller.sh /usr/local/bin/liberty-pre-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-database-controller.sh /usr/local/bin/liberty-database-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-keystone-controller.sh /usr/local/bin/liberty-keystone-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-glance-controller.sh /usr/local/bin/liberty-glance-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-nova-controller.sh /usr/local/bin/liberty-nova-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-neutron-controller.sh /usr/local/bin/liberty-neutron-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-dashboard-controller.sh /usr/local/bin/liberty-dashboard-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-cinder-controller.sh /usr/local/bin/liberty-cinder-controller\r"}
expect "${controller_user}@*" {send "ln -s liberty-tenant-create.sh /usr/local/bin/liberty-tenant-create\r"}
expect "${controller_user}@*" {send "ln -s liberty-tenant-network-create.sh /usr/local/bin/liberty-tenant-network-create\r"}
ecpect "${controller_user}@*" {send "ln -s liberty-tenant-instance-create.sh /usr/local/bin/liberty-tenant-instance-create\r"}
expect "${controller_user}@*" {send "exit\r"}
expect eof
FLAGEOF

echo "prepare scripts to compute01"
libery_path=$(pwd)
dir_name=`pwd | awk -F "/" '{print $NF}'`

/usr/bin/expect << FLAGEOF
set timeout 30
spawn scp *.sh  $compute01_user@$compute01_ip:/root/
expect {
  "(yes/no)?" {send "yes\r"; exp_continue}
  "Password:" {send "${compute01_user_pass}\r"}
}
expect eof
FLAGEOF

/usr/bin/expect << FLAGEOF
set timeout 30
spawn ssh $compute01_user@$compute01_ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "$compute01_user_pass\r"}
}
expect "${compute01_user}@*" {send "cd /root/\r"}
expect "${compute01_user}@*" {send "ln -s liberty-openrc.sh /usr/local/bin/liberty-openrc\r"}
expect "${compute01_user}@*" {send "ln -s liberty-pre-compute.sh /usr/local/bin/liberty-pre-compute\r"}
expect "${compute01_user}@*" {send "ln -s liberty-nova-compute.sh /usr/local/bin/liberty-nova-compute\r"}
expect "${compute01_user}@*" {send "ln -s liberty-neutron-compute.sh /usr/local/bin/liberty-neutron-compute"}
expect "${compute01_user}@*" {send "ln -s liberty-cinder-compute.sh /usr/local/bin/liberty-cinder-compute\r"}
expect "${compute01_user}@*" {send "exit\r"}
expect eof
FLAGEOF

echo "prepare scripts to compute02"
libery_path=$(pwd)
dir_name=`pwd | awk -F "/" '{print $NF}'`

/usr/bin/expect << FLAGEOF
set timeout 30
spawn scp *.sh  $compute02_user@$compute02_ip:/root/
expect {
  "(yes/no)?" {send "yes\r"; exp_continue}
  "Password:" {send "${compute02_user_pass}\r"}
}
expect eof
FLAGEOF

/usr/bin/expect << FLAGEOF
set timeout 30
spawn ssh $compute02_user@$compute02_ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "$compute02_user_pass\r"}
}
expect "${compute02_user}@*" {send "cd /root/\r"}
expect "${compute02_user}@*" {send "ln -s liberty-openrc.sh /usr/local/bin/liberty-openrc\r"}
expect "${compute02_user}@*" {send "ln -s liberty-pre-compute.sh /usr/local/bin/liberty-pre-compute\r"}
expect "${compute02_user}@*" {send "ln -s liberty-nova-compute.sh /usr/local/bin/liberty-nova-compute\r"}
expect "${compute02_user}@*" {send "ln -s liberty-neutron-compute.sh /usr/local/bin/liberty-neutron-compute"}
expect "${compute02_user}@*" {send "ln -s liberty-cinder-compute.sh /usr/local/bin/liberty-cinder-compute\r"}
expect "${compute02_user}@*" {send "exit\r"}
expect eof
FLAGEOF

echo "$(hostname): config liberty env finish"
