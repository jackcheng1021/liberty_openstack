#!/usr/bin/env bash


ip=$1
pass=$2
tenant=$3

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
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "${pass}\r"}
}
expect "root@*" {send "curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null \r"}
expect "root@*" {send "sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo &> /dev/null \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo &> /dev/null \r"}
expect "root@*" {send "yum makecache &> /dev/null \r"}
expect "root@*" {send "yum -y install docker-ce &> /dev/null \r"}
expect "root@*" {send "yum -y install java-1.8.0-openjdk &> /dev/null \r"}
expect "root@*" {send "yum -y install python3 &> /dev/null \r"}
expect "root@*" {send "mkdir -p /etc/docker \r"}
expect "root@*" {send "echo '{\"registry-mirrors\": [\"https://idoamkgf.mirror.aliyuncs.com\"]}' > /etc/docker/daemon.json \r"}
expect "root@*" {send "systemctl daemon-reload \r"}
expect "root@*" {send "systemctl restart docker-ce \r"}
expect "root@*" {send "systemctl enable docker-ce &> /dev/null \r"}
expect "root@*" {send "docker pull mysql:5.7 &> /dev/null \r"}
expect "root@*" {send "docker pull redis:latest &> /dev/null \r"}
expect "root@*" {send "docker pull tomcat:8" &> /dev/null \r"}
expect "root@*" {send "docker run --name mysql --network host -e MYSQL_ROOT_PASSWORD=Welcome_1 -d mysql:5.7 &> /dev/null \r"}
expect "root@*" {send "docker run --name redis --network host -d redis:latest &> /dev/null \r"}
expect "root@*" {send "docker run --name tomcat --network host -d tomcat:8 &> /dev/null \r"}
expect "root@*" {send "docker exec -it tomcat /bin/bash \r"}
expect "root@*" {send "cp -r webapps.dist/* webapps/ \r"}
expect "root@*" {send "exit\r"}
expect "root@*" {send "exit\r"}
expect eof
FLAGEOF

if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":instance error}"
  exit
fi

echo "{\"result\":\"10\",\"msg\":{\"mysql\":{\"name\":\"mysql\",\"port\":\"3306\",\"pass\":\"Welcome_1\"},\"redis\":{\"name\":\"redis\",\"port\":\"6379\"},\"tomcat\":{\"name\":\"tomcat\",\"port\":\"8080\"}}}"