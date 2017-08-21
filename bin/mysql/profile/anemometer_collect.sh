#/usr/bin/env bash

# anemometer collection script to gather and digest slow query logs
#
# basic usage would be to add this to cron like this:
# 0 7 * * * anemometer_collect.sh
#
#

errlog=/tmp/anemometer_collect.log
bakcnf=/data/soft/dbadmin/conf/bakcnf
secret=/data/soft/dbadmin/script/secret.sh
digest=/usr/local/bin/pt-query-digest
mysql=/data/soft/mysql/bin/mysql
mail=/data/soft/dbadmin/script/sendEmail
USER=backup

history_db_user=anemometer
history_db_pass=opencmug
history_db_host=10.1.1.43
history_db_port=3306
history_db_name=slow_query_log

if [ ! -e "${digest}" ];then
  echo "Error: cannot find digest script at: ${digest}" > ${errlog}
  exit 1
fi

cat ${bakcnf} | grep -v '#' |head -n1 | while read TYPE WEEKLY SLAVE SOCKET PORT MYCNF SECRET INTERVAL
do
if [ ! -e "${secret}" ];then
  echo "Error: cannot find secret script at: ${secret}" >> ${errlog}
  exit 1
else
  source ${secret}
  datadir=$(${mysql} -u${USER} -p${SECRET} -S${SOCKET} -Be "show global variables like 'datadir'"  | awk '/datadir/ {print $2}')
  # slowlog name without full path
  slowlog=$(${mysql} -u${USER} -p${SECRET} -S${SOCKET} -Be "show global variables like 'slow_query_log_file'"  | awk '/slow_query_log_file/ {print $2}')
fi

if [ -z "${slowlog}" ];then
  echo "Error getting slow log file location" >> ${errlog}
  exit 1
else 
  cd ${datadir}
  # send slowlog to anemometer server
  hostname_max="$(/sbin/ifconfig eth0 |awk '/inet addr:/ {print $2}' |awk -F':' '{print $2}'):${PORT}"
  "${digest}" --user=${history_db_user} --password=${history_db_pass} --port=${history_db_port} \
    --review h="${history_db_host}",D="${history_db_name}",t=global_query_review \
    --history h="${history_db_host}",D="${history_db_name}",t=global_query_review_history \
    --no-report --limit=0\% \
    --filter="\$event->{Bytes} = length(\$event->{arg}) and \$event->{hostname}=\"${hostname_max}\" " \
    ${slowlog}
  # process slow log
  mv ${slowlog} ${slowlog}.$(date +%Y%m%d --date='-1 day')
  ${mysql} -u${USER} -p${SECRET} -S${SOCKET} -e "flush logs" >/dev/null 2>&1
  slowlog=$(basename ${slowlog})
  find . -name ${slowlog}.[0-9]\* -mtime +7 -type f -delete
  
fi
done

if [ -e ${errlog} ];then
  ${mail} -f monitor@cmug.org -t lafeng@cmug.org -cc lafeng@cmug.org -u "Slowlog Collection Failure Report on ${hostname_max}" -m "$(cat ${errlog})" -s smtp.exmail.qq.com -o username=monitor@cmug.org -o password=opencmug
  rm -f ${errlog}
fi
