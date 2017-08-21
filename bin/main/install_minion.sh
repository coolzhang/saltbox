#!/bin/bash
#
# install_minion.sh
#

mid="${1}"
salt_master_ip="${2}"
salt_minion_conf=/etc/salt/minion

df |grep /dev/vdb >/dev/null
if [ "$?" = "1" ];then
yum install -y xfsprogs >/dev/null
mkfs.xfs /dev/vdb && echo /dev/vdb            /data                 xfs       defaults,noatime,nobarrier 1 0 >> /etc/fstab && mount -a && mkdir /data/swap && dd if=/dev/zero of=/data/swap/swap bs=4096 count=1572864 && mkswap /data/swap/swap && swapon /data/swap/swap && echo /data/swap/swap        swap       swap      defaults 0 0 >> /etc/fstab 
fi
grep -w ${mid} ${salt_minion_conf} >/dev/null 2>&1
if [ "$?" = "2" ];then
yum install -y salt-minion >/dev/null
sed -i -e "/#master:/amaster: ${salt_master_ip}" -e "/#id:/aid: ${mid}" ${salt_minion_conf}
service salt-minion start >/dev/null
elif [ "$?" = "1" ];then
sed -i -e "/^master:/d" -e "/^id:/d" -e "/#master:/amaster: ${salt_master_ip}" -e "/#id:/aid: ${mid}" ${salt_minion_conf}
service salt-minion restart >/dev/null
fi
