#!/usr/bin/env bash

host_master_ip=$1
host_master_root_pass=$2
image_url=$3  #例如: 192.168.200.10:5000/busybox:0.1
service_type=$4 #1: external 2:internal
tenant=$5
service_name=$6
replicas=$7
image_port=$8
image_name=$(echo "${image_url}" | awk -F '/' '{print $NF}' | awk -F ':' '{print $1}' )
containerport=$9

func(){ # $1 tenant $2 service_name $3 replicas $4 image_name $5 image_url $6 containerport
  /usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$host_master_ip
expect {
       "(yes/no)" {send "yes\r"; exp_continue}
       "password:" {send "${host_master_root_pass}\r"}
}
expect "root@*" {send "currentMills=$(date  \"+%Y%m%d%H%M%S%s\") \r"}
expect "root@*" {send "[ $service_type -eq 1 ] && cp k8s/k8s_service-model-external.yml k8s/k8s-service-model-${currentMills}.yml || cp k8s/k8s_service-model-internal.yml k8s/k8s-service-model-${currentMills}.yml  \r"}
expect "root@*" {send "sed -i \"s#<namespace:name>.*</namespace:name>#$1#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<deployment:name>.*</deployment:name>#$1-$2#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<deployment:pod:replicas>.*</deployment:pod:replicas>#$3#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<deployment:pod:label>.*</deployment:pod:label>#$4#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<deployment:pod:name>.*</deployment:pod:name>#$4#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<deployment:pod:image>.*</deployment:pod:image>#$5#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<deployment:pod:containerport>.*</deployment:pod:containerport>#$6#g\" k8s/k8s-service-model-${currentMills}.yml \r"}
expect "root@*" {send "sed -i \"s#<service:name>.*</service:name>#$1-$2#g\" k8s/k8s-service-model-${currentMills}.yml  \r"}
expect "root@*" {send "kubectl apply -f k8s/k8s-service-model-${currentMills}.yml &> /dev/null \r"}
expect "root@*" {send "port=$(kubectl get service -n $1 | grep \"^$1-$2\" | awk '{print $5}' | awk -F '/' '{print $1}' | awk -F ':' '{print $NF}') \r"}
expect "root@*" {send "echo \"port:${port}\" \r"}
expect "root@*" {send "ips=$(cat /etc/hosts | grep -v \"^$\" | awk '{print $1}'); for ip in ${ips}; do [ \"${ip}\" == \"127.0.0.1\" ] && continue; [ \"${ip}\" == \"::1\" ] && continue; sed -i \"${index}i server ${ip}:${port};\" >> /etc/nginx/conf.d/nginx-${currentMills}.conf;  done  \r"}
expect "root@*" {send "rpm -q nginx || (yum -y install nginx &> /dev/null; systemctl restart nginx; systemctl enable nginx) \r"}
expect "root@*" {send "mkdir -p /etc/nginx/conf.d/location \r"}
expect "root@*" {send "cat /etc/nginx/conf.d/default.conf | grep \"include\" || cp k8s/nginx.conf /etc/nginx/conf.d/default.conf \r"}
expect "root@*" {send "sed -i \"1i upstream service_${currentMills} {\" /etc/nginx/conf.d/default.conf  \r"}
expect "root@*" {send "sed -i \"2i }\" /etc/nginx/conf.d/default.conf \r"}
expect "root@*" {send "for ip in ${ips}; do sed -i "2i server ${ip}:${port};" /etc/nginx/conf.d/default.conf;  done \r"}
expect "root@*" {send "echo \"location /${service_name} {\" > /etc/nginx/conf.d/location/service_${currentMills}.conf \r"}
expect "root@*" {send "echo \"}\" >> /etc/nginx/conf.d/location/service_${currentMills}.conf \r"}
expect "root@*" {send "sed -i \"2i proxy_pass http://service_${currentMills}; \" /etc/nginx/conf.d/location/service_${currentMills}.conf \r"}
expect "root@*" {send "nginx -s reload \r"}
expect "root@*" {send "exit &> /dev/null  \r"}
expect eof
FLAGEOF
}

result=$(func ${tenant} ${service_name} ${replicas} ${image_name} ${image_url} ${containerport})
port=$(echo "${result}" | grep "^port:" | awk -F ':' '{print $2}')

if [ $service_type -eq 1 ]; then
  echo "{\"result\":\"10\",\"msg\":{\"port\":\"${port}\",\"service_type\":\"external\",\"url\":\"http://${host_master_ip}/${service_name} \"}}"
  exit 0
fi
echo "{\"result\":\"10\",\"msg\":{\"service_type\":\"internal\"}}"
exit 0


