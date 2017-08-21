#!/bin/bash

bakcnf=/data/soft/dbadmin/conf/bakcnf
secret=/data/soft/dbadmin/script/secret.sh
mysql=/data/soft/mysql/bin/mysql

cat ${bakcnf} | grep -v '#' |head -n1 | while read TYPE WEEKLY SLAVE SOCKET PORT MYCNF SECRET INTERVAL
do
source ${secret}
${mysql} -uadmin -p${SECRET} -S${SOCKET} -e "set global slow_query_log=1;set global long_query_time=1;set global log_queries_not_using_indexes=0"
#${mysql} -uroot -p${SECRET} -S${SOCKET} -e "grant select,super on *.* to anemometer@'%' identified by 'opencmug'"
#${mysql} -uroot -p${SECRET} -S${SOCKET} -e "set global max_allowed_packet=1073741824"
done
