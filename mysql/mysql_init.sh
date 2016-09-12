#!/bin/bash
#
#

mysql_install()
{
salt "${mid}" state.sls mysql.install
}

mysql_repl()
{
sed -i -e "/set master_mid/ s/\"\"/\"${master_mid}\"/" -e "/set rootpass/ s/\"\"/\"${rootpass}\"/" /data/salt/srv/salt/mysql/repl.sls
salt "${mid}" state.sls mysql.repl
sed -i -e "/set master_mid/ s/\"${master_mid}\"/\"\"/" -e "/set rootpass/ s/\"${rootpass}\"/\"\"/" /data/salt/srv/salt/mysql/repl.sls
}

mysql_monitor()
{
salt "${mid}" state.sls mysql.monitor
}

mysql_backup()
{
salt "${mid}" state.sls mysql.backup
}

prompt()
{
echo -n "new mids: "
read mids
echo -n "root_password: "
read rootpass
echo -n "master_mid: "
read master_mid
}

mids=$1
rootpass=$2
master_mid=$3

for mid in ${mids}
do
mysql_install
sleep 10
mysql_repl
mysql_monitor
mysql_backup
done
