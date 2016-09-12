#!/bin/bash
#
#

salt_fileroots=
sshkey_dir=${salt_fileroots}/conf/mha/sshkeys

if [ "$#" = "1" ];then
  if [ ! -e ${sshkey_dir}/$1 ];then
    mkdir ${sshkey_dir}/$1
    ssh-keygen -q -N '' -f ${sshkey_dir}/$1/id_rsa
    cp -a ${sshkey_dir}/authorized_keys ${sshkey_dir}/$1/
    cd ${sshkey_dir}/$1
    cat id_rsa.pub >> authorized_keys
    cat /root/.ssh/id_rsa.pub >> authorized_keys
    echo sshkeys dir: [${sshkey_dir}/$1]
  else
    echo "[ ${sshkey_dir}/$1 ] already exists!"
  fi

else
  echo "Usage: sh $0 app_name"
fi
