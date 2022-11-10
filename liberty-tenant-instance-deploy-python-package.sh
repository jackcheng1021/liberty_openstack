#!/usr/bin/env bash

echo "run liberty-tenant-instance-deploy-python-package"

ip=$1
tenant=$2
packageUrl=$3
packageName=$(echo "${packageUrl}" | awk -F '/' '{print $NF}')
scriptName=$4
packageVersion=$5

sourc /etc/keystone/$tenant-openrc.sh

/usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "000000\r"}
}
expect "root@*" {send "curl -o ${packageName} ${packageUrl} &> /dev/null \r"}
expect "root@*" {send "echo 'FROM python:3.6' >> ${packageName}_file_python \r"}
expect "root@*" {send "echo 'ADD ${packageName} /opt/' >> ${packageName}_file_python \r"}
expect "root@*" {send "echo 'CMD [\"python\",\"/opt/${packageName}/${scriptName}\"]' >> ${packageName}_file_python \r"}
expect "root@*" {send "docker build -f ${packageName}_file_python -t ${packageName}:${packageVersion} . &> /dev/null \r"}
expect "root@*" {send "docker run --network host -d ${packageName}:${packageVersion} &> /dev/null \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF

echo "run liberty-tenant-instance-deploy-python-package finish"