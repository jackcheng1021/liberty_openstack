#!/bin/bash

echo "$(hostname): setup liberty-database-controller"

source liberty-openrc

echo "deploy mariadb"
rpm -q mariadb &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install mariadb &> /dev/null || (echo "mariadb installed error"; exit)
fi

rpm -q mariadb-server &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install mariadb-server &> /dev/null || (echo "mariadb-server installed error"; exit)
fi

rpm -q MySQL-python &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install MYSQL-python &> /dev/null || (echo "MYSQL-python installed error"; exit)
fi

rpm -q expect &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install expect $> /dev/null || (echo "expect installed error"; exit)
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

systemctl restart mariadb &> /dev/null || (echo "service mariadb start error"; exit)
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
if [ $? -ne 0 ]; then
  echo "mariadb init error"
  exit
fi

echo "deploy MongoDB"
rpm -q mongodb-server &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install mongodb-server &> /dev/null
  if [ $? -ne 0 ];then
    echo "mongodb-server installed error"
    exit
  fi
fi

rpm -q mongodb &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install mongodb &> /dev/null
  if [ $? -ne 0 ];then
    echo "mongodb installed error"
    exit
  fi
fi

sed -i 's#^bind_ip = .*#\#bind_ip = 127.0.0.1#g' /etc/mongod.conf
sed -i 's#^\#smallfiles = .*#smallfiles = true#g' /etc/mongod.conf

systemctl restart mongod || (echo "mongodb boot error"; exit)
systemctl enable mongod &> /dev/null

echo "deploy RabbitMQ"
rpm -q rabbitmq-server &> /dev/null
if [ $? -ne 0 ]; then
  yum -y install rabbitmq-server &> /dev/null
  if [ $? -ne 0 ]; then
    echo "rabbitmq installed error"
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

echo "$(hostname): setup liberty-database-controller finish"
