#!/bin/bash
#
#  sub-script: mysqldump.sh
#

softdir=/data/soft
bakdir=/data/backup
bakdate=$(date +%Y%m%d)
cnfdir=${softdir}/dbadmin/conf
mysql=${softdir}/mysql/bin/mysql
mysqldump=${softdir}/mysql/bin/mysqldump
USER=backup

command_check()
{
if [ ! -e ${mysql} -o ! -e ${mysqldump} ];then
echo "mysql or mysqldump: command not found!" > ${localdir}/mysqldump_${bakdate}.log
exit
fi
}

mkdir_bakdir()
{
localdir=${bakdir}/${dbdir}/mysqldump
binlogdir=${bakdir}/${dbdir}/binlog

if [ ! -e ${localdir} ];then
mkdir -p ${localdir}
fi

if [ ! -e ${binlogdir}/${bakdate} ];then
mkdir -p ${binlogdir}/${bakdate}
fi
}

check_backup()
{
if [ -e ${localdir}/${bakdate}.sql ];then
  tail -n1 ${localdir}/${bakdate}.sql |grep "Dump completed" > ${localdir}/mysqldump_${bakdate}.log
  if [ $? -eq "0" ];then
    grep -m1 'CHANGE MASTER TO' ${localdir}/${bakdate}.sql > ${binlogdir}/${bakdate}/mysqldump_slave_info
    if [ "${SLAVE}" = "Y" ];then
      sed -i "s/CHANGE MASTER TO/CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl',/" ${binlogdir}/${bakdate}/mysqldump_slave_info
    elif [ "${SLAVE}" = "N" ];then
      sed -i "s/CHANGE MASTER TO/CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='repl', MASTER_HOST='${IP}', MASTER_PORT=${PORT},/" ${binlogdir}/${bakdate}/mysqldump_slave_info 
    fi 
    cp /data/mysql${PORT}/my${PORT}.cnf ${localdir}/
    cd ${localdir}/; tar -czf ${bakdate}.tar.gz my${PORT}.cnf ${bakdate}.sql
    if [ $? -eq "0" ];then
      ## remote backup dumpfile & logfile
      cd ${bakdir}
      rsync -az -R ${dbdir}/mysqldump/${bakdate}.tar.gz mysql@10.1.1.45::backup
      rsync -az -R ${dbdir}/mysqldump/mysqldump_${bakdate}.log mysql@10.1.1.45::backup
      rsync -az -R ${dbdir}/binlog/${bakdate}/mysqldump_slave_info mysql@10.1.1.45::backup
      rm -f ${localdir}/${bakdate}.sql;rm -f ${localdir}/my*.cnf
    fi
  else
    return 1
  fi
else
  cd ${bakdir}
  rsync -az -R ${dbdir}/mysqldump/mysqldump_${bakdate}.log mysql@10.1.1.45::backup
fi
}

clean_backup()
{     
find ${localdir} -mtime +0 -type f -delete
find ${binlogdir} -mtime +0 -type d -exec rm -rf {} +
} 

get_dbpass()
{
if [ ${UID} -eq "0" ];then
source ${softdir}/dbadmin/script/secret.sh
else
echo "Must run secret.sh as ROOT!" > ${localdir}/mysqldump_${bakdate}.log
fi
}

get_dbname()
{
dbnames=$(${mysql} -u${USER} -p${SECRET} -S${SOCKET} -B -N -e "show databases" 2>/dev/null |grep -v -E "information_schema|mysql|test|performance_schema|sys")
DBNAMES=$(echo ${dbnames})
}

check_query()
{
enabled_backup=0
max_running=6
sleep_seconds=60
for i in {1..3}
do
threads_running=$(${mysql} -u${USER} -p${SECRET} -S${SOCKET} -B -N -e "select count(*) from information_schema.processlist where command not in ('Sleep', 'Binlog Dump', 'Connect', 'Binlog Dump GTID')")
if [ ${threads_running} -gt ${max_running} ];then
  echo "current thread running: ${threads_running}, sleep: ${sleep_seconds}s"
  sleep ${sleep_seconds}
elif [ ${threads_running} -lt ${max_running} ];then
  enabled_backup=1
  echo "start the backup"
  break
fi
done
}

# start to backup
command_check

cat ${cnfdir}/bakcnf |grep "mysqldump" |grep -v "Null" | while read TYPE WEEKLY SLAVE SOCKET PORT MYCNF SECRET INTERVAL IP
do
  dbdir=mysql${PORT}_${IP}
  mkdir_bakdir
  check_query
if [ ${enabled_backup} -eq 1 ];then
  echo ${WEEKLY} | grep -E "$(date +%a)|All" > /dev/null
  if [ $? -eq "0" ];then
    get_dbpass
    if [ -z "$1" ];then
      get_dbname
    else
      DBNAMES="$@"
    fi
    if [ -z "${DBNAMES}" ];then
      echo "no data on ${PORT}" >>  ${localdir}/mysqldump_${bakdate}.log
      check_backup
    else
      ## backup on master
      if [ ${SLAVE} = "N" ];then
        ${mysqldump} -u${USER} -p${SECRET} -S${SOCKET} --default-character-set=utf8 --max_allowed_packet=1G --master-data=2 --single-transaction --flush-logs --hex-blob --routines --triggers --events --databases ${DBNAMES} > ${localdir}/${bakdate}.sql 2> /dev/null
        check_backup
        if [ $? -eq "0" ];then
          clean_backup
        fi
      ## backup on slave
      elif [ ${SLAVE} = "Y" ];then
        ${mysqldump} -u${USER} -p${SECRET} -S${SOCKET} --default-character-set=utf8 --max_allowed_packet=1G --dump-slave=2 --include-master-host-port --single-transaction --hex-blob --routines --triggers --events --databases ${DBNAMES} > ${localdir}/${bakdate}.sql 2> /dev/null
        check_backup
        if [ $? -eq "0" ];then
        clean_backup
        fi
      fi
    fi
  fi
else
  echo "stop the backup: current threads_running > ${max_running}!" >> ${localdir}/mysqldump_${bakdate}.log
fi
done
