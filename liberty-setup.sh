#!/bin/bash
clear
echo "----Welcome Use Liberty OpenStack One Key System----"
echo "    inpute 1: one key install openstack"
echo "    inpute 2: config environment"
echo "    inpute 3: restore configuration"
echo "    inpute 4: reinstall database"
echo "    inpute 5: reinstall keystone"
echo "    inpute 6: reinstall glance"
echo "    inpute 7: reinstall nova"
echo "    inpute 8: reinstall neutron"
echo "    inpute 9: reinstall dashboard"
echo "    inpute 0: reinstall Cinder"
echo "    inpute 11 show menu"
echo "    inpute 10: quit"
echo "----------------------------------------------------"

while [ 1 -eq 1 ]
do
  read -p "pleae input key: " key
  if [ $key -eq 10 ]; then
    echo "welcome to use again，bye"
    exit
  fi 
  if [ $key -eq 11 ]; then
    clear
    echo "----Welcome Use Liberty OpenStack One Key System----"
    echo "    inpute 1: one key install openstack"
    echo "    inpute 2: config environment"
    echo "    inpute 3: restore configuration"
    echo "    inpute 4: reinstall database"
    echo "    inpute 5: reinstall keystone"
    echo "    inpute 6: reinstall glance"
    echo "    inpute 7: reinstall nova"
    echo "    inpute 8: reinstall neutron"
    echo "    inpute 9: reinstall dashboard"
    echo "    inpute 0: reinstall Cinder"
    echo "    inpute 11 show menu"
    echo "    inpute 10: quit"
    echo "----------------------------------------------------"
  fi
  
  if [ $key -eq 1 ]; then
    echo "start on key install liberty-openstack"
    ln -s liberty-env-config.sh /usr/local/bin/liberty-env-config
    liberty-env-config

    source liberty-openrc

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
    send \"liberty-nova-compute ${compute01_ip}\r\"
    expect \"${compute01_user}@*\"
    send \"exit\r\"
    expect eof

    spawn ssh -p 22 $compute02_user@$compute02_ip
    expect \"Password:\" 
    send \"${compute02_user_pass}\r\"
    expect \"${compute02_user}@*\"
    send \"liberty-nova-compute ${compute02_ip}\r\"
    expect \"${compute02_user}@*\"
    send \"exit\r\"
    expect eof

    liberty-neutron-controller

    spawn ssh -p 22 $compute01_user@$compute01_ip
    expect \"Password:\"
    send \"${compute01_user_pass}\r\"
    expect \"${compute01_user}@*\"
    send \"liberty-neutron-compute ${compute01_ip}\r\"
    expect \"${compute01_user}@*\"
    send \"exit\r\"
    expect eof

    spawn ssh -p 22 $compute02_user@$compute02_ip
    expect \"Password:\"
    send \"${compute02_user_pass}\r\"
    expect \"${compute02_user}@*\"
    send \"liberty-neutron-compute ${compute02_ip}\r\"
    expect \"${compute02_user}@*\"
    send \"exit\r\"
    expect eof
    
    liberty-dashboard-controller
    liberty-cinder-controller
    
    spawn ssh -p 22 $compute01_user@$compute01_ip
    expect \"Password:\"
    send \"${compute01_user_pass}\r\"
    expect \"${compute01_user}@*\"
    send \"liberty-cinder-compute\r\"
    expect \"${compute01_user}@*\"
    send \"exit\r\"
    expect eof
    
    spawn ssh -p 22 $compute02_user@$compute02_ip
    expect \"Password:\"
    send \"${compute02_user_pass}\r\"
    expect \"${compute02_user}@*\"
    send \"liberty-cinder-compute\r\"
    expect \"${compute02_user}@*\"
    send \"exit\r\"
    expect eof
    
    echo "one key install liberty-openstack finish"
  fi
done
