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
[root@compute01 ~]# liberty-pre-compute
[root@compute02 ~]# liberty-pre-compute
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

## 5. important submit

All the scripts in this project are divided into two parts：
- some scripts for ops
- some scripts for development，one key generate a cloud host with a development environment, eg: java-1.8, python-3.6, docker, mysql-5.7, tomcat-8.0, redis
  - liberty-tenant-create.sh
  - liberty-tenant-imge-create.sh
  - liberty-tenant-instance-create.sh
  - liberty-tenant-instance-dev.sh
  - liberty-tenant-network-create.sh

## 6. Update Process
- 2022.11.06
  - repair: some bugs
  - submit: "on key install system"
- 2022.11.07
  - new add: tenant-create script
  - new add: tenant-network-create script
  - update: two scripts add  "one key install system"
- 2022.11.08
  - update: tenant-instance-create script，support use  default or custom create tenant-instance
  - update: repair liberty-setup script, liberty-tenant-instance-create add liberty-setup script
- 2022.11.09
  - new add: liberty-tenant-instance-dev script, one key generate server use for development
  - new add: liberty-tenant-image-create script, one key upload image to glance
  - update: liberty-tenant-instance-create script, user one key generate server with development environment
- 2022.11.10
  - new add: liberty-tenant-instance-deploy-java-package script, one key deploy java project in instance
  - new add: liberty-tenant-instance-deploy-python-package script, one key deploy python project in instance
  - new add: liberty-tenant-instance-deploy-tomcat-package script, one key deploy web project in instance
  - update: liberty-tenant-instance-create script, repair some parameters bug
  - update: liberty-tenant-instance-dev script, repair some parameters bug
  - update: liberty-tenant-instance-install-app script, repair some parameters bug
- 2022.11.13
  - new add: liberty-tenant-instance-git, one key deploy git env in cloud host
  - new add: liberty-tenant-instance-git-repo, one key deploy git repo in cloud host
  - update: liberty-tenant-*.sh, repair json string form
  