#!/usr/bin/env bash

echo "run liberty-tenant-instance-deploy-tomcat-package"

ip=$1
tenant=$2
packageUrl=$3
packageName=$(echo "${packageUrl}" | awk -F '/' '{print $NF}')

sourc /etc/keystone/$tenant-openrc.sh

/usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "000000\r"}
}
expect "root@*" {send "curl -o /opt/${packageName} ${packageUrl} &> /dev/null \r"}
expect "root@*" {send "docker cp /opt/${packageName} mysql:/usr/local/tomcat/webapps/ \r"}
expect "root@*" {send "exit\r"}0
expect eof
FLAGEOF

echo "run liberty-tenant-instance-deploy-tomcat-package finish"