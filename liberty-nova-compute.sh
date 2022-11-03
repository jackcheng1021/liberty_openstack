#!/bin/bash

echo "该脚本在compute节点运行"
echo "配置 liberty-nova-compute"
sleep 5

source liberty-openrc.sh #加载环境变量

echo "安装软件"
rpm -q openstack-nova-compute &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install openstack-nova-compute &> /dev/null
  if [ $? -ne 0 ]; then
    echo "openstack-nova-compute 安装失败"
    exit
  fi
fi

rpm -q sysfsutils &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install sysfsutils &> /dev/null
  if [ $? -ne 0 ]; then
    echo "sysfsutils 安装失败"
    exit
  fi
fi

echo "配置参数"
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit 
  #配置RabbitMQ消息队列
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
  #配置认证服务访问
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $1 #Ip从脚本外传进
  #计算节点上的管理网络接口的IP地址
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
  #启用网络服务支持
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api neutron
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
  #使用neutron托管底层网络接口
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
  #关闭nova防火墙
openstack-config --set /etc/nova/nova.conf DEFAULT verbose True
  #开启日志
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
  #keystone身份认证
n=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ $n -eq 0 ]; then
  openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
else
  openstack-config --set /etc/nova/nova.conf libvirt virt_type kvm
fi
openstack-config --set /etc/nova/nova.conf neutron url http://controller:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://controller:35357
openstack-config --set /etc/nova/nova.conf neutron auth_plugin password
openstack-config --set /etc/nova/nova.conf neutron project_domain_id default
openstack-config --set /etc/nova/nova.conf neutron user_domain_id default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username ${neutron_user_admin}
openstack-config --set /etc/nova/nova.conf neutron password ${neutron_user_admin_pass}
  #配置nova管理neutron
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
  #配置锁路径
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host controller
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid ${rabbit_user}
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password ${rabbit_pass}
  #配置Rabbit访问信息
openstack-config --set /etc/nova/nova.conf vnc enabled True
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $1
openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://${controller_ip}:6080/vnc_auto.html
  #配置访问云主机的伪终端

echo "启动服务"
systemctl restart libvirtd
if [ $? -ne 0 ]; then
  echo "libvirtd 启动失败"
  exit
fi
systemctl restart openstack-nova-compute
if [ $? -ne 0 ]; then
  echo "openstack-nova-compute 启动失败"
  exit
fi
systemctl enable libvirtd openstack-nova-compute

echo "liberty-nova-compute 配置完成"
