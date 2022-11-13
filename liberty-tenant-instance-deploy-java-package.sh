#!/usr/bin/env bash

ip=$1
tenant=$2
packageUrl=$3
packageName=$(echo "${packageUrl}" | awk -F '/' '{print $NF}')
packageVersion=$4
rootPass=$5

sourc /etc/keystone/$tenant-openrc.sh &> /dev/null
if [ $? -ne 0 ]; then
  echo "{\"result\":\"-1\",\"msg\":\"tenant not exist\"}"
  exit
fi

nova list | grep "ACTIVE" | grep "${ip}" &> /dev/null
if [ $? -ne 0 ]; then
  echo "{{\"result\":\"0\",\"msg\":\"no host ip=${ip}\"}}"
  exit
fi

/usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${rootPass}\r"}
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

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"deploy error\"}"
  exit
fi

echo "{\"result\":\"10\",\"msg\":\"deploy success\"}"
