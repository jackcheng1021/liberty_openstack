#!/usr/bin/env bash

#删除实例
tenant=$1
hostName=$2

source /etc/keystone/${tenant}-openrc.sh
if [ $? -ne 0 ]; then
  echo "{\"result\":\"-1\",\"msg\":\"tenant not exist\"}"
  exit
fi

nova delete ${hostName} &> /dev/null
if [ $? -ne 0 ]; then
  echo "{\"result\":\"0\",\"msg\":\"instance not exist\"}"
  exit
fi

echo "{\"result\":\"10\",\"msg\":\"instance delete finish\"}"