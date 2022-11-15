#!/usr/bin/env bash

ip=$1
tenant=$2
gitUser=$3
gitPass=$4
gitRepo=$5

source /etc/keystone/${tenant}-openrc.sh &> /dev/null
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
spawn ssh ${gitUser}@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${gitPass}\r"}
}
expect "${gitUser}@*" {send "[ -d ${gitRepo}.git ] && rm -rf ${gitRepo}.git \r"}
expect "${gitUser}@*" {send "mkdir ${gitRepo}.git; cd ${gitRepo}.git \r"}
expect "${gitUser}@*" {send "git init --bare &> /dev/null \r"}
expect "${gitUser}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"deploy git repo error\"}"
  exit
fi

echo echo "{\"result\":\"10\",\"msg\":\"deploy git repo success\"}"