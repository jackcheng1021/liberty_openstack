#!/bin/bash

source liberty-openrc

echo "$(hostname): setup liberty-cinder-compute"

echo "install application"
yum -y install lvm2 &> /dev/null
if [ $? -ne 0 ]; then
  echo "lvm2 installed error"
  exit
fi
yum -y install openstack-cinder &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-cinder installed error"
  exit
fi
yum -y install targetcli &> /dev/null
if [ $? -ne 0 ]; then
  echo "targetcli installed error"
  exit
fi
yum -y install python-oslo-policy &> /dev/null
if [ $? -ne 0 ]; then
  echo "python-oslo-policy installed error"
  exit
fi

echo "create volume"
systemctl restart lvm2-lvmetad && systemctl enable lvm2-lvmetad || exit
pvcreate ${cinder_disk_path} &> /dev/null || (echo "create pv error, check disk path"; exit)
vgcreate cinder-volumes ${cinder_disk_path} &> /dev/null || (echo "create vg error, check pv"; exit)
let index=$(cat -n /etc/lvm/lvm.conf | grep "devices {" | xargs | awk '{print $1}')+1
sed "${index}i filter = [ \"a/sda/\", \"a/sdb/\", \"r/.*/\"]" /etc/lvm/lvm.conf
systemctl restart openstack-cinder-volume target || (echo "create volume error; exit")

echo "config parameter"
openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit 
  #配置 RabbitMQ 消息队列访问
openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone 
  #配置认证服务访问
ip=$(grep "$(hostname)" /etc/hosts | awk '{print $1}')

openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip ${ip} 
  #存储节点上的管理网络接口的IP 地址
openstack-config --set /etc/cinder/cinder.conf DEFAULT enabled_backends lvm 
  #启用 LVM 后端
openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host controller 
  #配置镜像服务的位置
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
  #配置身份认证信息
openstack-config --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
  #配置锁路径
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}
  #配置 RabbitMQ 消息队列访问
openstack-config --set /etc/cinder/cinder.conf lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
  #设置Cinder管理lvm需要的驱动
openstack-config --set /etc/cinder/cinder.conf lvm volume_group cinder-volumes
  #设置cinder管理的卷组为cinder-volumes
openstack-config --set /etc/cinder/cinder.conf lvm iscsi_protocol iscsi
  #设置使用磁盘协议scsi
openstack-config --set /etc/cinder/cinder.conf lvm iscsi_helper lioadm

echo "boot service"
systemctl restart openstack-cinder-volume || (echo "service openstack-cinder-volume restart error"; exit)
systemctl restart target || (echo "service target restart error"; exit)
systemctl enable openstack-cinder-volume target &> /dev/null

echo "$(hostname): setup liberty-cinder-compute finish"
