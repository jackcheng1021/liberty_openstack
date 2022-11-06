# One Key Deploy Liberty-Openstack Platform

## 1. Prepare three node
- nodes
  - node1: os: centos7 hostname: controller disk1: /dev/sda
  - node2: os: centos7 hostname: compute01 disk1: /dev/sda disk2: /dev/sdb disk3: /dev/sdc
  - node3: os: centos7 hostname: compute02 disk1: /dev/sda disk2: /dev/sdb disk3: /dev/sdc
    - disk2: use block storage for cinder
    - disk3: use object storage for swift
- disable selinux on nodes
```
#use controller node for example
sed -i 's#^SELINUX=.*#SELINUX=disabled#g' /etc/selinux/config
reboot
```
- clone this project to controller node root dir `cd /root/; git clone https://github.com/jackcheng1021/liberty_openstack.git `

## 2. Download liberty package 
- url: https://pan.baidu.com/s/1ZkhNkJD4EC8y4pAvodEtDg 
- code: kn34 
- <font color='red'>upload the package to the root directory of this project</font>

## 3. Boot and deploy
- step1: set parameter in liberty-openrc.sh
```
[root@controller ~]# cd /root/liberty_openstack/
[root@controller liberty_openstack]# vi liberty-openrc.sh
```
- step2: boot one key system to install openstack platform
```
[root@controller liberty_openstack]# chmod +x liberty-setup.sh
[root@controller liberty_openstack]# ./liberty-setup.sh
```
- step3: also install it separately using scripts
```
[root@controller liberty_openstack]# chmod +x *.sh
[root@controller liberty_openstack]# ./liberty-env-config.sh
[root@controller liberty_openstack]# liberty-pre-controller
liberty-pre-compute
liberty-pre-compute
[root@controller liberty_openstack]# liberty-database-controller
[root@controller liberty_openstack]# liberty-keystone-controller
[root@controller liberty_openstack]# liberty-glance-controller
[root@controller liberty_openstack]# liberty-nova-controller
[root@compute01 ~]# liberty-nova-compute
[root@compute02 ~]# liberty-nova-compute
[root@controller liberty_openstack]# liberty-neutron-controller
[root@compute01 ~]# liberty-neutron-compute
[root@compute02 ~]# liberty-neutron-compute
[root@controller liberty_openstack]# liberty-dashboard-controller
[root@controller liberty_openstack]# liberty-cinder-controller
[root@compute01 ~]# liberty-cinder-compute
[root@compute02 ~]# liberty-cinder-compute
```

## 4. The visualization system for remote installation will be updated later
