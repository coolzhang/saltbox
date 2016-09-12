#!/bin/bash
#
# check_backup_stat.sh
#

dbaDir=
baseDir=
bakDir=
logDir=${dbaDir}/log
bakDate=$(date +%Y%m%d)
mysqlbinlog56=${baseDir}/bin/mysqlbinlog
interval=7

fnBackupBinlog()
{
binDir=${bakDir}/${mysqlport}/binlog/${bakDate}
binlog=${binDir}/${tool}_slave_info
master_status=$(grep -m1 -i "change master" ${binlog} |sed -e 's/^-- //' -e 's/,/ /g' -e 's/;//' -e "s/'//g" | awk '{print $4" "$5" "$6" "$7" "$8" "$9}')
master_user=$(echo ${master_status} |awk '{print $1}' |awk -F'=' '{print $2}')
master_pass=$(echo ${master_status} |awk '{print $2}' |awk -F'=' '{print $2}')
master_host=$(echo ${master_status} |awk '{print $3}' |awk -F'=' '{print $2}')
master_port=$(echo ${master_status} |awk '{print $4}' |awk -F'=' '{print $2}')
master_file=$(echo ${master_status} |awk '{print $5}' |awk -F'=' '{print $2}')
master_pos=$(echo ${master_status} |awk '{print $6}' |awk -F'=' '{print $2}')
mysqlbinlog_pid=$(ps -ef |grep -w "${mysqlport}" |grep -w mysqlbinlog |awk '{print $2}')

if [ -n "${mysqlbinlog_pid}" ];then
  kill -9 ${mysqlbinlog_pid}
  sleep 5
fi

nohup ${mysqlbinlog56} -u${master_user} -p${master_pass} -h${master_host} -P${master_port} \
                                 --start-position=${master_pos} --read-from-remote-server --raw \
                                 --stop-never --result-file=${binDir}/ \
                                 ${master_file} 2>/dev/null &
}

fnBinlogSyncCheck()
{
ip_filter="10.1.1.1|10.0.0.1"
binlog_sync_list=${logDir}/binsync.txt
binlog_sync_err_list=${logDir}/binsync.err
cat /dev/null > ${binlog_sync_err_list}
ps -ef |grep mysqlbinlog |grep -v grep |awk '{print $(NF-1)}' |awk -F'/' '{print $4}' > ${binlog_sync_list}

for i in $(ls ${bakDir} |grep mysql)
do
grep $i ${binlog_sync_list} > /dev/null
if [ "$?" != "0" ];then
echo $i >> ${binlog_sync_err_list}
fi
done

if [ "$(grep -cvE "${ip_filter}" ${binlog_sync_err_list})" != "0" ];then
${dbaDir}/script/sendEmail -f monitor@cmug.org -t zhanghai@cmug.org -cc dba@cmug.org -u "Binlog Sync Failure List" -m "$(cat ${binlog_sync_err_list})" -s smtp.exmail.qq.com -xu monitor@cmug.org -xp xxxxxxx
fi
}

fnCleanupDump()
{
find ${dumpDir}/ -mtime +${interval} -type f \( -name "*.gz" -o -name "*.log" \) -delete
find ${bakDir}/${mysqlport}/binlog/ -mtime +${interval} -type d -exec rm -rf {} +
find ${logDir} -mtime +${interval} -type f -name *.log -delete 
}

# function of checking backup log and creating report log
fnCheckDumpLog()
{
if [ -e ${logDir}/dailybackup_report_${bakDate}.log ];then
  rm -f ${logDir}/dailybackup_report_${bakDate}.log
fi

if [ ${tool} = "mysqldump" ];then
  grep "Dump completed" ${dumpLog} > /dev/null
  if [ $? -eq "0" ];then
    fnBackupBinlog
    fnCleanupDump
  else
    echo "${port}: ${tool} failed." >> ${logDir}/dailybackup_report_${bakDate}.log
    fnCleanupDump
  fi
elif [ ${tool} = "xtrabackup" ];then
  grep "completed OK" ${dumpLog} > /dev/null
  if [ $? -eq "0" ];then
    fnBackupBinlog
    fnCleanupDump
  else
    echo "${port}: ${tool} failed." >> ${logDir}/dailybackup_report_${bakDate}.log
    fnCleanupDump
  fi
fi
}

# backup checkup
ports=$(ls ${bakDir} |grep mysql)
for mysqlport in ${ports}
do
  for tool in $(ls ${bakDir}/${mysqlport} |grep -E 'mysqldump|xtrabackup')
  do
    if [ ${tool} = "mysqldump" ];then
      dumpDir=${bakDir}/${mysqlport}/${tool}
    elif [ ${tool} = "xtrabackup" ];then
      dumpDir=${bakDir}/${mysqlport}/${tool}/full 
    fi
    if [ -e ${dumpDir} ];then
      dumpLog=${dumpDir}/${tool}_${bakDate}.log
      if [ -e ${dumpLog} ];then
        fnCheckDumpLog
      fi 
    else
      echo "Backup on ${mysqlport}(${tool}): backup is NOT okay!" >> ${logDir}/dailybackup_report_${bakDate}.log
    fi  
  done
done

if [ -e ${logDir}/dailybackup_report_${bakDate}.log ];then
  ${dbaDir}/script/sendEmail -f monitor@cmug.org -t zhanghai@cmug.org -cc dba@cmug.org -u "Backup Failure Report" -m "$(cat ${logDir}/dailybackup_report_${bakDate}.log)" -s smtp.exmail.qq.com -xu monitor@cmug.org -xp xxxxxxxxx
fi

sleep 5
fnBinlogSyncCheck
