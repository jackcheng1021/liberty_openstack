#!/bin/bash

source liberty-openrc

echo $controller_ip

#/usr/bin/expect << FLAGEOF
#set timeout 2
#spawn ssh $controller_user@$controller_ip   
#expect {
#        "(yes/no)" {send "yes\r"; exp_continue}
#        "password:" {send "$controller_user_pass\r"}
#}
#expect "${controller_user}@*"  {send "echo \"hello test\" &> ~/test.txt\r"}
#expect "${controller_user}@*"  {send "exit\r"}
#expect eof 
#FLAGEOF
