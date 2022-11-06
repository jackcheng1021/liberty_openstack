#!/bin/bash

echo "$(hostname): setup liberty-glance-controller"

source liberty-openrc
source /etc/keystone/admin-openrc.sh #加载管理员令牌

echo "config glance database"
mysql -uroot -p"$mysql_pass" -e "show databases;" | grep "glance" &> /dev/null
if [ $? -eq 0 ]; then
  mysql -uroot -p"$mysql_pass" -e "drop database glance;"
fi
mysql -uroot -p"$mysql_pass" -e "create database glance;"

mysql -uroot -p"$mysql_pass"  -e "use glance;grant all privileges on glance.* to '$mysql_glance_user'@'localhost' identified by '$mysql_glance_pass';"

mysql -uroot -p"$mysql_pass"  -e "use keystone;grant all privileges on glance.* to '$mysql_glance_user'@'%' identified by '$mysql_glance_pass';"

echo "create glance service"
openstack service create --name glance --description "OpenStack Image service" image &> /dev/null
if [ $? -ne 0 ]; then
  echo "service glance created error"
  exit
fi
openstack endpoint create --region RegionOne image public http://controller:9292 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service glance add endpoint public error"
  exit
fi
openstack endpoint create --region RegionOne image internal http://controller:9292 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service glance add endpoint internal error"
  exit
fi
openstack endpoint create --region RegionOne image admin http://controller:9292 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service glance add endpoint admin error"
  exit
fi

echo "create glance admin"
openstack user create --domain default --password $glance_user_admin_pass  $glance_user_admin &> /dev/null
if [ $? -ne 0 ]; then
  echo "glance user admin created error"
  exit
fi
openstack role add --project service --user $glance_user_admin admin &> /dev/null
if [ $? -ne 0 ]; then
  echo "glance user admin bind role error"
  exit
fi

echo "install application"
rpm -q openstack-glance &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install openstack-glance &> /dev/null
  if [ $? -ne 0 ]; then
    echo "openstack-glance installed error"
    exit
  fi
fi
rpm -q python-glance &> /dev/null
if [ $? -ne 0 ]; then 
  yum -y install python-glance &> /dev/null
  if [ $? -ne 0 ]; then
    echo "python-glance installed error"
    exit
  fi
fi
rpm -q python-glanceclient &> /dev/null
if [ $? -ne 0 ]; then 
  yum -y install python-glanceclient &> /dev/null
  if [ $? -ne 0 ]; then
    echo "python-glanceclient installed error"
    exit
  fi
fi

echo "config parameter"
openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver noop#禁用通知
openstack-config --set /etc/glance/glance-api.conf DEFAULT verbose True 
  #开启日志
openstack-config --set /etc/glance/glance-api.conf database connection mysql://${mysql_glance_user}:${mysql_glance_pass}@controller/glance #配置数据库连接
openstack-config --set /etc/glance/glance-api.conf glance_store default_store file #配置本地文件系统存储
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/ #配置镜像文件位置
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://controller:5000 #glance身份验证地址-外人员和内部人员
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://controller:35357 #glance身份验证地址-管理员
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_plugin password #glance身份验证的方式-密码
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_id default #glance身份验证服服务所在项目的区域-default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_id default #glance身份验证的用户所在区域-default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name service #glance身份验证服务所在项目-service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username ${glance_user_admin} #glance身份验证服务的所使用的用户名
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password ${glance_user_admin_pass}
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone #配置认证服务访问
openstack-config --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop #禁用通知
openstack-config --set /etc/glance/glance-registry.conf DEFAULT verbose True #开启日志
openstack-config --set /etc/glance/glance-registry.conf database connection mysql://${mysql_glance_user}:${mysql_glance_pass}@controller/glance #配置数据库连接
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://controller:35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken username ${glance_user_admin}
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken password ${glance_user_admin_pass}
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone #配置认证服务访问

echo "sync glance database"
su -s /bin/sh -c "glance-manage db_sync" glance &> /dev/null #将配置写入镜像服务数据库
n=$(mysql -u${mysql_glance_user} -p${mysql_glance_pass} -e "use glance;show tables;" | wc -l)
if [ $n -eq 0 ]; then
  echo "sync glance database error"
  exit
fi

echo "boot service"
systemctl restart openstack-glance-api openstack-glance-registry
systemctl enable openstack-glance-api openstack-glance-registry &> /dev/null
netstat -lntp | grep python | awk -F ' ' '{print $4}' | grep 9191 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service port 9191 error"
  exit
fi
netstat -lntp | grep python | awk -F ' ' '{print $4}' | grep 9292 &> /dev/null
if [ $? -ne 0 ]; then
  echo "service port  9292 error"
  exit
fi

echo "check result"
echo "export OS_IMAGE_API_VERSION=2" | tee -a /etc/keystone/admin-openrc.sh
source /etc/keystone/admin-openrc.sh
glance image-list &> /dev/null #确认镜像的上传并验证属性
if [ $? -ne 0 ]; then
  echo "glance setup error"
  exit
fi
echo "$(hostname): setup liberty-glance-controller finish"

