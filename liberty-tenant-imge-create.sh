#!/usr/bin/env bash

source /etc/keystone/admin-openrc.sh

echo "run liberty-tenant-image-create"

imageName=$1
imagePath=$2
imageFormat=$3
containerFormat=$4

glance image-create --name "${imageName}" --file $imagePath --disk-format $imageFormat  --container-format $containerFormat --visibility public &> /dev/null
if [ $? -ne 0 ]; then
  echo "glance: image ${imageName} created error"
  exit
fi

echo "run liberty-tenant-image-create finish"