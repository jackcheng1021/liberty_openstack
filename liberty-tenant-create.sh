#!/bin/bash

source liberty-openrc
source /etc/keystone/admin-openrc.sh

if [ $# -eq 0 ]; then
  echo "run liberty-tenant-create"
  echo "create project ${tenant_project}"

  openstack project show ${tenant_project} &>/dev/null
  if [ $? -eq 0 ]; then
    echo "project ${tenant_project} exist"
    exit
  fi
  openstack project create --domain default --description "${tenant_project} Project" ${tenant_project} &>/dev/null
  if [ $? -ne 0 ]; then
    echo "create project ${tenant_project} error"
    exit
  fi

  echo "create user ${tenant_project_user}"
  openstack user show ${tenant_project_user} &>/dev/null
  if [ $? -ne 0 ]; then
    echo "user ${tenant_project_user} exist"
    exit
  fi
  openstack user create --domain default --password ${tenant_project_user_pass} ${tenant_project_user} &>/dev/null
  if [ $? -ne 0 ]; then
    echo "create user ${tenant_project_user} error"
    exit
  fi

  openstack role show user &>/dev/null
  if [ $? -ne 0 ]; then
    echo "create role user"
    openstack role create user &>/dev/null
  fi

  echo "bind role user with ${tenant_project_user}"
  openstack role add --project ${tenant_project} --user ${tenant_project_user} user &>/dev/null
  if [ $? -ne 0 ]; then
    echo "bind role user with ${tenant_project_user} error"
    exit
  fi

  echo "echo ${tenant_project} token"
  cat >/etc/keystone/demo-openrc.sh <<E0F
  export OS_PROJECT_DOMAIN_ID=default
  export OS_USER_DOMAIN_ID=default
  export OS_PROJECT_NAME=${tenant_project}
  export OS_TENANT_NAME=${tenant_project}
  export OS_USERNAME=${tenant_project_user}
  export OS_PASSWORD=${tenant_project_user_pass}
  export OS_AUTH_URL=http://controller:5000/v3
  export OS_IDENTITY_API_VERSION=3
E0F
  if [ %? -ne 0 ]; then
    echo "created ${tenant_project} token error"
    exit
  fi

  echo "init secgroup"
  source /etc/keystone/demo-openrc.sh
  nova secgroup-delete default &>/dev/null
  nova secgroup-create default default
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
  nova secgroup-add-rule default udp 1 65535 0.0.0.0/0

  echo "run liberty-tenant-create finish"

else
  projectName=$1
  projectUser=$2
  projectUserPass=$3

  openstack project show ${projectName} &>/dev/null
  if [ $? -eq 0 ]; then
    echo "{\"result\":\"-1\",\"msg\":\"project not exist\"}"
    exit
  fi

  openstack project create --domain default --description "${projectName} Project" ${projectName} &>/dev/null
  if [ $? -ne 0 ]; then
    echo "{\"result\":\"0\",\"msg\":\"project create error\"}"
    exit
  fi

  openstack user show ${projectUser} &>/dev/null
  if [ $? -eq 0 ]; then
    echo "{\"result\":\"1\",\"msg\":\"user exist\"}"
    exit
  fi

  openstack user create --domain default --password ${projectUserPass} ${projectUser} &>/dev/null
  if [ $? -ne 0 ]; then
    echo "{\"result\":\"2\",\"msg\":\"user create error\"}"
    exit
  fi

  openstack role show user &>/dev/null
  if [ $? -ne 0 ]; then
    openstack role create user &>/dev/null
    if [ $? -ne 0 ]; then
      echo "{\"result\":\"3\",\"msg\":\"role create error\"}"
      exit
    fi
  fi

  openstack role add --project ${projectName} --user ${projectUser} user &>/dev/null
  if [ $? -ne 0 ]; then
    echo "{\"result\":\"4\",\"msg\":\"bind role error\"}"
    exit
  fi

  cat >/etc/keystone/${projectName}-openrc.sh <<E0F
  export OS_PROJECT_DOMAIN_ID=default
  export OS_USER_DOMAIN_ID=default
  export OS_PROJECT_NAME=${projectName}
  export OS_TENANT_NAME=${projectName}
  export OS_USERNAME=${projectUser}
  export OS_PASSWORD=${projectUserPass}
  export OS_AUTH_URL=http://controller:5000/v3
  export OS_IDENTITY_API_VERSION=3
E0F

  if [ %? -ne 0 ]; then
    echo "{\"result\":\"5\",\"msg\":\"created token error\"}"
    exit
  fi

  source /etc/keystone/${projectName}-openrc.sh
  nova secgroup-delete default &>/dev/null
  nova secgroup-create default default
  nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  nova secgroup-add-rule default tcp 1 65535 0.0.0.0/0
  nova secgroup-add-rule default udp 1 65535 0.0.0.0/0

  echo "{\"result\":\"10\",\"msg\":\"create tenant success\"}"

fi
