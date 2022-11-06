#!/bin/bash

source liberty-openrc

source /etc/keystone/admin-openrc.sh

echo "$(hostname): setup liberty-dashboard-controller"

echo "install dashboard"
yum -y install openstack-dashboard &> /dev/null
if [ $? -ne 0 ]; then
  echo "openstack-dashboard install failed"
  exit
fi

echo "config parameter"
sed -i 's#^OPENSTACK_HOST = .*#OPENSTACK_HOST = \"controller\"#g' /etc/openstack-dashboard/local_settings
sed -i 's#^ALLOWED_HOSTS = .*#ALLOWED_HOSTS = ['*', ]#g' /etc/openstack-dashboard/local_settings
sed -i "118i \'LOCATION\': \'controller:11211\'\," /etc/openstack-dashboard/local_settings
sed -i 's#^OPENSTACK_KEYSTONE_DEFAULT_ROLE = .*#OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"#g' /etc/openstack-dashboard/local_settings
sed 's#^\#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = .*#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True#g' /etc/openstack-dashboard/local_settings
index=$(cat -n /etc/openstack-dashboard/local_settings | grep "#OPENSTACK_API_VERSIONS = .*" | xargs | awk '{print $1}')
sed -i "${index}i OPENSTACK_API_VERSIONS = \{ " /etc/openstack-dashboard/local_settings
let index=index+1
sed -i "${index}i \"identity\": 3," /etc/openstack-dashboard/local_settings
let index=index+1
sed -i "${index}i \"volume\": 2," /etc/openstack-dashboard/local_settings
let index=index+1
sed -i "${index}i \}" /etc/openstack-dashboard/local_settings
timezone=$(timedatectl | grep "Time zone" | xargs |awk '{print $3}')
sed -i "s#^TIME_ZONE = .*#TIME_ZONE = \"${timezone}\"#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_router': .*#'enable_router': True,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_quotas': .*#'enable_quotas': True,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_ipv6': .*#'enable_ipv6': False,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_distributed_router': .*#'enable_distributed_router': False,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_ha_router': .*#'enable_ha_router': False,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_lb': .*#'enable_lb': False,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_firewall': .*#'enable_firewall': False,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_vpn': .*#'enable_vpn': False,#g" /etc/openstack-dashboard/local_settings
sed -i "s#'enable_fip_topology_check': .*#'enable_fip_topology_check': False,#g" /etc/openstack-dashboard/local_settings

echo "boot service"
systemctl restart httpd
if [ $? -ne 0 ]; then
  echo "dashboard local_settings exist error"
  exit
else
  systemctl enable httpd &> /dev/null
fi

systemctl restart memcached
if [ $? -ne 0 ]; then
  echo "dashboard local_settings exist error"
  exit
else
  systemctl enable memcached &> /dev/null
fi

echo "pleae access http://${controller_ip}/dashboard"
echo "domain: default"
echo "user: ${keystone_user_admin}"
echo "password" ${keystone_user_admin_pass}
echo "$(hostname): setup liberty-dashboard-controller finish"
