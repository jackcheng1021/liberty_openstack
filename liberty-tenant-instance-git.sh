#!/usr/bin/env bash

ip=$1
pass=$2
tenant=$3
gitUser=$4
gitPass=$5

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
        "password:" {send "${pass}\r"}
}
expect "root@*" {send "rpm -q git &> /dev/null || (yum -y install git &> /dev/null) \r"}
export "root@*" {send "useradd ${gitUser} \r"}
export "root@*" {send "echo "${gitPass}" | passwd --stdin ${gitUser} \r"}
#export "root@*" {send "echo "su - ${gitUser} \r"}
#expect "${gitUser}@*" {send "[ -d ${gitRepo} ] && rm -rf ${gitRepo} \r"}
#expect "${gitUser}@*" {send "mkdir ${gitRepo}; cd ${gitRepo} \r"}
#expect "${gitUser}@*" {send "git init --bare &> /dev/null \r"}
expect "root@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"deploy git error\"}"
  exit
fi

echo echo "{\"result\":\"10\",\"msg\":\"deploy git success\"}"