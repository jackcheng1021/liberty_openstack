#!/bin/bash

echo "$(hostname): setup liberty-neutron-controller"

source liberty-openrc
source /etc/keystone/admin-openrc.sh

echo "config neutron database"
mysql -uroot -p"$mysql_pass" -e "show databases;" | grep "neutron" &> /dev/null
if [ $? -eq 0 ]; then
  mysql -uroot -p"$mysql_pass" -e "drop database neutron;"
fi
mysql -uroot -p"$mysql_pass" -e "create database neutron;"

mysql -uroot -p"$mysql_pass"  -e "use neutron;grant all privileges on neutron.* to '$mysql_neutron_user'@'localhost' identified by '$mysql_neutron_pass';"

mysql -uroot -p"$mysql_pass"  -e "use neutron;grant all privileges on neutron.* to '$mysql_neutron_user'@'%' identified by '$mysql_neutron_pass';"

echo "create neutron admin"
openstack user create --domain default --password ${neutron_user_admin_pass} ${neutron_user_admin} &> /dev/null
if [ $? -ne 0 ]; then
  echo "create neutron user admin error"
  exit
fi
openstack role add --project service --user ${neutron_user_admin} admin &> /dev/null
if [ $? -ne 0 ]; then
  echo "neutron user admin bind role error"
  exit
fi

echo "create neutron service"
openstack service create --name neutron --description "OpenStack Networking" network &> /dev/null
if [ $? -ne 0 ]; then
  echo "service neutron created error"
  exit
fi
openstack endpoint create --region RegionOne network public http://controller:9696 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service neutron add endpoint public error"
  exit
fi
openstack endpoint create --region RegionOne network internal http://controller:9696 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service neutron add endpoint internal error"
  exit
fi
openstack endpoint create --region RegionOne network admin http://controller:9696 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service neutron add endpoint admin error"
  exit
fi

echo "install application"
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge python-neutronclient ebtables ipset &> /dev/null

rpm -q openstack-neutron &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron installed error"
  exit
fi

rpm -q openstack-neutron-ml2 &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron-ml2 installed error"
  exit
fi

rpm -q openstack-neutron-linuxbridge &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-neutron-linuxbridge installed error"
  exit
fi

rpm -q python-neutronclient &> /dev/null
if [ $? -ne 0 ]; then 
  echo "python-neutronclient installed error"
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
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
  #??????Layer 2 (ML2)???????????????????????????????????????IP??????
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit 
  #?????? "RabbitMQ" ??????????????????
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone 
  #????????????????????????
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
  #???????????????????????????????????????????????????
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://controller:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT verbose True 
  #??????????????????
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken uth_uri http://controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username ${neutron_user_admin}
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password ${neutron_user_admin_pass}
  #keystone???????????????
openstack-config --set /etc/neutron/neutron.conf database connection mysql://${mysql_neutron_user}:${mysql_neutron_pass}@controller/neutron  
  #?????????????????????
openstack-config --set /etc/neutron/neutron.conf nova auth_url http://controller:35357
openstack-config --set /etc/neutron/neutron.conf nova auth_plugin password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name service
openstack-config --set /etc/neutron/neutron.conf nova username ${nova_user_admin}
openstack-config --set /etc/neutron/neutron.conf nova password ${nova_user_admin_pass}
  #neutron??????????????????nova????????????????????????????????????nova???????????????????????????
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp 
  #???????????????
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}
  #??????rabbit???????????????
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,vxlan 
  #??????flat???VLAN???VXLAN??????
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vxlan 
  #??????VXLAN????????????????????????  Linux?????????????????????VXLAN?????????
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers linuxbridge,l2population 
  #??????Linux ?????????layer-2 population mechanisms
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security 
  #??????????????????????????????
  #??????????????????
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks ${public_network_name} 
  #????????????flat????????????
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000 
  #??????VXLAN???????????????????????????????????????
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True 
  #?????? ipset ???????????????????????????
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings ${public_network_name}:${public_network_interface} 
  #???????????????????????????????????????????????????
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip ${controller_ip}
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini agent prevent_arp_spoofing True 
  #??????ARP????????????
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
  #???????????????????????? Linux ?????? iptables ???????????????
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge     
  #???????????????????????????????????????????????????????????????????????????
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT verbose True 
  #??????????????????
  #??????3?????????
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT verbose True
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf
  #????????????IP???????????????
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
  #?????????????????????
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret ${secret_pass}
  #?????????????????????????????????????????????

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT verbose True
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name %SERVICE_TENANT_NAME%
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_user %SERVICE_USER%
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT admin_password %SERVICE_PASSWORD%
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

echo "sync neutron database"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron &> /dev/null
n=$(mysql -u${mysql_neutron_user} -p${mysql_neutron_pass} -e "use neutron;show tables;" | wc -l)
if [ $n -eq 0 ]; then
  echo "sync neutron database error"
  exit
fi

echo "boot service"
systemctl restart openstack-nova-api  #??????nova??????nova????????????
if [ $? -ne 0 ]; then
  echo "service openstack-nova-api restart error"
  exit
fi
#????????????????????????????????????????????????(?????????????????????)
systemctl restart neutron-server
if [ $? -ne 0 ]; then
  echo "service neutron-server restart error"
  exit
fi
systemctl restart neutron-linuxbridge-agent
if [ $? -ne 0 ]; then
  echo "service neutron-linuxbridge-agent restart error"
  exit
fi
systemctl restart neutron-dhcp-agent
if [ $? -ne 0 ]; then
  echo "service neutron-dhcp-agent restart error"
  exit
fi
systemctl restart neutron-metadata-agent
if [ $? -ne 0 ]; then
  echo "service neutron-metadata-agent restart error"
  exit
fi
systemctl enable neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent &> /dev/null
#???????????????2-3????????????????????????????????????layer-3?????????
systemctl restart neutron-l3-agent
if [ $? -ne 0 ]; then
  echo "service neutron-l3-agent restart error"
  exit
fi
systemctl enable neutron-l3-agent &>/dev/null

echo "$(hostname): setup liberty-neutron-controller finish"
