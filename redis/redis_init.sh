#!/bin/bash
#
#

redis_install()
{
sed -i -e "/set redis_memory/ s/\"\"/\"${redis_memory}\"/" -e "/set redis_version/ s/\"\"/\"${redis_version}\"/" /data/salt/srv/salt/redis/install.sls
salt "${mid}" state.sls redis.install
sed -i -e "/set redis_memory/ s/\"${redis_memory}\"/\"\"/" -e "/set redis_version/ s/\"${redis_version}\"/\"\"/" /data/salt/srv/salt/redis/install.sls
}

redis_repl()
{
sed -i "/set master_mid/ s/\"\"/\"${master_mid}\"/" /data/salt/srv/salt/redis/repl.sls
salt "${mid}" state.sls redis.repl
sed -i "/set master_mid/ s/\"${master_mid}\"/\"\"/" /data/salt/srv/salt/redis/repl.sls
}

redis_monitor()
{
salt "${mid}" state.sls redis.monitor
}

redis_sentinel()
{
sed -i -e "/set master_mid/ s/\"\"/\"${master_mid}\"/" -e "/set master_vip/ s/\"\"/\"${master_vip}\"/" /data/salt/srv/salt/redis/sentinel.sls
salt "sentinel-*" state.sls redis.sentinel
sed -i -e "/set master_mid/ s/\"${master_mid}\"/\"\"/" -e "/set master_vip/ s/\"${master_vip}\"/\"\"/" /data/salt/srv/salt/redis/sentinel.sls
}

prompt()
{
echo -n "master_mid: "
read master_mid
echo -n "master_vip: "
read master_vip
echo -n "maxmemory of redis(e.g, 4gb, 512mb): "
read redis_memory
echo -n "new mids: "
read mids
echo -n "redis_version: "
read redis_version
}

mids=$1
redis_version=$2
redis_memory=$3
master_mid=$4
master_vip=$5

for mid in ${mids}
do
redis_install
echo ${mid} |grep redisslave >/dev/null && redis_repl
redis_monitor
[ -n "${master_vip}" ] && redis_sentinel
done
