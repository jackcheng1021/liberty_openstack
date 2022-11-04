#!/bin/bash

echo "该脚本在compute节点运行"
echo "liberty-neutron-compute setup"
sleep 5

source liberty-openrc

echo "安装软件"
yum -y install openstack-neutron openstack-neutron-linuxbridge ebtables ipset &> /dev/null
rpm -q openstack-neutron &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron 安装失败"
  exit
fi
rpm -q openstack-neutron-linuxbridge &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron-linuxbridge 安装失败"
  exit
fi
rpm -q ebtables &> /dev/null
if [ $? -ne 0 ]; then
  echo "ebtables 安装失败"
  exit
fi
rpm -q ipset &> /dev/null
if [ $? -ne 0 ]; then
  echo "ipset 安装失败"
  exit
fi

echo "配置参数"
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
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $1
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini agent prevent_arp_spoofing True 
  #启用ARP欺骗防护
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

echo "启动服务"
systemctl restart openstack-nova-compute
if [ $? -ne 0 ]; then
  echo "openstack-nova-compute 重启失败，检查配置"
  exit
fi
systemctl restart neutron-linuxbridge-agent
if [ $? -ne 0 ]; then
  echo "neutron-linuxbridge-agent 重启失败，检查配置"
  exit
else
  systemctl enable neutron-linuxbridge-agent &> /dev/null
fi

echo "liberty-neutron-compute setup finish"
