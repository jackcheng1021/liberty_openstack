#!/bin/bash

source liberty-openrc
source /etc/keystone/admin-openrc.sh

echo "setup cinder-controller"

echo "config database cinder"
mysql -uroot -p"$mysql_pass" -e "show databases;" | grep "cinder" &> /dev/null
if [ $? -eq 0 ]; then
  mysql -uroot -p"$mysql_pass" -e "drop database cinder;"
fi
mysql -uroot -p"$mysql_pass" -e "create database cinder;"

mysql -uroot -p"$mysql_pass"  -e "use cinder;grant all privileges on cinder.* to '$mysql_cinder_user'@'localhost' identified by '$mysql_cinder_pass';"

mysql -uroot -p"$mysql_pass"  -e "use cinder;grant all privileges on cinder.* to '$mysql_cinder_user'@'%' identified by '$mysql_cinder_pass';"

echo "create cinder admin"
openstack user create --domain default --password ${cinder_user_admin}  ${cinder_user_admin_pass} &> /dev/null
if [ $? -ne 0 ]; then
  echo "create cinder admin error"
  exit
fi
openstack role add --project service --user ${cinder_user_admin} admin
if [ $? -ne 0 ]; then
  echo "assign role error"
  exit
fi

echo "create service"
openstack service create --name cinder  --description "OpenStack Block Storage" volume &> /dev/null
if [ $? -ne 0 ]; then
  echo "create cinder service error"
  exit
fi
openstack service create --name cinderv2  --description "OpenStack Block Storage" volumev2 &> /dev/null
if [ $? -ne 0 ]; then
  echo "create cinderv2 service error"
  exit
fi

echo "create service endpoints"
openstack endpoint create --region RegionOne volume public http://controller:8776/v1/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service cinder add endpoint public error"
  exit
fi
openstack endpoint create --region RegionOne volume internal http://controller:8776/v1/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service cinder add endpoint internal error"
  exit
fi
openstack endpoint create --region RegionOne volume admin http://controller:8776/v1/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service cinder add endpoint admin error"
  exit
fi
openstack endpoint create --region RegionOne volumev2 public http://controller:8776/v2/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service cinderv2 add endpoint public error"
  exit
fi
openstack endpoint create --region RegionOne volumev2 internal http://controller:8776/v2/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service cinderv2 add endpoint public error"
  exit
fi
openstack endpoint create --region RegionOne volumev2 admin http://controller:8776/v2/%\(tenant_id\)s &> /dev/null
if [ $? -ne 0 ]; then
  echo "service cinderv2 add endpoint public error"
  exit
fi

echo "install cinder"
yum -y install openstack-cinder &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-cinder installed error"
  exit
fi
yum -y install python-cinderclient &> /dev/null
if [ $? -ne 0 ]; then
  echo "python-cinderclient installed error"
  exit
fi

echo "config parameter"
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip ${controller_ip}
  #配置 my_ip 来使用控制节点的管理接口的IP 地址
openstack-config --set /etc/cinder/cinder.conf DEFAULT verbose True
  #启用详细日志
openstack-config --set /etc/cinder/cinder.conf database connection mysql://${mysql_cinder_user}:${mysql_cinder_pass}@controller/cinder 
  #配置数据库访问
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_name service
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken username ${cinder_user_admin}
openstack-config --set /etc/cinder/cinder.conf keystone_authtoken password ${cinder_user_admin_pass}
  #配置身份验证信息
openstack-config --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp 
  #配置锁路径
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}
  #配置rabbit
openstack-config --set /etc/nova/nova.conf cinder os_region_name RegionOne
  #配置nova能访问cinder

echo "sync database cinder"
su -s /bin/sh -c "cinder-manage db sync" cinder &> /dev/null
n=$(mysql -u${mysql_cinder_user} -p${mysql_cinder_pass} -e "use cinder;show tables;" | wc -l)
if [ $n -eq 0 ]; then
  echo "sync database error, check parameter"
  exit
fi

echo "boot service"
systemctl restart openstack-nova-api
if [ $? -ne 0 ]; then
  echo "service openstack-nova-api restart error, check nova.conf"
  exit
fi
systemctl restart openstack-cinder-api
if [ $? -ne 0 ]; then
  echo "service openstack-cinder-api restart error, check cinder.conf"
  exit
fi
systemctl restart openstack-cinder-scheduler
if [ $? -ne 0 ]; then
  echo "service openstack-cinder-scheduler restart error, check cinder.conf"
  exit
fi
systemctl enable openstack-cinder-api openstack-cinder-scheduler &> /dev/null

echo "setup cinder-controller finish"
