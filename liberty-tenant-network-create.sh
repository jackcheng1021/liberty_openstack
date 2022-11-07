#!/bin/bash

echo "run liberty-tenant-network-create"
if [ $# -eq 0 ]; then
  source liberty-openrc
  source /etc/keystone/admin-openrc.sh

  neutron net-show ${public_network_name} &> /dev/null
  if [ $? -ne 0 ]; then  #公共网络不存在

    echo "create public net: ${public_network_name}"
    neutron net-create --shared --provider:physical_network ${public_network_name} --provider:network_type flat ${public_network_name} &> /dev/null
    if [ $? -ne 0 ]; then
      echo "public net: ${public_network_name} created error"
      exit
    fi

    echo "create public subnet: sub${public_network_name}"
    ip=$(echo ${public_network_cidr%.*})
    neutron subnet-create ${public_network_name} ${public_network_cidr} --name sub${public_network_name} --allocation-pool start=${ip}.101,end=${ip}.199 --dns-nameserver ${dns_ip} --gateway ${public_network_gateway}
    if [ $? -ne 0 ]; then
      echo "public subnet: sub${public_network_name} created error"
      exit
    fi
    
  fi

  neutron net-show ${tenant_network_name} &> /dev/null
  if [ $? -ne 0 ]; then #租户网络不存在
    
    echo "create tenant net: ${tenant_network_name}"
    source /etc/keystone/demo-openrc.sh
    neutron net-create ${tenant_network_name} &> /dev/null
    if [ $? -ne 0 ]; then
      echo "tenant net: ${tenant_network_name} created error"
      exit
    fi

    echo "create tenant subnet: sub${tenant_network_name}"
    neutron subnet-create ${tenant_network_name} ${tenant_network_cidr} --name sub${tenant_network_name} --dns-nameserver ${dns_ip} --gateway ${tenant_network_gateway}
    if [ $? -ne 0 ]; then
      echo "tenant subnet: sub${tenant_network_name} created error"
      exit
    fi
        
  fi

  echo "set ${public_network_name} external net"
  source /etc/keystone/admin-openrc.sh
  neutron net-update ${public_network_name} --router:external &> /dev/null
  if [ $? -ne 0 ]; then
    echo "set ${public_network_name} external net error"
    exit
  fi
  
  echo "create tenant router"
  source /etc/keystone/demo-openrc.sh
  neutron router-create router_${tenant_project} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create tenant router: router_${tenant_project} error"
    exit
  fi

  echo "tenant subnet: sub${tenant_network_name}  connect router: router_${tenant_project}"
  neutron router-interface-add router_${tenant_project} sub${tenant_network_name} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "tenant subnet: sub${tenant_network_name}  connect router: router_${tenant_project} error"
    exit
  fi
  
  echo "public net: ${public_network_name} connect router: router_${tenant_project}"
  neutron router-gateway-set router_${tenant_project} ${public_network_name} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "public subnet: sub${public_network_name} connect router: router_${tenant_project} error"
    exit
  fi

else

  tenant=$1
  tenant_net=$2
  tenant_net_cidr=$3
  tenant_net_gateway=$4
  timestamp=$(echo $[$(date +%s%N)/1000000])
  tenant_subnet=$(echo "sub_$2_$tenant_subnet")
  
  neutron net-show ${tenant_net} &> /dev/null
  if [ $? -ne 0 ]; then #租户网络不存在
    
    echo "create tenant net: ${tenant_net}"
    source /etc/keystone/${tenant}-openrc.sh &> /dev/null
    if [ $? -ne 0 ]; then
      echo "tenant: ${tenant} not exist, error"
      exit
    fi
    neutron net-create ${tenant} &> /dev/null
    if [ $? -ne 0 ]; then
      echo "tenant net: ${tenant_network_name} created error"
      exit
    fi

    echo "create tenant subnet: ${tenant_subnet}"
    neutron subnet-create ${tenant_net} ${tenant_net_cidr} --name ${tenant_subnet} --dns-nameserver ${dns_ip} --gateway ${tenant_net_gateway}
    if [ $? -ne 0 ]; then
      echo "tenant subnet: ${tenant_subnet} created error"
      exit
    fi
        
  fi
  
  echo "create tenant router"
  source /etc/keystone/${tenant}-openrc.sh
  neutron router-create router_${tenant} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create tenant router: router_${tenant} error"
    exit
  fi

  echo "tenant subnet: ${tenant_subnet} connect router: router_${tenant}"
  neutron router-interface-add router_${tenant} ${tenant_subnet} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "tenant subnet: ${tenant_subnet}  connect router: router_${tenant} error"
    exit
  fi
  
  echo "public net: ${public_network_name} connect router: router_${tenant}"
  neutron router-gateway-set router_${tenant} ${public_network_name} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "public subnet: sub${public_network_name} connect router: router_${tenant} error"
    exit
  fi  
  
fi

echo "run liberty-tenant-network-create finish"