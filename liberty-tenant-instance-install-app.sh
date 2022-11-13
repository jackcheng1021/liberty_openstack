#!/usr/bin/env bash

ip=$1
tenant=$2
instancePass=$3
app=$4 #要安装的软件

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
        "password:" {send "${instancePass}\r"}
}
expect "root@*" {send "yum -y install ${app} &> /dev/null \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"app install error\"}" #安装软件报错
  exit
fi

echo "{\"result\":\"10\",\"msg\":\"app install success\"}"