#!/bin/bash

ip=$1
gitUser=$2
gitPass=$3
gitRepo=$4
gitRepoVersion=$5
packageName=$6

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
expect "${gitUser}@*" {send "[ -d  ${gitRepo}-${gitRepoVersion} ] && rm -rf ${gitRepo}-${gitRepoVersion} \r"}
expect "${gitUser}@*" {send "mkdir -p ${gitRepo}-${gitRepoVersion} \r"}
expect "${gitUser}@*" {send "cd ${gitRepo}-${gitRepoVersion} \r"}
expect "${gitUser}@*" {send "git clone git@localhost:/${gitUser}/${gitRepo}.git \r"}
expect "${gitUser}@*" {send "cd ${gitRepo}-${gitRepoVersion}/${gitRepo}/ \r"}
expect "${gitUser}@*" {send "mvn clean install -Dmaven.test.skip=true &> /dev/null \r"}
expect "${gitUser}@*" {send "cd target/ \r"}
expect "${gitUser}@*" {send "mv ${gitRepo}-${gitRepoVersion}.jar /opt/${packageName}-${gitRepoVersion}.jar \r"}
expect "${gitUser}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"deploy git repo error\"}"
  exit
fi

echo echo "{\"result\":\"10\",\"msg\":{\"packageUrl\":\"ftp://${ip}/${packageName}-${gitRepoVersion}.jar \"}}"