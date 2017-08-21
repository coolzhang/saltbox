#!/bin/bash
#
#

echo -n "IP of slave(e.g, 10.1.6.88): "
read remote_ip
echo -n "Port of slave(e.g, 3306): "
read port
echo -n "Port of master(e.g, 3307): "
read mport
echo -n "Date of restore(e.g, 20160327): "
read dumpdate
echo -n "Tool of restore(e.g, mysqldump,xtrabackup): "
read tool

local_ip=$(ifconfig eth0 |awk '/inet addr:/ {print $2}' |awk -F':' '{print $2}')
local_basedir=/data/backup/mysql${mport}_${local_ip}
local_bindir=${local_basedir}/binlog/${dumpdate}
remote_basedir=/data/backup/mysql${port}_${remote_ip}
remote_bindir=${remote_basedir}/binlog/${dumpdate}

if [ "${tool}" = "mysqldump" ];then
dumpfile=${local_basedir}/${tool}/${dumpdate}.tar.gz
bininfo=${local_bindir}/${tool}_slave_info
remote_bakdir=${remote_basedir}/${tool}
elif [ "${tool}" = "xtrabackup" ];then
dumpfile=${local_basedir}/${tool}/full/${dumpdate}.tar.gz
bininfo=${local_bindir}/${tool}_slave_info
remote_bakdir=${remote_basedir}/${tool}/full
fi

echo $(date +%k:%M:%S) dumpfile syncing...
ssh -o StrictHostKeyChecking=no ${remote_ip} "mkdir -p ${remote_bakdir}"
ssh -o StrictHostKeyChecking=no ${remote_ip} "mkdir -p ${remote_bindir}"
scp -o StrictHostKeyChecking=no ${dumpfile} ${remote_ip}:${remote_bakdir}/
scp -o StrictHostKeyChecking=no ${bininfo} ${remote_ip}:${remote_bindir}/
echo $(date +%k:%M:%S) sync end!!!
