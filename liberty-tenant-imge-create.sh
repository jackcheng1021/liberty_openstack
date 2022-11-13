#!/usr/bin/env bash


source /etc/keystone/admin-openrc.sh

imageName=$1
imageUrl=$2
imagePath=/opt/image/${imageName}
imageFormat=$3
containerFormat=$4

{
curl -o $imagePath $imageUrl &> /dev/null
}&
wait
if [ $? -ne 0 ]; then
  echo "{\"result\":\"0\",\"msg\":\"image download error\"}"
  exit
fi


glance image-create --name "${imageName}" --file $imagePath --disk-format $imageFormat  --container-format $containerFormat --visibility public &> /dev/null
if [ $? -ne 0 ]; then
  echo "{\"result\":\"-1\",\"msg\":\"image created error\"}"
  exit
fi

echo "{\"result\":\"10\",\"msg\":\"image created success\"}"

