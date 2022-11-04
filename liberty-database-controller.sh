#!/bin/bash

echo "该脚本在controller节点执行"
sleep 5

source liberty-openrc

echo "部署mysql数据库"
rpm -q mariadb &> /dev/null
if [ $? -ne 0 ]; then
  #mariadb没有安装
  yum -y install mariadb &> /dev/null
fi

rpm -q mariadb-server &> /dev/null
if [ $? -ne 0 ]; then
  #mariadb-server没有安装
  yum -y install mariadb-server &> /dev/null
fi

rpm -q MySQL-python &> /dev/null
if [ $? -ne 0 ]; then
  #MYSQL-python没有安装
  yum -y install MYSQL-python &> /dev/null
fi

rpm -q expect &> /dev/null
if [ $? -ne 0 ]; then
  #安装expect
  yum -y install expect
fi

cp /usr/share/mariadb/my-medium.cnf /etc/my.cnf

openstack-config --set /etc/my.cnf mysqld bind-address ${controller_ip}
sed -i 's#^bind_address#\#bind_address#g' /etc/my.cnf
openstack-config --set /etc/my.cnf mysqld default-storage-engine innodb
openstack-config --set /etc/my.cnf mysqld innodb_file_per_table
openstack-config --set /etc/my.cnf mysqld collation-server utf8_general_ci
openstack-config --set /etc/my.cnf mysqld init-connect 'SET NAMES utf8'
openstack-config --set /etc/my.cnf mysqld character-set-server utf8
openstack-config --set /etc/my.cnf mysqld max_connections 1000

systemctl restart mariadb &> /dev/null
systemctl enable mariadb &> /dev/null

expect -c "
spawn /usr/bin/mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$mysql_pass\r\"
expect \"Re-enter new password:\"
send \"$mysql_pass\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"n\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
"
echo "mysql 数据库配置完成"

echo "部署MongoDB 数据库"
rpm -q mongodb-server &> /dev/null
if [ $? -ne 0 ]; then
  #mongodb-server 没安装
  yum -y install mongodb-server &> /dev/null
  if [ $? -ne 0 ];then
    echo "安装 mongodb-server 失败"
    exit
  fi
fi

rpm -q mongodb &> /dev/null
if [ $? -ne 0 ]; then
  #mongodb 没安装
  yum -y install mongodb &> /dev/null
  if [ $? -ne 0 ];then
    echo "安装 mongodb 失败"
    exit
  fi
fi

sed -i 's#^bind_ip = .*#\#bind_ip = 127.0.0.1#g' /etc/mongod.conf
sed -i 's#^\#smallfiles = .*#smallfiles = true#g' /etc/mongod.conf

systemctl restart mongod 
systemctl enable mongod &> /dev/null
echo "MongoDB 配置完成"

echo "部署 RabbitMQ 消息队列"
rpm -q rabbitmq-server &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install rabbitmq-server &> /dev/null
  if [ $? -ne 0 ]; then
    echo "rabbitmq 安装失败"
    exit
  fi
fi

systemctl restart rabbitmq-server &> /dev/null
systemctl enable rabbitmq-server &> /dev/null

rabbitmqctl list_users | grep rabbit &> /dev/null
if [ $? -ne 0 ]; then
  rabbitmqctl add_user $rabbit_user $rabbit_pass
fi
rabbitmqctl set_permissions $rabbit_user ".*" ".*" ".*"
echo "rabbitmq 配置完成"

echo "数据库配置完成"
