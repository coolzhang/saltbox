#!/bin/bash
#
#

bakcnf=/data/soft/dbadmin/conf/bakcnf
mysql=/data/soft/mysql/bin/mysql
query=/data/tmp/query.sql
USER=admin

if [ -z "$1" ];then
echo Usage: sh $0 dbname
else
cat ${bakcnf} |grep -m1 -v "#" | while read TYPE WEEKLY SLAVE SOCKET PORT MYCNF SECRET INTERVAL IP
do
echo $(date +%k:%M:%S) Query running...
source /data/soft/dbadmin/script/secret.sh
${mysql} -u${USER} -p${SECRET} -S${SOCKET} --default-character-set=utf8 -NB $1 < ${query} 2>/dev/null
if [ "$?" != "0" ];then
echo $(date +%k:%M:%S) Query failed!
else
echo $(date +%k:%M:%S) Query end
\cp ${query} ${query}.old
> ${query}
fi
done
fi
