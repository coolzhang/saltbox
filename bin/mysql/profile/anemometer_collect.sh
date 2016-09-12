#/usr/bin/env bash
#
# anemometer collection script to gather and digest slow query logs
#
# basic usage would be to add this to cron like this:
# 0 7 * * * anemometer_collect.sh
#
#

dbadir=
basedir=
bakcnf=${dbadir}/conf/bakcnf
secret=${dbadir}/script/secret.sh
digest=/usr/local/bin/pt-query-digest
mysql=${basedir}/bin/mysql
mail=${dbadir}/script/sendEmail
errlog=/tmp/anemometer_collect.log
USER=admin

history_db_user=anemometer_user
history_db_pass=anemometer_password
history_db_host=anemometer_server_ip
history_db_port=anemometer_server_port
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
  # path to the slow query log
  slowlog=$( ${mysql} -u${USER} -p${SECRET} -S${SOCKET} -Be "show global variables like 'slow_query_log_file'"  | tail -n1 | awk '{ print $2 }' )
fi

if [ -z "${slowlog}" ];then
  echo "Error getting slow log file location" >> ${errlog}
  exit 1
else 
  # send slowlog to anemometer server
  hostname_max="$(/sbin/ifconfig eth0 |awk '/inet addr:/ {print $2}' |awk -F':' '{print $2}'):${PORT}"
  "${digest}" --user=${history_db_user} --password=${history_db_pass} --port=${history_db_port} \
    --review h="${history_db_host}",D="${history_db_name}",t=global_query_review \
    --history h="${history_db_host}",D="${history_db_name}",t=global_query_review_history \
    --no-report --limit=0\% \
    --filter="\$event->{Bytes} = length(\$event->{arg}) and \$event->{hostname}=\"${hostname_max}\" " \
    "${slowlog}"
  # process the log
  mv "$slowlog" "$slowlog".old
  ${mysql} -u${USER} -p${SECRET} -S${SOCKET} -e "flush logs" >/dev/null 2>&1
  rm -f "$slowlog".old
fi
done

if [ -e ${errlog} ];then
  ${mail} -f monitor@cmug.org -t zhanghai@cmug.org -cc dba@cmug.org -u "Slowlog Collection Failure Report on ${hostname_max}" -m "$(cat ${errlog})" -s smtp.exmail.qq.com -o username=monitor@cmug.org -o password=xxxxxxx
  rm -f ${errlog}
fi
