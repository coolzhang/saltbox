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
sed -i "/set app_vip_mip_port/ s/\"\"/\"${app_vip_mip_port}\"/" /data/salt/srv/salt/redis/repl.sls
salt "${mid}" state.sls redis.repl
sed -i "/set app_vip_mip_port/ s/\"${app_vip_mip_port}\"/\"\"/" /data/salt/srv/salt/redis/repl.sls
}

redis_monitor()
{
salt "${mid}" state.sls redis.monitor
}

redis_sentinel()
{
sed -i -e "/set app_vip_mip_port/ s/\"\"/\"${app_vip_mip_port}\"/" /data/salt/srv/salt/redis/sentinel.sls
salt "sentinel-*" state.sls redis.sentinel
sed -i -e "/set app_vip_mip_port/ s/\"${app_vip_mip_port}\"/\"\"/" /data/salt/srv/salt/redis/sentinel.sls
}


mids=$1
redis_version=$2
redis_memory=$3
app_vip_mip_port=$4
redis_memory_slave=$5

for mid in ${mids}
do
echo ${mid} |grep redisslave >/dev/null && redis_memory=${redis_memory_slave}
redis_install
[ "${redis_version}" == "redis28" ] && echo ${mid} |grep redisslave >/dev/null && [ -n "${app_vip_mip_port}" ] && redis_repl
redis_monitor
[ -n "${app_vip_mip_port}" ] && redis_sentinel
done
