#!/bin/bash
#
#

echo "Notice: binlog_format=row ..."
sleep 1
read -p "Database Name: " dbname
read -p "Table Name: " tblname
read -p "Column Number: " colnum
read -p "Start time(e.g, 2017-07-11 20:00:01): " stime
read -p "Stop time(e.g, 2017-07-12 11:00:01): " etime
read -p "Binlog path: " binpath
read -p "Binlog files: " binlogs

cd ${binpath}
mysqlbinlog -vvv --base64-output=decode-rows --database=${dbname} --start-datetime="${stime}" --stop-datetime="${etime}" ${binlogs} > /data/tmp/${dbname}_binlog.txt
cd /data/tmp
colnum_update=$((colnum*2+2))
colnum_insert=$((colnum+1))
grep -B1 -A${colnum_insert} "INSERT INTO \`${dbname}\`.\`${tblname}\`" ${dbname}_binlog.txt > ${tblname}_binlog.txt
grep -B1 -A${colnum_update} "UPDATE \`${dbname}\`.\`${tblname}\`" ${dbname}_binlog.txt >> ${tblname}_binlog.txt
echo "SQL from ${tblname} on /data/tmp/${tblname}_binlog.txt"
