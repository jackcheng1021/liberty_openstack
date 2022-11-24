#!/usr/bin/env bash

#host_master=$1
#host_master_ip=${master[ip]}
#host_master_pass=${master[pass]}

tenant=$1
hostArray=$2

source /etc/keystone/${tenant}-openrc.sh &> /dev/null
if [ $? -ne 0 ]; then
  echo "{\"result\":\"-1\",\"msg\":\"tenant not exist\"}"
  exit
fi

#各个节点准备环境
for item in ${hostArray[*]}
do
  hostIp=${item[ip]}
  hostRootPass=${item[pass]}
  /usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@$hostIp
expect {
       "(yes/no)" {send "yes\r"; exp_continue}
       "password:" {send "${hostRootPass}\r"}
}
expect "root@*" {send "echo \"[k8s]\" > /etc/yum.repos.d/k8s.repo \r"}
expect "root@*" {send "echo \"name=k8s\" >> /etc/yum.repos.d/k8s.repo \r"}
expect "root@*" {send "echo \"baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/\" >> /etc/yum.repos.d/k8s.repo \r"}
expect "root@*" {send "echo \"gpgcheck=0\" >> /etc/yum.repos.d/k8s.repo \r"}
expect "root@*" {send "echo \"enabled=1\" >> /etc/yum.repos.d/k8s.repo \r"}
expect "root@*" {send "for host in $*; do ip=${host[ip]}; name=${host[name]}; echo \"${ip} ${name}\" >> /etc/hosts done \r"}
expect "root@*" {send "rpm -q iptables-services || yum -y install iptables-services &> /dev/null \r"}
expect "root@*" {send "systemctl restart iptables && systemctl enable iptables \r"}
expect "root@*" {send "iptables -F && iptables -F -t nat && iptables -F -t mangle && iptables -F -t raw \r"}
expect "root@*" {send "service iptables save &> /dev/null \r"}
expect "root@*" {send "modprobe br_netfilter \r"}
expect "root@*" {send "echo \"net.ipv4.ip_forward = 1\" >> /etc/sysctl.d/k8s.conf \r"}
expect "root@*" {send "echo \"vm.swappiness = 0\" >> /etc/sysctl.d/k8s.conf \r"}
expect "root@*" {send "echo \"net.bridge.bridge-nf-call-ip6tables = 1\" >> /etc/sysctl.d/k8s.conf \r"}
expect "root@*" {send "echo \"net.bridge.bridge-nf-call-iptables = 1\" >> /etc/sysctl.d/k8s.conf \r"}
expect "root@*" {send "echo \"modprobe ip_vs\" >> /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "echo \"modprobe ip_vs_rr\" >> /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "echo \"modprobe ip_vs_wrr\" >> /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "echo \"modprobe ip_vs_sh\" >> /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "echo \"modprobe nf_conntrack_ipv4\" >> /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "chmod 755 /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "rpm -q docker-ce-19.03.1 || yum -y install docker-ce-19.03.1 &> /dev/null \r"}
expect "root@*" {send "mkdir -p /etc/docker \r"}
expect "root@*" {send "[ -f /etc/docker/daemon.json ] && rm -f /etc/docker/daemon.json \r"}
expect "root@*" {send "echo \"{\" >> /etc/docker/daemon.json  \r"}
expect "root@*" {send "echo '\"registry-mirrors\": [\"https://idoamkgf.mirror.aliyuncs.com\"],' >> /etc/docker/daemon.json \r"}
expect "root@*" {send "echo '\"exec-opts\": [\"native.cgroupdriver=systemd\"]' >> /etc/docker/daemon.json \r"}
expect "root@*" {send "echo \"}\" >> /etc/docker/daemon.json \r"}
expect "root@*" {send "systemctl daemon-reload \r"}
expect "root@*" {send "systemctl restart docker \r"}
expect "root@*" {send "systemctl enable docker &> /dev/null \r"}
expect "root@*" {send "yum -y install kubelet-1.18.3 kubeadm-1.18.3 kubectl-1.18.3 &> /dev/null \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF
  if [ $? -ne 0 ]; then
    echo "{\"result\":\"0\",\"msg\":\"k8s pre error\"}"
    exit
  fi
done

#初始化master
host=${hostArray[0]}
hostIp=${host[ip]}
hostRootPass=${host[pass]}
##拷贝文件
/usr/bin/expect << FLAGEOF
spawn scp *.yml root@hostIp:/root/
expect {
  "(yes/no)?" {send "yes\r"; exp_continue}
  "Password:" {send "${hostRootPass}\r"}
}
expect eof
FLAGEOF
##初始化
k8sInit(){
/usr/bin/expect << FLAGEOF
set timeout 1800
spawn ssh root@$1
expect {
  "(yes/no)" {send "yes\r"; exp_continue}
  "password:" {send "$2 \r"}
}
expect "root@*" {send "sysctl -p /etc/sysctl.d/k8s.conf &> /dev/null \r"}
expect "root@*" {send "source /etc/sysconfig/modules/ipvs.modules \r"}
expect "root@*" {send "systemctl enable kubelet &> /dev/null \r"}
expect "root@*" {send "echo \"token:$(kubeadm init --kubernetes-version=1.18.3 --apiserver-advertise-address=${hostIp} --image-repository registry.aliyuncs.com/google_containers --service-cidr=10.2.0.0/16 --pod-network-cidr=10.3.0.0/16)\" \r"}
expect "root@*" {send "while [ 1 -eq 1 ]; do count=$(docker images | grep \"^registry\" | wc -l); [ $count -eq 7 ] && break || sleep 10 done \r"}
expect "root@*" {send "echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /etc/profile \r"}
expect "root@*" {send "source /etc/profile \r"}
expect "root@*" {send "while [ 1 -eq 1 ]; do count=$(kubectl get cs | grep -E \"ok|true\" | wc -l); [ $count -eq 3 ] && break || sleep 10 \r"}
expect "root@*" {send "kubectl apply -f kube-flannel.yml \r"}
expect "root@*" {send "while [ 1 -eq 1 ]; do count=$(kubectl get pods -n kube-system | grep -v \"running\" | grep -v \"^$\" | wc -l); [ $count -eq 0 ] && break || sleep 10; done \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF
}

token=$(k8sInit ${hostIp} ${hostRootPass} | grep "^token" | awk -F ':' '{print $2}' )
if [ $? -ne 0 ]; then
  echo "{\"result\":\"1\",\"msg\":\"k8s init error\"}";
fi

#节点加入集群
index=1
while [ ${index} -lt ${#hostArray[*]} ]
do
  host=${hostArray[index]}
  hostIp=${host[ip]}
  hostRootPass=${host[pass]}
  /usr/bin/expect << FLAGEOF
set timeout 600
spawn ssh root@${hostIp}
expect {
  "(yes/no)" {send "yes\r"; exp_continue}
  "password:" {send "${hostRootPass}\r"}
}
expect "root@*" {send "${token} \r"}
expect "root@*" {send "exit \r"}
expect eof
FLAGEOF
  if [ $? -ne 0 ]; then
    echo "{\"result\":\"2\",\"msg\":\"node join cluster error\"}"
    exit
  fi
  let index=index+1
done

echo "{\"result\":\"10\",\"msg\":\"k8s install success\"}"




