#!/bin/bash

echo "进行部署openstack的准备工作"

echo "在compute节点执行"

sleep 5

source liberty-openrc

echo "配置yum源"
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo &> /dev/null
if [ $? -ne 0 ]; then
  echo "yum源: CentOS-Base.repo 配置失败"
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

yum makecache &> /dev/null
len=$(yum list | grep "^openstack" | wc -l)
if [ ${len} -lt 137 ]; then
  echo "liberty源配置有错"
  exit
fi

echo "关闭防火墙"
systemctl stop firewalld &> /dev/null
systemctl disable firewalld &> /dev/null

echo "关闭网络管理器"
systemctl stop NetworkManager &> /dev/null
systemctl disable NetworkManager &> /dev/null

echo "清空访问规则"
rpm -q iptables-services &> /dev/null
if [ $? -ne 0 ];then
  yum -y install iptables-services &> /dev/null
  if [ $? -ne 0 ]; then
    echo "访问规则管理器安装失败"
    exit
  fi
fi
systemctl restart iptables
systemctl enable iptables
iptables -F && iptables -F -t nat && iptables -F -t mangle && iptables -F -t raw
service iptables save

echo "禁用安全模块"
sed -i 's#SELINUX=.*#SELINUX=disabled#g' /etc/selinux/config

echo "设置DNS"
len=$(cat /etc/resolv.conf | grep "^nameserver" | grep -v '^$' | wc -l) #-v 表示过滤掉
if [ ${len} -eq 0 ];then
    echo "nameserver ${dns_ip}" &>> /etc/resolv.conf
else
    sed -i 's#^nameserver .*#nameserver '${dns_ip}'#g' /etc/resolv.conf
fi

echo "设置主机映射"
len=$(cat /etc/hosts | grep 'controller$' | grep -v '^$' | wc -l)
if [ $len -eq 0 ]; then
    #主机映射中没有controller这一行
    echo "${controller_ip} controller" &>> /etc/hosts
else
    #删除controller对应的行后重新填
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

echo "安装初始化软件包"
yum -y install python-openstackclient &> /dev/null
if [ $? -ne 0 ];then
    echo "python-openstackclient 安装失败"
    exit
fi
yum -y install python-openstackclient &> /dev/null
if [ $? -ne 0 ];then
    echo "python-openstackclient 安装失败"
    exit
fi
yum -y install openstack-utils &> /dev/null
if [ $? -ne 0 ];then
    echo "openstack-utils 安装失败"
    exit 
fi

echo "部署时间同步"
rpm -q chrony &> /dev/null
if [ $? -ne 0 ]; then
    echo "开始安装时间同步"
    yum -y install chrony &> /dev/null
fi

echo "配置时间同步"

#删除server配置
sed -i 's#^.*.iburst$##g' /etc/chrony.conf
echo "server ${ntp_server} iburst" >> /etc/chrony.conf

systemctl restart chronyd 
systemctl enable chronyd

{
    chronyc sources -v | grep '\^\*'
}&
wait

if [ $? -ne 0 ]
then
  echo "请检查时间同步配置"
  exit
fi

echo "配置完成，重启"
sleep 2
reboot
