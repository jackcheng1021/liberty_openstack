#!/bin/bash

ip=$1  #git git-repo  git-repo-package 都在同一台云主机上
tenant=$2
gitUser=$3
gitPass=$4
gitRepo=$5 #gitRepo=my_project
gitRepoVersion=$6 #当前即将打包的版本号，开发人员传入 假设 gitRepoVersion=0.1
packageName=$7 #要打包的包名，开发人员传入 packageName=demo

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
expect "${gitUser}@*" {send "[ -d ${gitRepo}-${gitRepoVersion} ] && rm -rf ${gitRepo}-${gitRepoVersion} \r"}
expect "${gitUser}@*" {send "mkdir -p ${gitRepo}-${gitRepoVersion} \r"}
expect "${gitUser}@*" {send "cd ${gitRepo}-${gitRepoVersion} \r"}
expect "${gitUser}@*" {send "git clone git@localhost:/${gitUser}/${gitRepo}.git \r"}
expect "${gitUser}@*" {send "cd ${gitRepo}-${gitRepoVersion}/${gitRepo}/ \r"}
expect "${gitUser}@*" {send "mvn clean install -Dmaven.test.skip=true &> /dev/null \r"}
expect "${gitUser}@*" {send "cd target/ \r"}
expect "${gitUser}@*" {send "mv ${gitRepo}-*.jar /opt/${packageName}-${gitRepoVersion}.jar \r"}
expect "${gitUser}@*" {send "exit &> /dev/null \r"}
expect eof
FLAGEOF

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"deploy git repo error\"}"
  exit
fi

echo "{\"result\":\"10\",\"msg\":{\"packageUrl\":\"ftp://${ip}/${packageName}-${gitRepoVersion}.jar \"}}"