#!/bin/bash
#
# prepare_minion.sh
#

mid_gen()
{
# Automatically generate minion ids for new hosts 
read -p "APP name: " app_name
read -p "IP of master: " master_ip
read -p "Installed of master(yes or no): " master_installed
read -p "IP of slaves(optional): " slave_ips
read -p "Type of DB: " db_type
read -p "Number of instances: " instance_count
if [ "${db_type}" = "mysql" ];then
read -p "Password of root: " rootpass
fi
if [ "${db_type}" = "redis" ];then
read -p "Maxmemory of redis: " redis_memory
if [ -n ${slave_ips} ];then
read -p "VIP of master: " master_vip
fi
fi
read -p "Salt master server: " salt_master_ip

mysql_connect="mysql -uadmin -padmin@cmug.org -h10.1.1.1 -P3306"
mysql_table="runaway.${db_type}_port"

port=$(${mysql_connect} -NBe "select port from ${mysql_table} where app_name='${app_name}' and master_ip='${master_ip}'" 2>/dev/null |tr '\n' '_' |sed 's/_$//')
if [ -z "${port}" ];then
for i in $(seq ${instance_count})
do
${mysql_connect} -e "insert into ${mysql_table} values('${app_name}', '${master_ip}', null)" 2>/dev/null
done
port=$(${mysql_connect} -NBe "select port from ${mysql_table} where app_name='${app_name}' and master_ip='${master_ip}'" 2>/dev/null |tr '\n' '_' |sed 's/_$//')
fi

icount=$(${mysql_connect} -NBe "select count(*) from ${mysql_table} where app_name='${app_name}' and master_ip='${master_ip}'" 2>/dev/null)
if [ "${instance_count}" -gt "${icount}" ];then
delta=$(( ${instance_count} - ${icount} ))
j=0
for i in $(seq ${delta})
do
port_array[$j]=$(${mysql_connect} -NBe "insert into ${mysql_table} values('${app_name}', '${master_ip}', null);select last_insert_id()" 2>/dev/null)
j=$(( $j + 1 ))
done
port=${port}_$(echo ${port_array[*]} |sed 's/ /_/')
fi

master_mid=${app_name}-${db_type}master-${master_ip}-${port}
i=0
for ip in $(echo ${slave_ips})
do
slave_mid[$i]=${app_name}-${db_type}slave-${ip}-${port}
i=$(( $i + 1 ))
done
if [ "${master_installed}" = "no" ];then
mids="${master_mid} ${slave_mid[*]}"
else
mids="${slave_mid[*]}"
fi
}

mid_unaccepted_check()
{
ssh ${salt_master_ip} "salt-key -l unaccepted |grep -w ${mid}" >/dev/null
while [ "$?" != "0" ]
do
sleep 3
ssh ${salt_master_ip} "salt-key -l unaccepted |grep -w ${mid}" >/dev/null
done
}

mid_accepted_check()
{
ssh ${salt_master_ip} "salt '${mid}' test.ping |grep True" >/dev/null
while [ "$?" != "0" ]
do
sleep 5
ssh ${salt_master_ip} "salt '${mid}' test.ping |grep True" >/dev/null
done
}

install_minion()
{
# mids from the mid_gen() func
for mid in ${mids}
do
salt_minion_ip=$(echo ${mid} |awk -F'-' '{print $3}')

ssh ${salt_master_ip} "salt-key -l acc |grep -w ${mid}" >/dev/null
if [ "$?" != "0" ];then
  ssh ${salt_master_ip} "salt-key -l acc |grep ${salt_minion_ip}" >/dev/null
  if [ "$?" = "0" ];then
  ssh ${salt_minion_ip} "service salt-minion stop" >/dev/null
  ssh ${salt_master_ip} "salt-key -y -d '*${salt_minion_ip}*'" >/dev/null
  ssh ${salt_minion_ip} "sed -i -e '/^id:/d' -e '/^#id:/aid: ${mid}' /etc/salt/minion; service salt-minion start" >/dev/null
  mid_unaccepted_check 
  ssh ${salt_master_ip} "salt-key -y -a '*${salt_minion_ip}*'" >/dev/null
  mid_accepted_check
  else
  scp -o StrictHostKeyChecking=no /home/dba/install_minion.sh ${salt_minion_ip}:/tmp >/dev/null
  ssh ${salt_minion_ip} "sh /tmp/install_minion.sh ${mid} ${salt_master_ip}" >/dev/null
  ssh ${salt_minion_ip} "rm -f /tmp/install_minion.sh" >/dev/null
  mid_unaccepted_check 
  ssh ${salt_master_ip} "salt-key -y -a '*${salt_minion_ip}*'" >/dev/null
  mid_accepted_check
  fi
fi
done
}

mongodb_mid()
{
mids="mongodb-rs1-10.1.1.111-27017"
}

mysql_mid()
{
# Notice: manually define variables, if there are slaves in mids, master *must* be in the first place.
# mysql port start from xxxx
mids="opencmug-mysqlslave-10.1.1.135-3306 opencmug-mysqlmaster-10.1.1.199-3306"
master_mid=$(echo ${mids} |awk '{print $1}')
}

redis_mid()
{
# redis port start from xxxx
## eg. mids="opencmug-redismaster01-10.1.1.57-6379 opencmug-redisslave-10.1.1.119-6379_6380_6381_6382"
mids="opencmug-redismaster-10.1.1.97-6379"
echo ${mids} | grep redisslave >/dev/null && read -p "Enter appname-vip-masterip-port(eg. opencmug-10.1.1.193-10.1.1.57-6379): " app_vip_mip_port
echo ${mids} | grep redisslave >/dev/null && read -p "Enter Maxmemory of Redis slaves(eg. 512mb, 1gb): " redis_memory_slave
}

# Notice: manually define variables, if there are slaves in mids, master *must* be in the first place.
mysql_init()
{
ssh ${salt_master_ip} "sh ${salt_master_fileroots}/mysql/mysql_init.sh '${mids}' ${rootpass} ${master_mid}"
}

redis_init()
{
ssh ${salt_master_ip} "sh ${salt_master_fileroots}/redis/redis_init.sh '${mids}' ${redis_version} ${redis_memory} ${app_vip_mip_port} ${redis_memory_slave}"
}

# the following variables for zbxapitool, which preparing for monitor.sls 
read -p "Note: are you sure that the settings of Zabbix are already done (y/n)? " zbx_settings
if [ ${zbx_settings} == "y" ];then
group_name=DBA-MySQL中国用户组-redis
action_name=MySQL中国用户组-redis
condition_like=opencmug-redis
/home/dba/zbxapitool -groupName ${group_name} -actionName ${action_name} -actionCondition ${condition_like} -configType hostgroup

# main process
salt_master_ip=10.1.1.1
salt_master_fileroots=/data/salt/srv/salt

read -p "Enter DB type(eg. mysql, redis, mongodb): " db_type
if [ "${db_type}" = "redis" ];then
read -p "Enter Version(eg. redis28, redis3x): " redis_version
read -p "Enter Maxmemory of Redis masters(eg. 512mb, 1gb): " redis_memory
elif [ "${db_type}" = "mysql" ];then
read -p "Enter MySQL Root Password: " rootpass
fi

${db_type}_mid
install_minion
${db_type}_init
fi
