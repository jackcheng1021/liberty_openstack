#!/usr/bin/env bash

echo "run liberty-tenant-instance-install-app"

ip=$1
tenant=$2
instanceName=$3
app=$4 #要安装的软件

sourc /etc/keystone/$tenant-openrc.sh

/usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "000000\r"}
}
expect "${instanceName}@*" {send "yum -y install ${app} &> /dev/null \r"}
expect "${instanceName}@*" {send "exit\r"}
expect eof
FLAGEOF

echo "run liberty-tenant-instance-install-app finish"