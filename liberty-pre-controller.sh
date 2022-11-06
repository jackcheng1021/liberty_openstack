#!/bin/bash

echo "$(hostname): setup liberty-pre-controller"

source liberty-openrc

echo "config yum repo"
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null
if [ $? -ne 0 ]; then
  echo "yum: CentOS-Base.repo config error"
  exit
fi
rpm -q createrepo &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install createrepo &> /dev/null
  if [ $? -ne 0 ]; then
    echo "createrepo installed error"
  fi
fi
tar -zxvf liberty.tar.gz -C /opt/ &> /dev/null
if [ $? -ne 0 ]; then
  echo "liberty package uzip error"
  exit
fi
createrepo /opt/liberty &> /dev/null
if [ $? -ne 0 ]; then
  echo "create liberty local repo error"
  exit
fi

if [ -f /etc/yum.repos.d/liberty.repo ]; then
  rm -f /etc/yum.repos.d/liberty.repo
fi
cat > /etc/yum.repos.d/liberty.repo << E0F
[liberty]
name=liberty
baseurl=ftp://${controller_ip}/liberty
gpgcheck=0
enabled=1
E0F

rpm -q vsftpd &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install vsftpd &> /dev/null
  if [ $? -ne 0 ]; then
    echo "vsftpd installed error"
    exit
  fi
fi
echo "anon_root=/opt/" >> /etc/vsftpd/vsftpd.conf
systemctl restart vsftpd || (echo "vsftpd config error"; exit)
systemctl enable vsftpd &> /dev/null

yum makecache &> /dev/null
len=$(yum list | grep "^openstack" | wc -l)
if [ ${len} -lt 137 ]; then
  echo "liberty repo error"
  exit
fi

echo "close firewall"
systemctl stop firewalld &> /dev/null
systemctl disable firewalld &> /dev/null

echo "close networkmanager"
systemctl stop NetworkManager &> /dev/null
systemctl disable NetworkManager &> /dev/null

echo "clear rule"
rpm -q iptables-services &> /dev/null
if [ $? -ne 0 ];then
  yum -y install iptables-services &> /dev/null
  if [ $? -ne 0 ]; then
    echo "iptables-services installed error"
    exit
  fi
fi
systemctl restart iptables
systemctl enable iptables &> /dev/null
iptables -F && iptables -F -t nat && iptables -F -t mangle && iptables -F -t raw
service iptables save &> /dev/null

echo "disable selinux"
#sed -i 's#SELINUX=.*#SELINUX=disabled#g' /etc/selinux/config
#setenforce 0
seStatus=$(sestatus | awk '{print $3}')
if [ "${seStatus}" != "disabled" ]; then
  echo "set SELINUX=disabled in /etc/selinux/config and reboot server"
  exit
fi

echo "config DNS"
len=$(cat /etc/resolv.conf | grep "^nameserver" | grep -v '^$' | wc -l)
if [ ${len} -eq 0 ];then
    echo "nameserver ${dns_ip}" &>> /etc/resolv.conf
else
    sed -i 's#^nameserver .*#nameserver '${dns_ip}'#g' /etc/resolv.conf
fi

echo "config host map"
len=$(cat /etc/hosts | grep 'controller$' | grep -v '^$' | wc -l)
if [ $len -eq 0 ]; then
    echo "${controller_ip} controller" &>> /etc/hosts
else
    sed -i 's#^.*.controller$##g' /etc/hosts
    echo "${controller_ip} controller" &>> /etc/hosts
fi

len=$(cat /etc/hosts | grep 'compute01$' | grep -v '^$' | wc -l)
if [ $len -eq 0 ]; then
    echo "${compute01_ip} compute01" &>> /etc/hosts
else
    #删除compute01对应的行后重新填
    sed -i 's#^.*.compute01$##g' /etc/hosts
    echo "${compute01_ip} compute01" &>> /etc/hosts
fi

len=$(cat /etc/hosts | grep 'compute02$' | grep -v '^$' | wc -l)
if [ $len -eq 0 ]; then
    echo "${compute02_ip} compute02" &>> /etc/hosts
else
    #删除compute02对应的行后重新填
    sed -i 's#^.*.compute02$##g' /etc/hosts
    echo "${compute02_ip} compute02" &>> /etc/hosts
fi

echo "install application"
yum -y install python-openstackclient &> /dev/null
if [ $? -ne 0 ];then
    echo "python-openstackclient installed error"
    exit
fi
yum -y install python-openstackclient &> /dev/null
if [ $? -ne 0 ];then
    echo "python-openstackclient installed error"
    exit
fi
yum -y install openstack-utils &> /dev/null
if [ $? -ne 0 ];then
    echo "openstack-utils installed error"
    exit 
fi

echo "deploy ntp"
rpm -q chrony &> /dev/null
if [ $? -ne 0 ]; then
    echo "install ntp"
    yum -y install chrony &> /dev/null
fi

echo "config ntp"

#删除server配置
sed -i 's#^.*.iburst$##g' /etc/chrony.conf
echo "server ${ntp_server} iburst" >> /etc/chrony.conf

systemctl restart chronyd || (echo "config ntp error"; exit) 
systemctl enable chronyd &> /dev/null

{
    chronyc sources -v | grep '\^\*'
}&
wait

if [ $? -ne 0 ]
then
  echo "sync time error"
  exit
fi

echo "$(hostname): setup liberty-pre-controller finish"
