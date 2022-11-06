#!/bin/bash

echo "$(hostname): setup liberty-nova-controller"

source liberty-openrc
source /etc/keystone/admin-openrc.sh #组件的需要依赖身份验证

echo "config nova database"
mysql -uroot -p"$mysql_pass" -e "show databases;" | grep "nova" &> /dev/null
if [ $? -eq 0 ]; then
  #系统中存在nova库
  mysql -uroot -p"$mysql_pass" -e "drop database nova;"
fi
mysql -uroot -p"$mysql_pass" -e "create database nova;"

mysql -uroot -p"$mysql_pass"  -e "use nova;grant all privileges on nova.* to '$mysql_nova_user'@'localhost' identified by '$mysql_nova_pass';"

mysql -uroot -p"$mysql_pass"  -e "use nova;grant all privileges on nova.* to '$mysql_nova_user'@'%' identified by '$mysql_nova_pass';"

echo "create nova service"
openstack service create --name nova --description "OpenStack Compute" compute &> /dev/null
if [ $? -ne 0 ]; then
  echo "service nova created error"
  exit
fi
openstack endpoint create --region RegionOne compute public http://controller:8774/v2/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service nova add endpoint public error"
  exit
fi
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service nova add endpoint internal error"
  exit
fi
openstack endpoint create --region RegionOne compute admin http://controller:8774/v2/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service nova add endpoint admin error"
  exit
fi

echo "create nova admin"
openstack user create --domain default --password $nova_user_admin_pass  $nova_user_admin &> /dev/null
if [ $? -ne 0 ]; then
  echo "nova user admin create error"
  exit
fi
openstack role add --project service --user $nova_user_admin admin
if [ $? -ne 0 ]; then
  echo "nova user admin bind role error"
  exit
fi

echo "install application"
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient &> /dev/null
if [ $? -ne 0 ]; then
  echo "nova application installed error"
  exit
fi

echo "config parameter"
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit 
  #配置RabbitMQ消息队列访问
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
  #配置认证策略
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip ${controller_ip} 
  #配置控制节点管理接口的IP地址
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
  #启用网络服务支持
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
  #安全组由neutron托管
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver   nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
  #用neutron托管底层接口并向上提供网络
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
  #关闭nova自带的防火墙，后面启用neutron防火墙
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf DEFAULT verbose True
  #开启日志
openstack-config --set /etc/nova/nova.conf database connection mysql://${mysql_nova_user}:${mysql_nova_pass}@controller/nova 
  #配置数据库访问
openstack-config --set /etc/nova/nova.conf glance host controller 
  #配置镜像服务的位置
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username ${nova_user_admin}
openstack-config --set /etc/nova/nova.conf keystone_authtoken password ${nova_user_admin_pass}
openstack-config --set /etc/nova/nova.conf neutron url http://controller:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://controller:35357
openstack-config --set /etc/nova/nova.conf neutron auth_plugin password
openstack-config --set /etc/nova/nova.conf neutron project_domain_id default
openstack-config --set /etc/nova/nova.conf neutron user_domain_id default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username ${neutron_user_admin}
openstack-config --set /etc/nova/nova.conf neutron password ${neutron_user_admin_pass}
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True 
  #启用元数据代理和配置元数据共享密码
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret ${secret_pass}
  #自定义，与/etc/neutron/metadata_agent.ini文件中一致即可
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp 
  #配置锁路径
  #配置 RabbitMQ消息队列访问
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}

  #配置VNC代理使用控制节点的管理IP地址
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen ${controller_ip}
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address ${controller_ip}

echo "sync nova database"
su -s /bin/sh -c "nova-manage db sync" nova &> /dev/null
n=$(mysql -u${mysql_nova_user} -p${mysql_nova_pass} -e "use nova;show tables;" | wc -l)
if [ $n -eq 0 ]; then
  echo "sync nova database error"
  exit
fi

echo "boot service"
systemctl restart openstack-nova-api
if [ $? -ne 0 ]; then
  echo "service openstack-nova-api restart error"
  exit
fi
systemctl restart openstack-nova-cert
if [ $? -ne 0 ]; then
  echo "service openstack-nova-cert restart error"
  exit
fi
systemctl restart openstack-nova-consoleauth
if [ $? -ne 0 ]; then
  echo "service openstack-nova-consoleauth restart error"
  exit
fi
systemctl restart openstack-nova-scheduler 
if [ $? -ne 0 ]; then
  echo "service openstack-nova-scheduler restart error"
  exit
fi
systemctl restart openstack-nova-conductor
if [ $? -ne 0 ]; then
  echo "service openstack-nova-conductor restart error"
  exit
fi
systemctl restart openstack-nova-novncproxy
if [ $? -ne 0 ]; then
  echo "service openstack-nova-conductor restart error"
  exit
fi

systemctl enable openstack-nova-api openstack-nova-cert openstack-nova-consoleauth openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy &> /dev/null

echo "$(hostname): setup liberty-nova-controller finish"
