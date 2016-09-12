#!/bin/bash
#
# restore_check.sh
#

source /root/.bash_profile
softdir=
bakbase=
mysql=${softdir}/mysql/bin/mysql
xtrabackup=${softdir}/dbadmin/script/innobackupex
mysqladmin=${softdir}/mysql/bin/mysqladmin
mymail=${softdir}/dbadmin/script/sendEmail
restoreDir=
restoreLog=${restoreDir}/log/restore.log
portList=${restoreDir}/log/ports.txt
rm -f ${restoreLog}

if [ ! -e ${portList} ];then
  ls -l ${bakbase} |awk -F'mysql' '/mysql/ {print $2}' > ${portList}
fi
# delete old ports
for i in $(cat ${portList})
do
  i=$(echo $i |sed -e 's/#//')
  ls -l ${bakbase} |awk -F'mysql' '/mysql/ {print $2}' |grep $i >/dev/null
  if [ "$?" != "0" ];then
    sed -i "/$i/d" ${portList}
  fi
done
# add new ports
for i in $(ls -l ${bakbase} |awk -F'mysql' '/mysql/ {print $2}')
do
  grep $i ${portList} >/dev/null
  if [ "$?" != "0" ];then
    echo $i >> ${portList}
  fi 
done
# create new port list
if [ "$(grep -cv '#' ${portList})" -eq "0" ];then
  ls -l ${bakbase} |awk -F'mysql' '/mysql/ {print $2}' > ${portList}
fi
# comment the port that will be checked
port=$(grep -m1 -v '#' ${portList})
sed -i "s/${port}$/#${port}/" ${portList}

# Restore DB from mysqldump
mysqldump_restore()
{
  #gunzip -c ${bakFile} > ${restoreDir}/${tool}/${fileName}.sql
  cd ${bakDir};tar -xzf ${fileName}.tar.gz -C ${restoreDir}/${tool}/
  dumpSize=$(du -h ${restoreDir}/${tool}/${fileName}.sql |awk '{print $1}')
  echo "DBPort: ${p}" >> ${restoreLog}
  echo "DumpTool: ${tool}	DumpSize: ${dumpSize}" >> ${restoreLog}
  ## restore dumpfile
  (time ${mysql} -uroot -S${restoreDir}/${tool}/mysql.sock < ${restoreDir}/${tool}/${fileName}.sql)  > ${restoreDir}/log/time_${tool}.log 2>&1
  if [ $? -eq "0" ];then
    echo "RecoveryTime:   $(awk '/real/ {print $NF}' ${restoreDir}/log/time_mysqldump.log)" >> ${restoreLog} 2>&1
    echo -n "RecoveryStatus: Success " >> ${restoreLog}
    ## collect metadata
    dbname=$(${mysql} -uroot -S${restoreDir}/${tool}/mysql.sock -B -N -e "select SCHEMA_NAME from information_schema.SCHEMATA where SCHEMA_NAME not in ('information_schema','mysql','test','performance_schema')" |tr '\n' ' ')
    for db in ${dbname}
    do
      tblNum=$(${mysql} -uroot -S${restoreDir}/${tool}/mysql.sock -B -N -e "select count(*) from information_schema.tables where table_schema='${db}'")
      echo -n "[ ${db}: ${tblNum} tables ] " >> ${restoreLog}
    done
  else
    echo "RecoveryStatus: Fail" >> ${restoreLog}
    cat ${restoreDir}/log/time_${tool}.log >> ${restoreLog}
  fi
  echo "" >> ${restoreLog}
  dbname=$(${mysql} -uroot -S${restoreDir}/${tool}/mysql.sock -B -N -e "select SCHEMA_NAME from information_schema.SCHEMATA where SCHEMA_NAME not in ('information_schema','mysql','test','performance_schema')")
  ## cleanup data
  for db in ${dbname}
  do
    ${mysql} -uroot -S${restoreDir}/${tool}/mysql.sock -e "drop database ${db}" > /dev/null
  done
  rm -f ${restoreDir}/${tool}/${fileName}.sql
}

# Restore DB from xtrabackup
xtrabackup_restore()
{
  cd ${bakDir}
  (time tar -xzf ${bakFile} -C ${restoreDir}/${tool}/) > ${restoreDir}/log/time_${tool}.log 2>&1
  echo "DBPort: ${p}" >> ${restoreLog}
  echo "DumpTool: ${tool}       DumpSize: $(du -sh ${restoreDir}/${tool}/${dataDir} |awk '{print $1}')" >> ${restoreLog}
  echo "RecoveryTime:  $(awk '/real/ {print $NF}' ${restoreDir}/log/time_${tool}.log)" >> ${restoreLog}

  ## configure mysqld startup options
  sed -i -e '/datadir/d' -e '/innodb\_data\_home\_dir/d' -e '/innodb\_log\_group\_home\_dir/d' -e '/innodb\_fast\_checksum/d' -e "/innodb_undo_directory/ s/=.*$/=\/data\/restore\/${tool}\/${dataDir}/" ${restoreDir}/${tool}/${dataDir}/backup-my.cnf
  cat >> ${restoreDir}/${tool}/${dataDir}/backup-my.cnf << EOF
port=3307
socket=${restoreDir}/${tool}/${dataDir}/mysql.sock
datadir=${restoreDir}/${tool}/${dataDir}
innodb_buffer_pool_size=2G
log-error=mysqld.err

[mysql]
user=restore
password=YY18iRSUBoIcrpp4d4Vor78QT
socket=${restoreDir}/${tool}/${dataDir}/mysql.sock
EOF
  chown -R mysql.mysql ${restoreDir}/${tool}/${dataDir}
  cd /data/soft/mysql
  bin/mysqld_safe --defaults-file=${restoreDir}/${tool}/${dataDir}/backup-my.cnf --user=mysql & > /dev/null 2>&1
  sleep 60
  if [ -e ${restoreDir}/${tool}/${dataDir}/mysql.sock ];then
    echo -n "RecoveryStatus: Success" >> ${restoreLog}
    ## collect metadata
    dbname=$(${mysql} --defaults-file=${restoreDir}/${tool}/${dataDir}/backup-my.cnf -B -N -e "select SCHEMA_NAME from information_schema.SCHEMATA where SCHEMA_NAME not in ('information_schema','mysql','test','performance_schema')" |tr '\n' ' ')
    for db in ${dbname}
    do
      tblNum=$(${mysql} --defaults-file=${restoreDir}/${tool}/${dataDir}/backup-my.cnf -B -N -e "select count(*) from information_schema.tables where table_schema='${db}'")
      echo -n "[ ${db}: ${tblNum} tables ]" >> ${restoreLog}
    done
    kill -9 $(ps -ef |grep -v grep |grep backup-my.cnf |awk '{print $2}' |tr '\n' ' ')
    sleep 5
    rm -fr ${restoreDir}/${tool}/*
  else
    echo "RecoveryStatus: mysqld startup fail..." >> ${restoreLog}
    echo "mysqld error log as follow" >> ${restoreLog}
    echo "--------------------------" >> ${restoreLog}
    echo ${restoreDir}/${tool}/${dataDir}/mysqld.err >> ${restoreLog}
  fi
}

# start to restore
for p in "${port}"
do
for tool in mysqldump xtrabackup
do
if [ ${tool} = "mysqldump" ];then
  bakDir=/data/backup/mysql${p}/${tool}
  if [ -e ${bakDir} ];then
    bakFile=$(find ${bakDir} -mtime -1 -type f |grep -v ".log")
    if [ -n "${bakFile}" ];then
      fileName=$(basename ${bakFile} |awk -F'.' '{print $1}')
      mysqldump_restore
    fi
  fi
elif [ ${tool} = "xtrabackup" ];then
  bakDir=/data/backup/mysql${p}/${tool}/full
  if [ -e ${bakDir} ];then
    bakFile=$(find ${bakDir} -mtime -1 -type f |grep -v ".log")
    if [ -n "${bakFile}" ];then
      dataDir=$(basename ${bakFile} |awk -F'.' '{print $1}')
      xtrabackup_restore
    fi
  fi
fi
done
done

# send mail
MAIL_FROM="monitor@cmug.org"
MAIL_TO="zhanghai@cmug.org"
MAIL_CC="dba@cmug.org"
MAIL_SRV="smtp.exmail.qq.com:25"
MAIL_USER="monitor@cmug.org"
MAIL_PASS="xxxxxx"
mail_subject="Restore Check Status"

if [ -e ${restoreLog} ];then
  ${mymail}  -u ${mail_subject} -f ${MAIL_FROM} -t ${MAIL_TO} -cc ${MAIL_CC} -m "$(cat ${restoreLog})" -s ${MAIL_SRV} -xu ${MAIL_USER} -xp ${MAIL_PASS}
else
  ${mymail}  -u ${mail_subject} -f ${MAIL_FROM} -t ${MAIL_TO} -cc ${MAIL_CC} -m "[ mysqld:${port} ] no new db or no crontab!" -s ${MAIL_SRV} -xu ${MAIL_USER} -xp ${MAIL_PASS}
fi
