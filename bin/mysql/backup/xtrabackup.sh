#!/bin/bash
#
# sub-script -- xtrabackup.sh
#

source /root/.bash_profile
softdir=/data/soft
bakdir=/data/backup
bakdate=$(date +%Y%m%d)
cnfdir=${softdir}/dbadmin/conf
mysql=${softdir}/mysql/bin/mysql
xtrabackup=${softdir}/mysql/bin/innobackupex
USER=backup

command_check()
{
if [ ! -e ${mysql} -o ! -e ${xtrabackup} ];then
echo "mysql or xtrabackup: command not found!" > ${localdir}/mysqldump_${bakdate}.log
exit
fi
}

mkdir_bakdir()
{
localdir=${bakdir}/${dbdir}/xtrabackup/full
binlogdir=${bakdir}/${dbdir}/binlog
if [ ! -e ${localdir} ];then
mkdir -p ${localdir}
fi

if [ -e ${localdir}/${bakdate} ];then
rm -fr ${localdir}/${bakdate}
fi

if [ ! -e ${binlogdir}/${bakdate} ];then
mkdir -p ${binlogdir}/${bakdate}
fi
}

check_backup()
{
tail -n1 ${localdir}/xtrabackup_${bakdate}.log |grep "completed OK" > /dev/null
if [ $? -eq "0" ];then
  if [ "${SLAVE}" = "Y" ];then
    master_host=$(${mysql} -u${USER} -p${SECRET} -S${SOCKET} -NBe "select host from mysql.slave_master_info" 2>/dev/null |grep -v "Logging to file")
    master_port=$(${mysql} -u${USER} -p${SECRET} -S${SOCKET} -NBe "select port from mysql.slave_master_info" 2>/dev/null |grep -v "Logging to file")
    sed -i -e "s/CHANGE MASTER TO/CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_HOST='${master_host}', MASTER_PORT=${master_port},/" -e 's/$/;/' ${localdir}/${bakdate}/xtrabackup_slave_info
  elif [ "${SLAVE}" = "N" ];then
    file=$(awk '{print $1}' ${localdir}/${bakdate}/xtrabackup_binlog_info)
    pos=$(awk '{print $2}' ${localdir}/${bakdate}/xtrabackup_binlog_info)
    echo "CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_HOST='${IP}', MASTER_PORT=${PORT}, MASTER_LOG_FILE='${file}', MASTER_LOG_POS=${pos};" > ${localdir}/${bakdate}/xtrabackup_slave_info
  fi
  \cp -f ${localdir}/${bakdate}/xtrabackup_slave_info ${binlogdir}/${bakdate}
  cd ${localdir}
  \cp -f /data/mysql${PORT}/my${PORT}.cnf ${bakdate}/my.cnf
  tar -czf ${bakdate}.tar.gz ${bakdate} && rm -fr ${bakdate}
  ## remote backup dumpfile & logfile
  cd ${bakdir}
  rsync -az -R ${dbdir}/xtrabackup/full/${bakdate}.tar.gz mysql@10.1.1.45::backup
  rsync -az -R ${dbdir}/xtrabackup/full/xtrabackup_${bakdate}.log mysql@10.1.1.45::backup
  rsync -az -R ${dbdir}/binlog/${bakdate}/xtrabackup_slave_info mysql@10.1.1.45::backup
else
  return 1
fi
}

clean_backup()
{
find ${localdir} -mtime +0 -type f -delete
find ${binlogdir} -mtime +0 -type d -exec rm -rf {} +
}

get_dbpass()
{
if [ $UID -eq "0" ];then
source ${softdir}/dbadmin/script/secret.sh
else
echo "Must run secret.sh as ROOT!" > ${localdir}/xtrabackup_${bakdate}.log
fi
}

# start to backup
command_check

cat ${cnfdir}/bakcnf |grep "xtrabackup" |grep -v "Null" | while read TYPE WEEKLY SLAVE SOCKET PORT MYCNF SECRET INTERVAL IP
do
  dbdir=mysql${PORT}_${IP}
  mkdir_bakdir
  echo ${WEEKLY} |grep -E "`date +%a`|All" > /dev/null
  if [ $? -eq "0" ];then
    get_dbpass
    ## backup on slave and apply redo log
    if [ ${SLAVE} = "Y" ];then
      ${xtrabackup} --defaults-file=${MYCNF} --user=${USER} --password=${SECRET} --socket=${SOCKET} --slave-info --no-timestamp ${localdir}/${bakdate}/ 2>${localdir}/xtrabackup_${bakdate}.log && ${xtrabackup} --defaults-file=${MYCNF} --apply-log  ${localdir}/${bakdate}/ 2>${localdir}/xtrabackup_${bakdate}.log
      check_backup
      if [ $? -eq "0" ];then
      clean_backup
      fi
    ## backup on master and apply redo log
    elif [ ${SLAVE} = "N" ];then 
      ${xtrabackup} --defaults-file=${MYCNF} --user=${USER} --password=${SECRET} --socket=${SOCKET}  --no-timestamp ${localdir}/${bakdate}/ 2>${localdir}/xtrabackup_${bakdate}.log && ${xtrabackup} --defaults-file=${MYCNF} --apply-log  ${localdir}/${bakdate}/ 2>${localdir}/xtrabackup_${bakdate}.log
      check_backup
      if [ $? -eq "0" ];then
      clean_backup
      fi
    fi
  fi
done
