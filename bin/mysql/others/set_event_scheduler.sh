#!/bin/bash

bakcnf=/data/soft/dbadmin/conf/bakcnf
secret=/data/soft/dbadmin/script/secret.sh
mysql=/data/soft/mysql/bin/mysql

cat ${bakcnf} | grep -v '#' |head -n1 | while read TYPE WEEKLY SLAVE SOCKET PORT MYCNF SECRET INTERVAL
do
source ${secret}
${mysql} -uroot -p${SECRET} -S${SOCKET} -e "set global event_scheduler=off"
done
