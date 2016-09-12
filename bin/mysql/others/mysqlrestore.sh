#!/bin/bash
#
#

echo -n "Port of restoring(e.g, 3306): "
read port
echo -n "Password of new instance: "
read password
echo -n "Date of restoring(e.g, 20160321): "
read dumpdate
echo -n "Tool of restoring(e.g, mysqldump, xtrabackup): "
read tool
echo -n "Role of restoring(e.g, master, slave): "
read role
echo -n "Date of flashback(e.g, 2016-03-24 18:30:00 or null): "
read fbdate

basedir=
datadir=/data/mysql${port}
bakdir=/data/backup/mysql${port}_$(ifconfig eth0 |awk '/inet/ {print $2}' |awk -F':' '{print $2}')
replinfo=${tool}_slave_info
mycnf=my${port}.cnf
socket=${datadir}/mysql.sock
MYSQL=${basedir}/bin/mysql
MYSQLBINLOG=${basedir}/bin/mysqlbinlog

mysqldump_restore()
{
cd ${dumpdir}
echo $(date +%k:%M:%S) Uncompress starting...
tar -xzf ${dumpdate}.tar.gz
if [ "$?" = "0" ];then
echo $(date +%k:%M:%S) Uncompress end and Restore starting...

# check if the instance is now running and is new, otherwise initialize a new instance
netstat -nplt |grep ${port} >/dev/null
if [ "$?" = "0" ];then
  ${MYSQL} -uroot -p${password} -S${socket} -e "set global slow_query_log=0" 2>/dev/null |grep -v "Logging to file"
  if [ "${role}" = "slave" ];then
    ${MYSQL} -uroot -p${password} -S${socket} -e "stop slave" 2>/dev/null |grep -v "Logging to file"
  fi
else
  if [ ! -e "${datadir}" ];then 
    mkdir ${datadir}
    chown mysql.mysql ${datadir}
  fi
  cp ${dumpdir}/${mycnf} ${datadir}/${mycnf}
  master_sid=$(awk -F '=' '/^server-id/ {print $2}' ${mycnf})
  slave_sid=$((${master_sid}+1))
  sed -i -e "/^read_only/ s/0/1/" -e "/^server-id/ s/${master_sid}/ ${slave_sid}/" -e '/innodb_buffer_pool_size/d' -e '/# INNODB #/ainnodb_buffer_pool_size        = 16G' ${datadir}/${mycnf}
  cd ${basedir};scripts/mysql_install_db --defaults-file=${datadir}/${mycnf} --user=mysql >/dev/null 2>&1
  sleep 30
  cd ${basedir};bin/mysqld_safe --defaults-file=${datadir}/${mycnf} --user=mysql & >/dev/null 2>&1
  sleep 10
  ${MYSQL} -uroot -S${socket} -e "set password=password('${password}');set global slow_query_log=0;DELETE FROM mysql.user WHERE User='';DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');DROP DATABASE IF EXISTS test;DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';FLUSH PRIVILEGES;grant replication slave, replication client on *.* to 'repl_user'@'%' identified by 'xxxx';GRANT SELECT, SUPER, PROCESS, REPLICATION CLIENT ON *.* TO 'mpm_user'@'127.0.0.1' identified BY 'xxxxxxx';grant select on *.* to restore_user@localhost identified by 'xxxxxxx';grant all on *.* to admin_user@'10.%' identified by 'xxxxxxxx';GRANT SELECT, INSERT, UPDATE, DELETE ON *.* TO 'anemometer_user'@'%' IDENTIFIED BY 'xxxxxxx'" >/dev/null 2>&1 |grep -v "Logging to file"
fi

${MYSQL} -uroot -p${password} -S${socket} --default-character-set=utf8 --max-allowed-packet=1G --init-command='set sql_log_bin=0' < ${dumpdir}/${dumpdate}.sql 2>/dev/null
if [ "$?" != "0" ];then
echo Restore failed!
rm -f ${dumpdate}.sql
return 1
else
echo $(date +%k:%M:%S) Restore end
rm -f ${dumpdate}.sql
${MYSQL} -uroot -p${password} -S${socket} -e "set global slow_query_log=1" 2>/dev/null |grep -v "Logging to file"
return 0
fi
else
echo Uncompress failed!
return 1
fi
}

xtrabackup_restore()
{
cd ${dumpdir}
echo $(date +%k:%M:%S) Uncompress starting...
tar -xzf ${dumpdate}.tar.gz
if [ "$?" = "0" ];then
echo $(date +%k:%M:%S) Uncompress end and Restore starting...
ps -ef |grep ${port} |grep -v grep |awk '{print $2}' |xargs kill -9
sleep 10
ps -ef |grep ${port} |grep -v grep 2>/dev/null
  if [ "$?" != "0" ];then
  mv ${datadir} ${datadir}_err
  mv ${dumpdate} ${datadir}
  chown -R mysql.mysql ${datadir}
  cp -a ${datadir}_err/${mycnf} ${datadir}/${mycnf}
  cd ${basedir};bin/mysqld_safe --defaults-file=${datadir}/${mycnf} --user=mysql & 2>/dev/null
  echo $(date +%k:%M:%S) mysqld[${port}] starting...
  sleep 10
    pgrep mysqld >/dev/null
    if [ "$?" != "0" ];then
    echo Restore failed!
    return 1
    else
    echo $(date +%k:%M:%S) Restore end
    return 0
    fi
  else
  echo mysqld is still running...
  return 1
  fi
else
echo Uncompress failed!
return 1
fi
}

change_master()
{
echo $(date +%k:%M:%S) Setup replication
echo $(date +%k:%M:%S) Slave replication status
${MYSQL} -uroot -p${password} -S${socket} -e "stop slave;reset slave all" 2>/dev/null |grep -v "Logging to file"
change_master_to=$(sed -e 's/-- //' ${bakdir}/binlog/${dumpdate}/${replinfo})
${MYSQL} -uroot -p${password} -S${socket} -e "${change_master_to}" 2>/dev/null |grep -v "Logging to file"
${MYSQL} -uroot -p${password} -S${socket} -e "start slave" 2>/dev/null |grep -v "Logging to file"
sleep 3
${MYSQL} -uroot -p${password} -S${socket} -e "show slave status\G" 2>/dev/null |grep Running
}

flashback()
{
${MYSQL} -uroot -p${password} -S${socket} -e "show master status" 2>/dev/null |grep -v "Logging to file"
echo $(date +%k:%M:%S) flashbacking to ${fbdate}...
master_host=$(awk -F'[,;=]' '{print $6}' ${bakdir}/binlog/${dumpdate}/${replinfo} |sed -e "s/'//g")
start_pos=$(awk -F'[,;=]' '{print $(NF-1)}' ${bakdir}/binlog/${dumpdate}/${replinfo})
start_file=$(awk -F'[,;=]' '{print $(NF-3)}' ${bakdir}/binlog/${dumpdate}/${replinfo} |sed -e "s/'//g")
${MYSQLBINLOG} -urepl -prepl -h${master_host} --read-from-remote-server --raw --result-file=${bakdir}/binlog/${dumpdate}/ --start-position=${start_pos} --to-last-log ${start_file} 2>/dev/null
cd ${bakdir}/binlog/${dumpdate}
binlog_files=$(ls |grep mysql-bin |tr '\n' ' ')
${MYSQLBINLOG} --stop-datetime="${fbdate}" ${binlog_files} |${MYSQL} -uroot -p${password} -S${socket} 2>/dev/null
if [ "$?" = "0" ];then
echo $(date +%k:%M:%S) flashback end
else
echo $(date +%k:%M:%S) flashback failed!
fi
}

if [ "${tool}" = "mysqldump" ];then
dumpdir=${bakdir}/${tool}
elif [ "${tool}" = "xtrabackup" ];then
dumpdir=${bakdir}/${tool}/full
fi
${tool}_restore
if [ "$?" = "0" ];then
if [ "${role}" = "slave" ];then
change_master
fi
if [ "${role}" = "master" -a -n "$(echo ${fbdate} |sed -e 's/ //g')" ];then
flashback
fi
fi
