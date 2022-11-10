#!/usr/bin/env bash

echo "run liberty-tenant-instance-deploy-java-package"

ip=$1
tenant=$2
packageUrl=$3
packageName=$(echo "${packageUrl}" | awk -F '/' '{print $NF}')
packageVersion=$4

sourc /etc/keystone/$tenant-openrc.sh

/usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "000000\r"}
}
expect "root@*" {send "curl -o ${packageName} ${packageUrl} &> /dev/null \r"}
expect "root@*" {send "echo 'FROM Java:8' >> ${packageName}_file_java \r"}
expect "root@*" {send "echo 'COPY ${packageName} /opt/' >> ${packageName}_file_java \r"}
expect "root@*" {send "echo 'CMD [\"java\",\"-jar\",\"/opt/${packageName}\"]' >> ${packageName}_file_java \r"}
expect "root@*" {send "docker build -f ${packageName}_file_java -t ${packageName}:${packageVersion} . &> /dev/null \r"}
expect "root@*" {send "docker run --network host -d ${packageName}:${packageVersion} &> /dev/null \r"}
expect "root@*" {send "exit\r"}
expect eof
FLAGEOF

echo "run liberty-tenant-instance-deploy-java-package finish"