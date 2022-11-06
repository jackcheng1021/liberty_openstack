#!/bin/bash

echo "$(hostname): setup liberty-neutron-compute"

source liberty-openrc

echo "install application"
yum -y install openstack-neutron openstack-neutron-linuxbridge ebtables ipset &> /dev/null
rpm -q openstack-neutron &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron installed error"
  exit
fi
rpm -q openstack-neutron-linuxbridge &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron-linuxbridge installed error"
  exit
fi
rpm -q ebtables &> /dev/null
if [ $? -ne 0 ]; then
  echo "ebtables installed error"
  exit
fi
rpm -q ipset &> /dev/null
if [ $? -ne 0 ]; then
  echo "ipset installed error"
  exit
fi

echo "config parameter"
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit   
  #配置RabbitMQ消息队列访问
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
  #配置认证服务访问 在 [keystone_authtoken] 中注释或者删除其他选项。
openstack-config --set /etc/neutron/neutron.conf DEFAULT verbose True
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username ${neutron_user_admin}
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password ${neutron_user_admin_pass}
  #keystone身份认证
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp  
  #配置锁路径
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}
  #配置RabbitMQ消息队列访问
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings ${public_network_name}:${public_network_interface}  
  #映射公共虚拟网络到公共物理网络接口
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan True
ip=$(grep "$(hostname)" /etc/hosts | awk '{print $1}')
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip ${ip}
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini agent prevent_arp_spoofing True 
  #启用ARP欺骗防护
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

echo "boot service"
systemctl restart openstack-nova-compute
if [ $? -ne 0 ]; then
  echo "service openstack-nova-compute restart error, check parameter"
  exit
fi
systemctl restart neutron-linuxbridge-agent
if [ $? -ne 0 ]; then
  echo "service neutron-linuxbridge-agent restart error, check parameter"
  exit
else
  systemctl enable neutron-linuxbridge-agent &> /dev/null
fi

echo "$(hostname): setup liberty-neutron-compute finish"
