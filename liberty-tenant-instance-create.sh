#!/bin/bash

echo "run liberty-tenant-instance-create"

if [ $# -eq 0 ]; then

  echo "default tenant create server"
  source liberty-openrc
  source /etc/keystone/demo-openrc.sh
  
  echo "upload image"
  {
    nova image-list | grep "centos7" &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "centos7 image not exist, error"
    exit
  fi
  
  echo "init secgroup"
  netId=$(neutron net-list | grep "${tenant_network_name}" | awk '{print $2}')
  nova secgroup-delete default &> /dev/null
  nova secgroup-create default default
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
  nova secgroup-add-rule default udp 1 65535 0.0.0.0/0
 
  echo "boot instance"
  {
    nova boot --flavor m1.small --image centos7 --nic net-id=${netId} --security-group default ${tenant_project}-instance-01 &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "instance boot error"
  fi

  echo "bind floating ip"
  {
    floatingIp=$(neutron floatingip-create wan | grep "floating_ip_address" | awk '{print $4}')
    nova floating-ip-associate ${tenant_project}-instance-01 ${floatingIp}
  }&
  
  if [ $? -ne 0 ]; then
    echo "bind floating ip error"
  fi
  
  echo "instance list"
  nova list

elif [ $# -eq 2 ]; then #默认租户创建新实例  $1 instanceName 用途 $2 usage dev:开发 test:测试

  echo "default tenant create custom instance"
  source /etc/keystone/demo-openrc.sh
  
  echo "upload image"
  {
    nova image-list | grep "centos7" &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "centos7 image not exist, error"
    exit
  fi
  
  netId=$(neutron net-list | grep "${OS_TENANT_NAME}" | awk '{print $2}')
 
  echo "boot instance"
  {
    instanceId=${RANDOM}
    nova boot --flavor m1.small --image centos7 --nic net-id=${netId} --security-group default $1-${instanceId} &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "instance boot error"
  fi

  echo "bind floating ip"
  {
    floatingIp=$(neutron floatingip-create wan | grep "floating_ip_address" | awk '{print $4}')
    nova floating-ip-associate  ${floatingIp}
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "bind floating ip error"
  fi
  
  echo "instance list"
  nova list

  if [ "$2" == "dev" ]; then
    #instance use for dev
    liberty-tenant-instance-dev ${floatingIp} 000000 $1-${instanceId}
  elif [ "$2" == "test" ]; then
    #instance use for test
    liberty-tenant-instance-test ${floatingIp} 000000 $1-${instanceId}
  fi


elif [ $# -eq 3 ]; then

  tenant=$1 #租户名
  instanceName=$2 #实例名
  usage=$3 #用途 dev:开发 test:测试
  echo "custom tenant: ${tenant} create custom instance: ${instanceName}"
  source /etc/keystone/${tenant}-openrc.sh || (echo "tenant: ${tenant} not exist, error"; exit)
  echo "upload image"
  {
    nova image-list | grep "centos7" &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "centos7 image not exist, error"
    exit
  fi

  netId=$(neutron net-list | grep "${OS_TENANT_NAME}" | awk '{print $2}')

  echo "boot instance"
  {
    instanceId=${RANDOM}
    nova boot --flavor m1.small --image centos7 --nic net-id=${netId} --security-group default ${instanceName}-${instanceId} &> /dev/null
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "instance boot error"
  fi

  echo "bind floating ip"
  {
    floatingIp=$(neutron floatingip-create wan | grep "floating_ip_address" | awk '{print $4}')
    nova floating-ip-associate  ${floatingIp}
  }&
  wait
  if [ $? -ne 0 ]; then
    echo "bind floating ip error"
  fi

  echo "instance list"
  nova list

  if [ "$usage" == "dev" ]; then
    #instance use for dev
    liberty-tenant-instance-dev ${floatingIp} 000000 $1-${instanceId}
  elif [ "$usage" == "test" ]; then
    #instance use for test
    liberty-tenant-instance-test ${floatingIp} 000000 $1-${instanceId}
  fi

else
  echo "script parameters error"
  exit
fi

echo "run liberty-tenant-instance-create finish"
