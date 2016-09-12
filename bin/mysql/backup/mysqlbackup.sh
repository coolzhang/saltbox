#!/bin/bash
#
# mysqlbackup.sh
#

softdir=
# location of configuration files such as mycnf or baccnf
cnfdir=${softdir}/dbadmin/conf
# location of shell scripts
shdir=${softdir}/dbadmin/script
# categary of backup tools
dumptool=$(grep -vE "#|Null" ${cnfdir}/bakcnf |awk '{print $1}' |sort |uniq)
mysqldump=${softdir}/mysql/bin/mysqldump
xtrabackup=${softdir}/mysql/bin/innobackupex

# call sub-scripts -- mysqldump.sh or xtrabackup.sh
for type in ${dumptool}
do
  # check if previous process of backup is still running...
  if [ ${type} = "mysqldump" ];then
    ps -ef |grep -v grep |grep "${mysqldump}" > /dev/null
  elif [ ${type} = "xtrabackup" ];then
    ps -ef |grep -v grep |grep "${xtrabackup}" > /dev/null
  fi
  if [ $? -ne "0" ];then
    sh ${shdir}/${type}.sh
  else
    dbhost=$(grep IPADDR /etc/sysconfig/network-scripts/ifcfg-eth* |awk -F'=' '{print $2}' |tr '\n' ' ')
    ${soft_dir}/dbadmin/script/sendEmail -f monitor@cmug.org -t zhanghai@cmug.org -cc dba@cmug.org -u "Longtime Backup Report" -m "Please add info:[ ${dbhost} - ${type} - $(date +%Y%m%d) ] into backup_server:/data/backup/longbackup.list ." -s smtp.exmail.qq.com -o username=monitor@cmug.org -o password=xxxxxx
  fi
done
