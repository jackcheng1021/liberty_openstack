#!/usr/bin/env bash

ip=$1
pass=$2
instanceName=$3

echo "start prepare server for dev"

/usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "$pass\r"}
}
expect "${instanceName}@*" {send "curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null \r"}
expect "${instanceName}@*" {send "sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo \r"}
expect "${instanceName}" {send "curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo &> /dev/null \r"}
expect "${instanceName}" {send "curl -o /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo &> /dev/null \r"}
expect "${instanceName}" {send "yum makecache &> /dev/null \r"}
expect "${instanceName}" {send "yum -y install docker-ce &> /dev/null \r"}
expect "${instanceName}" {send "yum -y install java-1.8.0-openjdk &> /dev/null \r"}
expect "${instanceName}" {send "yum -y install python3 &> /dev/null \r"}
expect "${instanceName}" {send "mkdir -p /etc/docker \r"}
expect "${instanceName}" {send "echo '{\"registry-mirrors\": [\"https://idoamkgf.mirror.aliyuncs.com\"]}' > /etc/docker/daemon.json \r"}
expect "${instanceName}" {send "systemctl daemon-reload \r"}
expect "${instanceName}" {send "systecmtl restart docker-ce \r"}
expect "${instanceName}" {send "systecmtl enable docker-ce &> /dev/null \r"}
expect "${instanceName}" {send "docker pull mysql:5.7 &> /dev/null \r"}
expect "${instanceName}" {send "docker pull redis:latest &> /dev/null \r"}
expect "${instanceName}" {send "docker pull tomcat:8" &> /dev/null \r"}
expect "${instanceName}" {send "docker run --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Welcome_1 -d mysql:5.7 &> /dev/null \r"}
expect "${instanceName}" {send "docker run --name redis -p 6379:6379 -d redis:latest &> /dev/null \r"}
expect "${instanceName}" {send "docker run --name tomcat -p 8080:8080 -d tomcat:8 &> /dev/null \r"}
expect "${instanceName}" {send "exit\r"}
expect eof
FLAGEOF

echo "start prepare instance for dev finish"