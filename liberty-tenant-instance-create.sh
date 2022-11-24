#!/bin/bash

if [ $# -eq 0 ]; then
  echo "run liberty-tenant-instance-create"
  echo "default tenant create server"
  source liberty-openrc
  source /etc/keystone/demo-openrc.sh
  
  echo "upload image"
  nova image-list | grep "centos7" &> /dev/null
  if [ $? -ne 0 ]; then
    echo "1: centos7 image not exist, error"
    exit 1
  fi
  
  echo "init secgroup"
  netId=$(neutron net-list | grep "${tenant_network_name}" | awk '{print $2}')
  nova secgroup-delete default &> /dev/null
  nova secgroup-create default default
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
  nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
 
  echo "boot instance"
  nova boot --flavor m1.small --image centos7 --nic net-id=${netId} --security-group default ${tenant_project}-instance-01 &> /dev/null
  if [ $? -ne 0 ]; then
    echo "2: instance boot error"
    exit 2
  fi

  echo "bind floating ip"
  {
    floatingIp=$(neutron floatingip-create wan | grep "floating_ip_address" | awk '{print $4}')
    nova floating-ip-associate ${tenant_project}-instance-01 ${floatingIp}
  }&
  
  if [ $? -ne 0 ]; then
    echo "3: bind floating ip error"
    exit 3
  fi

  echo "config yum in instance"
  content=$(nova list | grep "| ACTIVE |" | grep "${tenant_project}-instance-01")
  if [ $? -eq 0 ]; then
    ip=$(echo "${content}" | awk -F ',' '{print $2}' | xargs | awk '{print $1}')
    /usr/bin/expect <<FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "000000\r"}
}
expect "root@*" {send "sed -i "s#^nameserver .*#nameserver ${public_network_gateway}#g" cat /etc/resolv.conf \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null \r"}
expect "root@*" {send "sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo &> /dev/null \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo &> /dev/null \r"}
expect "root@*" {send "yum makecache &> /dev/null \r"}
expect "root@*" {send "yum -y install iptables-services &> /dev/null \r"}
expect "root@*" {send "systemctl restart iptables \r"}
expect "root@*" {send "systemctl enable iptables \r"}
expect "root@*" {send "iptables -F && iptables -F -t nat && iptables -F -t mangle && iptables -F -t raw \r"}
expect "root@*" {send "services iptables save &> /dev/null \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF
  fi
  if [ $? -ne 0 ]; then
    echo "4: config yum error"
    exit 4
  fi
  echo "run liberty-tenant-instance-create finish"

elif [ $# -eq 3 ]; then

  tenant=$1 #租户名
  instanceName=$2 #实例名
  instanceType=$3 #云主机类型, 1:small 2: medium 3: large

  source /etc/keystone/${tenant}-openrc.sh || (echo "{\"result\":\"-1\",\"msg\":\"tenant not exist\"}"; exit) # -1: 没有该租户
  {
    nova image-list | grep "centos7" &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    #0: 没有镜像
    echo "{\"result\":\"0\",\"msg\":\"no centos7 image\"}"
    exit
  fi

  netId=$(neutron net-list | grep "${OS_TENANT_NAME}" | awk '{print $2}')

  {
    if [ ${instanceType} -eq 1 ]; then
      nova boot --flavor m1.small --image centos7 --nic net-id=${netId} --security-group default ${instanceName} &> /dev/null
    elif [ ${instanceType} -eq 2 ]; then
      nova boot --flavor m1.medium --image centos7 --nic net-id=${netId} --security-group default ${instanceName} &> /dev/null
    elif [ ${instanceType} -eq 3 ]; then
      nova boot --flavor m1.large --image centos7 --nic net-id=${netId} --security-group default ${instanceName} &> /dev/null
    else
      #1: 参数不对
      echo "{\"result\":\"1\",\"msg\":\"parameter error\"}"
      exit
    fi
  }&
  wait
  if [ $? -ne 0 ]; then
    #2: 启动云主机出错
    echo "{\"result\":\"2\",\"msg\":\"boot error\"}"
  fi

  {
    floatingIp=$(neutron floatingip-create wan | grep "floating_ip_address" | awk '{print $4}')
    nova floating-ip-associate  ${floatingIp}
  }&
  wait
  if [ $? -ne 0 ]; then
    #3: 绑定浮动ip出错
    echo "{\"result\":\"3\",\"msg\":\"floatingIp error\"}"
    exit
  fi

  content=$(nova list | grep "| ACTIVE |" | grep "${instanceName}")
  ip=""
  if [ $? -eq 0 ]; then
    ip=$(echo "${content}" | awk -F ',' '{print $2}' | xargs | awk '{print $1}')
    /usr/bin/expect <<FLAGEOF
set timeout 600
spawn ssh root@$ip
expect {
        "(yes/no)" {send "yes\r"; exp_continue}
        "password:" {send "000000\r"}
}
expect "root@*" {send "sed -i "s#^nameserver .*#nameserver ${public_network_gateway}#g" cat /etc/resolv.conf \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null \r"}
expect "root@*" {send "sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo &> /dev/null \r"}
expect "root@*" {send "curl -o /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo &> /dev/null \r"}
expect "root@*" {send "yum makecache &> /dev/null \r"}
expect "root@*" {send "yum -y install iptables-services &> /dev/null \r"}
expect "root@*" {send "systemctl restart iptables \r"}
expect "root@*" {send "systemctl enable iptables \r"}
expect "root@*" {send "iptables -F && iptables -F -t nat && iptables -F -t mangle && iptables -F -t raw \r"}
expect "root@*" {send "services iptables save &> /dev/null \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF
  fi
  if [ $? -ne 0 ]; then
    echo "echo {\"result\":\"4\",\"msg\": \"config yum error\"}"
    exit
  fi

  echo "{\"result\":\"10\",\"msg\":\"{\"hostIp\":\"${ip}\",\"hostRoot\":\"root\",\"hostPass\":\"000000\"}\"}"

else
  echo "4:parameter count error" #参数数量有误
  exit
fi
