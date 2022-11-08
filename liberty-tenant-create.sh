#!/bin/bash

source liberty-openrc
source /etc/keystone/admin-openrc.sh

echo "run liberty-tenant-create"

if [ $# -eq 0 ]; then
  echo "create project ${tenant_project}"
  openstack project show ${tenant_project} &> /dev/null
  if [ $? -eq 0 ]; then
    echo "project ${tenant_project} exist"
    exit
  fi
  openstack project create --domain default --description "${tenant_project} Project" ${tenant_project} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create project ${tenant_project} error"
    exit
  fi

  echo "create user ${tenant_project_user}"
  openstack user show ${tenant_project_user} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "user ${tenant_project_user} exist"
    exit
  fi
  openstack user create --domain default --password ${tenant_project_user_pass} ${tenant_project_user} &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create user ${tenant_project_user} error";
    exit
  fi

  openstack role show user &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create role user"
    openstack role create user &> /dev/null
  fi

  echo "bind role user with ${tenant_project_user}"
  openstack role add --project ${tenant_project} --user ${tenant_project_user} user &> /dev/null
  if [ $? -ne 0 ]; then
    echo "bind role user with ${tenant_project_user} error"
    exit
  fi
  
  echo "echo ${tenant_project} token"
  cat > /etc/keystone/demo-openrc.sh << E0F
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

else
  echo "create project $1"
  openstack project show $1 &> /dev/null
  if [ $? -eq 0 ]; then
    echo "project $1 exist"
    exit
  fi
  openstack project create --domain default --description "$1 Project" $1 &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create project $1 error"
    exit
  fi

  echo "create user $2"
  openstack user show $2 &> /dev/null
  if [ $? -ne 0 ]; then
    echo "user $2 exist"
    exit
  fi
  openstack user create --domain default  --password $3 $2 &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create user $2 error";
    exit
  fi

  openstack role show user &> /dev/null
  if [ $? -ne 0 ]; then
    echo "create role user"
    openstack role create user &> /dev/null
  fi

  echo "bind role user with $2"
  openstack role add --project $1 --user $2 user &> /dev/null
  if [ $? -ne 0 ]; then
    echo "bind role user with $2 error"
    exit
  fi

  echo "create $1 token"
  cat > /etc/keystone/$1-openrc.sh << E0F
  export OS_PROJECT_DOMAIN_ID=default
  export OS_USER_DOMAIN_ID=default
  export OS_PROJECT_NAME=$1
  export OS_TENANT_NAME=$1
  export OS_USERNAME=$2
  export OS_PASSWORD=$3
  export OS_AUTH_URL=http://controller:5000/v3
  export OS_IDENTITY_API_VERSION=3
E0F
  if [ %? -ne 0 ]; then
    echo "created $1 token error"
    exit
  fi

fi

echo "run liberty-tenant-create finish"
