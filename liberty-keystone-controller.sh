#!/bin/bash

source liberty-openrc.sh

echo "该脚本在controller节点执行"
echo "开始安装并配置keystone"
sleep 5

echo "配置mysql"
mysql -uroot -p"$mysql_pass" -e "show databases;" | grep "keystone" &> /dev/null
if [ $? -eq 0 ]; then
  #系统中存在Keystone库
  mysql -uroot -p"$mysql_pass" -e "drop database keystone;"
fi
mysql -uroot -p"$mysql_pass" -e "create database keystone;"

mysql -uroot -p"$mysql_pass"  -e "use keystone;grant all privileges on keystone.* to '$mysql_keystone_user'@'localhost' identified by '$mysql_keystone_pass';"

mysql -uroot -p"$mysql_pass"  -e "use keystone;grant all privileges on keystone.* to '$mysql_keystone_user'@'%' identified by '$mysql_keystone_pass';"

echo "安装必要的组件"
rpm -q openssl &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install openssl &> /dev/null
fi

export OS_TOKEN=$(openssl rand -hex 10)

yum -y install openstack-keystone &> /dev/null
if [ $? -ne 0 ]; then
  #安装失败
  echo "openstack-keystone 安装失败"
  exit
fi

yum -y install mod_wsgi &> /dev/null
if [ $? -ne 0 ]; then
  #安装失败
  echo "mod_wsgi 安装失败"
  exit
fi

yum -y install httpd &> /dev/null
if [ $? -ne 0 ]; then
  #安装失败
  echo "httpd 安装失败"
  exit
fi

yum -y install memcached &> /dev/null
if [ $? -ne 0 ]; then
  #安装失败
  echo "memcached 安装失败"
  exit
fi

yum -y install python-memcached &> /dev/null
if [ $? -ne 0 ]; then
  #安装失败
  echo "python-memcached 安装失败"
  exit
fi

systemctl restart memcached
systemctl enable memcached

echo "配置keystone配置文件"
#设置keystone配置所需要的一个初识令牌
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token ${OS_TOKEN}
#配置keystone数据库的连接对象
openstack-config --set /etc/keystone/keystone.conf database connection mysql://${mysql_keystone_user}:${mysql_keystone_pass}@controller/keystone
#配置keystone所要使用的缓存的所在位置
openstack-config --set /etc/keystone/keystone.conf memcache servers localhost:11211
#配置token的生成规则
openstack-config --set /etc/keystone/keystone.conf token provider uuid
#配置token的驱动器
openstack-config --set /etc/keystone/keystone.conf token driver memcache
#配置keystone的服务回滚
openstack-config --set /etc/keystone/keystone.conf revoke driver sql

echo "同步发布数据库"
su -s /bin/sh -c "keystone-manage db_sync" keystone

n=$(mysql -u${mysql_keystone_user} -p${mysql_keystone_pass} -e "use keystone;show tables;" | wc -l)
if [ $n -eq 0 ]; then
  echo "数据库同步失败，请检查配置"
  exit
fi

echo "配置httpd服务"
sed -i 's#^ServerName .*#ServerName controller#g' /etc/httpd/conf/httpd.conf

cat > /etc/httpd/conf.d/wsgi-keystone.conf << E0F
Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>
E0F

systemctl restart httpd #启动httpd服务
systemctl enable httpd

netstat -lntp | grep httpd | awk -F ' ' '{print $4}' | grep 5000
if [ $? -ne 0 ]; then
  echo "httpd 5000端口配置失败"
  exit
fi

netstat -lntp | grep httpd | awk -F ' ' '{print $4}' | grep 35357
if [ $? -ne 0 ]; then
  echo "httpd 35357端口配置失败"
  exit
fi

echo "配置环境变量"
export OS_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
n=$(env | grep ^OS | wc -l)
if [ $n -lt 3 ]; then
  echo "环境变量配置不完整"
  exit
fi

echo "创建keystone服务"
openstack service create --name keystone --description "OpenStack Identity" identity
#if [ $? -ne 0 ]; then
#  echo "keystone服务创建失败"
#  exit
#fi

openstack endpoint create --region RegionOne identity internal http://controller:5000/v2.0
if [ $? -ne 0 ]; then
  echo "internal 服务入口创建失败"
  exit
fi

openstack endpoint create --region RegionOne identity admin http://controller:35357/v2.0
if [ $? -ne 0 ]; then
  echo "admin 服务入口创建失败"
  exit
fi

openstack endpoint create --region RegionOne identity public http://controller:5000/v2.0
if [ $? -ne 0 ]; then
  echo "public 服务入口创建失败"
  exit
fi

openstack project create --domain default --description "Admin Project" admin
if [ $? -ne 0 ]; then
  echo "admin 租户创建失败"
  exit
fi

openstack user create --domain default --password ${keystone_user_admin_pass} ${keystone_user_admin}
if [ $? -ne 0 ]; then
  echo "admin 用户创建失败"
  exit
fi

openstack role create admin
if [ $? -ne 0 ]; then
  echo "admin 角色创建失败"
  exit
fi

openstack role add --project admin --user ${keystone_user_admin} admin
if [ $? -ne 0 ]; then
  echo "admin 角色 映射 admin租户 失败"
  exit
fi

openstack project create --domain default --description "Service Project" service
if [ $? -ne 0 ]; then
  echo "service 服务创建失败"
  exit
fi

echo "撤销临时令牌"
sed -i 's#admin_token_auth ##g' /usr/share/keystone/keystone-dist-paste.ini
unset OS_TOKEN OS_URL

echo "创建认证证书"
cat > /etc/keystone/admin-openrc.sh << E0F #设置 admin 项目的环境变量
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=${keystone_user_admin}
export OS_TENANT_NAME=${keystone_user_admin}
export OS_USERNAME=${keystone_user_admin}
export OS_PASSWORD=${keystone_user_admin_pass}
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
E0F

echo "keystone安装配置完成"
