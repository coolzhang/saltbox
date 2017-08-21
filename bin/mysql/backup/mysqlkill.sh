#!/bin/bash
#
#

read -p "Enter process query(e.g, select): " match_sql
read -p "Enter process state(e.g, Sending data): " match_state

user=admin
password=opencmug
mysql=/data/soft/mysql/bin/mysql
mysqladmin=/data/soft/mysql/bin/mysqladmin
sqltext=/data/tmp/mysqlkill.log

${mysql} -u${user} -p${password} -e "set global interactive_timeout = 1;set global wait_timeout = 1;set global max_user_connections = 512"
${mysqladmin} -u${user} -p${password} pro 2>/dev/null | grep -i ${match_sql} |grep "${match_state}" > ${sqltext}
pids=$(${mysqladmin} -u${user} -p${password} pro 2>/dev/null | grep -i ${match_sql} |awk -F'| ' '/'${match_state}'/ {printf $2","}END{print ""}' |sed 's/,$//')
${mysqladmin} -u${user} -p${password} kill $pids
