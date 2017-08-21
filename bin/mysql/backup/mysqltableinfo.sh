#!/bin/bash
#
#

#  ./mysqltableinfo.sh | grep -vE '\-\-|TableName' | sort | awk 'BEGIN{print "TableName Count(*) Partitions"}{a[$1]+=$2;b[$1]+=$3}END{for(i in a)print i,a[i],b[i]}' | sort -n -k2 | column -t 

read -p "Slave IP: " slave_ip
read -p "Slave Port: " slave_port

mysql_connect="mysql -uadmin -popencmug -h${slave_ip} -P${slave_port}"
db_names=$(${mysql_connect} -NBe "select table_schema from information_schema.tables where table_schema not in('mysql','performance_schema','information_schema','test','sys') group by table_schema" 2>/dev/null | grep -v "Logging to")

for db_name in ${db_names}
do
echo ----------------
echo --$db_name
echo ----------------
echo ${db_name} |grep -E '[0-9]$' >/dev/null
if [ "$?" = "0" ];then
table_names=$(${mysql_connect} -NBe "select table_name from information_schema.tables where table_schema='${db_name}' and table_type='BASE TABLE'" 2>/dev/null | grep -v "Logging to" | sed -re 's/_[0-9]+//g' | tr ' ' '\n' | sort | uniq)
echo "TableName Count(*) Partitions"
for table_name in ${table_names}
do
${mysql_connect} -NBe "select table_name,sum(table_rows),count(*) from information_schema.tables where table_schema='${db_name}' and table_name like '${table_name}\_%'" 2>/dev/null | grep -v "Logging to"
done | sort -n -k2 | awk '{sub(/_[0-9]*$/,"",$1);print}'
else
table_names=$(${mysql_connect} -NBe "select table_name from information_schema.tables where table_schema='${db_name}' and table_type='BASE TABLE'" 2>/dev/null | grep -v "Logging to" | sed -re 's/_[0-9]+//g' | tr ' ' '\n' | sort | uniq)
for table_name in ${table_names}
do
table_count=$(${mysql_connect} -NBe "select count(*) from information_schema.tables where table_schema='${db_name}' and table_name like '${table_name}' " 2>/dev/null | grep -v "Logging to")
if [ "${table_count}" = "0" ];then
${mysql_connect} -NBe "select table_name,sum(table_rows),count(*) from information_schema.tables where table_schema='${db_name}' and table_name like '${table_name}\_%'" 2>/dev/null | grep -v "Logging to"
else
${mysql_connect} -NBe "select table_name,sum(table_rows),count(*) from information_schema.tables where table_schema='${db_name}' and table_name like '${table_name}'" 2>/dev/null | grep -v "Logging to"
fi
done | sort -n -k2 | awk '{sub(/_[0-9]*$/,"",$1);print}'
fi
done | column -t
