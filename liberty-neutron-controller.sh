#!/bin/bash

echo "该脚本在controller节点运行"
echo "liberty-neutron-controller 开始配置"
sleep 5

source liberty-openrc.sh
source /etc/keystone/admin-openrc.sh

echo "配置数据库 neutron"
mysql -uroot -p"$mysql_pass" -e "show databases;" | grep "neutron" &> /dev/null
if [ $? -eq 0 ]; then
  #系统中存在nova库
  mysql -uroot -p"$mysql_pass" -e "drop database neutron;"
fi
mysql -uroot -p"$mysql_pass" -e "create database neutron;"

mysql -uroot -p"$mysql_pass"  -e "use neutron;grant all privileges on neutron.* to '$mysql_neutron_user'@'localhost' identified by '$mysql_neutron_pass';"

mysql -uroot -p"$mysql_pass"  -e "use neutron;grant all privileges on neutron.* to '$mysql_neutron_user'@'%' identified by '$mysql_neutron_pass';"

echo "创建neutron管理员"
openstack user create --domain default --password ${neutron_user_admin_pass} ${neutron_user_admin} &> /dev/null
if [ $? -ne 0 ]; then
  echo "创建neutron管理员失败"
  exit
fi
openstack role add --project service --user ${neutron_user_admin} admin &> /dev/null
if [ $? -ne 0 ]; then
  echo "neutron用户分配为管理员失败"
  exit
fi

echo "创建用于身份认证的neutron服务"
openstack service create --name neutron --description "OpenStack Networking" network &> /dev/null
if [ $? -ne 0 ]; then
  echo "创建 neutron service 失败"
  exit
fi
openstack endpoint create --region RegionOne network public http://controller:9696 &> /dev/null
if [ $? -ne 0 ]; then
  echo "neutron service public endpoint 失败"
  exit
fi
openstack endpoint create --region RegionOne network internal http://controller:9696 &> /dev/null
if [ $? -ne 0 ]; then
  echo "neutron service internal endpoint 失败"
  exit
fi
openstack endpoint create --region RegionOne network admin http://controller:9696 &> /dev/null
if [ $? -ne 0 ]; then
  echo "neutron service admin endpoint 失败"
  exit
fi

echo "安装软件"
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge python-neutronclient ebtables ipset &> /dev/null

rpm -q openstack-neutron &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron 安装失败"
  exit
fi

rpm -q openstack-neutron-ml2 &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron-ml2 安装失败"
  exit
fi

rpm -q openstack-neutron-linuxbridge &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron-linuxbridge 安装失败"
  exit
fi

rpm -q python-neutronclient &> /dev/null
if [ $? -ne 0 ]; then 
  echo "python-neutronclient 安装失败"
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
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
  #启用Layer 2 (ML2)插件模块，路由服务和重叠的IP地址
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit 
  #配置 "RabbitMQ" 消息队列访问
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone 
  #配置认证服务访问
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
  #配置网络以能够反映计算网络拓扑变化
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://controller:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT verbose True 
  #启用详细日志
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken uth_uri http://controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username ${neutron_user_admin}
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password ${neutron_user_admin_pass}
  #keystone的认证信息
openstack-config --set /etc/neutron/neutron.conf database connection mysql://${mysql_neutron_user}:${mysql_neutron_pass}@controller/neutron  
  #配置数据库访问
openstack-config --set /etc/neutron/neutron.conf nova auth_url http://controller:35357
openstack-config --set /etc/neutron/neutron.conf nova auth_plugin password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name service
openstack-config --set /etc/neutron/neutron.conf nova username ${nova_user_admin}
openstack-config --set /etc/neutron/neutron.conf nova password ${nova_user_admin_pass}
  #neutron同样需要拥有nova的身份认证信息，才能调用nova去请求计算网络拓扑
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp 
  #配置锁路径
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}
  #配置rabbit的访问账户
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan 
  #启用flat，VLAN和VXLAN网络
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan 
  #启用VXLAN项目（私有）网络  Linux桥接代理只支持VXLAN网络。
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population 
  #启用Linux 桥接和layer-2 population mechanisms
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security 
  #启用端口安全扩展驱动
  #配置二层网络
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks ${public_network_name} 
  #配置公共flat提供网络
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000 
  #配置VXLAN网络标识范围与私有网络不同
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True 
  #启用 ipset 增加安全组的方便性
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings ${public_network_name}:${public_network_interface} 
  #映射公共虚拟网络到公共物理网络接口
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip ${controller_ip}
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini agent prevent_arp_spoofing True 
  #启用ARP欺骗防护
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
  #启用安全组并配置 Linux 桥接 iptables 防火墙驱动
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge     
  #故意缺少值，这样就可以在一个代理上启用多个外部网络
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT verbose True 
  #启用详细日志
  #配置3层网络
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT verbose True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
  #自动分配IP的代理服务
echo "dhcp-option-force=26,1450" > /etc/neutron/dnsmasq-neutron.conf

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_uri http://controller:5000
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://controller:35357
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region RegionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_plugin password
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT project_domain_id default
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT user_domain_id default
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT project_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT username ${mysql_neutron_user}
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT password ${mysql_neutron_pass}
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller 
  #配置元数据主机
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret ${secret_pass}
  #配置元数据代理共享密码，自定义

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT verbose True
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name %SERVICE_TENANT_NAME%
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user %SERVICE_USER%
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password %SERVICE_PASSWORD%
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

echo "同步数据库"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron &> /dev/null
n=$(mysql -u${mysql_neutron_user} -p${mysql_neutron_pass} -e "use neutron;show tables;" | wc -l)
if [ $n -eq 0 ]; then
  echo "数据库同步失败，请检查配置"
  exit
fi

echo "启动neutron服务"
systemctl restart openstack-nova-api  #重启nova，使nova配置生效
if [ $? -ne 0 ]; then
  echo "openstack-nova-api重启失败,检查配置"
fi
#启动网络服务并配置他们开机自启动(对所有网络选项)
systemctl restart neutron-server
if [ $? -ne 0 ]; then
  echo "neutron-server 重启失败,检查配置"
  exit
fi
systemctl restart neutron-linuxbridge-agent
if [ $? -ne 0 ]; then
  echo "neutron-linuxbridge-agent 重启失败,检查配置"
  exit
fi
systemctl restart neutron-dhcp-agent
if [ $? -ne 0 ]; then
  echo "neutron-dhcp-agent 重启失败,检查配置"
  exit
fi
systemctl restart neutron-metadata-agent
if [ $? -ne 0 ]; then
  echo "neutron-metadata-agent 重启失败,检查配置"
  exit
fi
systemctl enable neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent &> /dev/null
#对网络选项2-3层网络，同样也启用并启动layer-3服务：
systemctl restart neutron-l3-agent
if [ $? -ne 0 ]; then
  echo "neutron-l3-agent 重启失败,检查配置"
  exit
fi
systemctl enable neutron-l3-agent &>/dev/null

echo "liberty-neutron-controller setup finish"
