#!/bin/bash
clear
echo "----欢迎使用 Liberty OpenStack 安装系统----"
echo "    按1: 一键安装"
echo "    按2: 环境配置"
echo "    按3: 修复系统配置"
echo "    按4: 重装数据库"
echo "    按5: 重装keystone"
echo "    按6: 重装glance"
echo "    按7: 重装nova"
echo "    按8: 重装neutron"
echo "    按9: 重装dashboard"
echo "    按0: 重装Cinder"
echo "    按11 显示菜单"
echo "    按10: 退出"
echo "-------------------------------------------"

while [ 1 -eq 1 ]
do
  read -p "请按键: " key
  if [ $key -eq 10 ]; then
    echo "欢迎再次使用，再见"
    exit
  fi 
  if [ $key -eq 11 ]; then
    clear
    echo "----欢迎使用 Liberty OpenStack 安装系统----"
    echo "    按1: 一键安装"
    echo "    按2: 环境配置"
    echo "    按3: 修复系统配置"
    echo "    按4: 重装数据库"
    echo "    按5: 重装keystone"
    echo "    按6: 重装glance"
    echo "    按7: 重装nova"
    echo "    按8: 重装neutron"
    echo "    按9: 重装dashboard"
    echo "    按0: 重装Cinder"
    echo "    按11 显示菜单"
    echo "    按10: 退出"
    echo "-------------------------------------------"
  fi
  
  if [ $key -eq 1 ]; then
    source liberty-env-config.sh
    liberty-pre-controller
    
    spawn ssh -p 22 $compute01_user@$compute01_ip
    expect \"Password:\" 
    send \"${compute01_user_pass}\r\"
    expect \"${compute01_user}@*\"
    send \"liberty-pre-compute\r\"
    expect \"${compute01_user}@*\"
    send \"exit\r\"
    expect eof

    spawn ssh -p 22 $compute02_user@$compute02_ip
    expect \"Password:\" 
    send \"${compute02_user_pass}\r\"
    expect \"${compute02_user}@*\"
    send \"liberty-pre-compute\r\"
    expect \"${compute02_user}@*\"
    send \"exit\r\"
    expect eof

    liberty-database-controller
    liberty-keystone-controller
    liberty-glance-controller
    liberty-nova-controller

    spawn ssh -p 22 $compute01_user@$compute01_ip
    expect \"Password:\"
    send \"${compute01_user_pass}\r\"
    expect \"${compute01_user}@*\"
    send \"liberty-nova-compute\r\"
    expect \"${compute01_user}@*\"
    send \"exit\r\"
    expect eof

    spawn ssh -p 22 $compute02_user@$compute02_ip
    expect \"Password:\"
    send \"${compute02_user_pass}\r\"
    expect \"${compute02_user}@*\"
    send \"liberty-nova-compute\r\"
    expect \"${compute02_user}@*\"
    send \"exit\r\"
    expect eof
  fi
done
