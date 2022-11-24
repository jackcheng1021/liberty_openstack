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
expect "root@*" {send "rpm -q iptables-services || (yum -y install iptables-services; systemctl restart iptables; systemctl enable iptables) \r"}
expect "root@*" {send "iptables -F && iptables -F -t nat && iptables -F -t mangle && iptables -F -t raw; service iptables save &> /dev/null \r"}
expect "root@*" {send "yum -y install docker-ce-19.03.1 &> /dev/null \r"}
expect "root@*" {send "yum -y install java-1.8.0-openjdk &> /dev/null \r"}
expect "root@*" {send "yum -y install python3 &> /dev/null \r"}
expect "root@*" {send "mkdir -p /etc/docker \r"}
expect "root@*" {send "[ -f /etc/docker/daemon.json ] && rm -f /etc/docker/daemon.json \r"}
expect "root@*" {send "echo \"{\" >> /etc/docker/daemon.json  \r"}
expect "root@*" {send "echo '\"registry-mirrors\": [\"https://idoamkgf.mirror.aliyuncs.com\"],' >> /etc/docker/daemon.json \r"}
expect "root@*" {send "echo '\"exec-opts\": [\"native.cgroupdriver=systemd\"]' >> /etc/docker/daemon.json \r"}
expect "root@*" {send "echo \"}\" >> /etc/docker/daemon.json \r"}
expect "root@*" {send "systemctl daemon-reload \r"}
expect "root@*" {send "systemctl restart docker \r"}
expect "root@*" {send "systemctl enable docker &> /dev/null \r"}
expect "root@*" {send "docker images | grep \"mysql:5.7\" || docker pull mysql:5.7 &> /dev/null \r"}
expect "root@*" {send "docker images | grep \"redis\" || docker pull redis:latest &> /dev/null \r"}
expect "root@*" {send "docker images | grep \"tomcat:8\" || docker pull tomcat:8" &> /dev/null \r"}
expect "root@*" {send "docker ps | grep \"mysql\" || docker run --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Welcome_1 -d mysql:5.7 &> /dev/null \r"}
expect "root@*" {send "docker ps | grep \"redis\" || docker run --name redis -p 6379:6379 -d redis:latest &> /dev/null \r"}
expect "root@*" {send "docker ps | grep \"tomcat\" || docker run --name tomcat -p 8080:8080 -d tomcat:8 &> /dev/null \r"}
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