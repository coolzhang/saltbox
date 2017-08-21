#!/bin/bash
# 
#

phone="131xxxx0056"
vip=
app_name=
sms=" mha failover(VIP:${vip})"
mha_log=/var/log/masterha/${app_name}/${app_name}.log
gconf=/data/salt/srv/salt/conf/mha/masterha_default.cnf
conf=/data/salt/srv/salt/conf/mha/mha-${app_name}.cnf

masterha_master_switch --master_state=alive --global_conf=${gconf} --conf=${conf} --orig_master_is_new_slave --interactive=0 > ${mha_log} 2>&1
grep "completed successfully" ${mha_log} >/dev/null

if [ "$?" = "0" ];then
  oldip=$(grep -E "\(current master\)" ${mha_log} |awk -F'(' '{print $1}')
  newip=$(grep -E "\(new master\)" ${mha_log} |awk -F'(' '{print $1}')
  curl http://10.1.1.119:9999/switch/${vip}/${oldip}/${newip} |grep -q "fail" && stat=" Fail!" || stat=" Sucess!"
  curl -d "phone_numbers=${phone}&content=${app_name}${sms}${stat}&msg_kind=notice&client_id=sa_alert" http://sms.china.cmug.org/sms/api/send >/dev/null 2>&1
else
  echo ${app_name} ${sms} failed!
  echo -- mha failover log: ${mha_log}
fi
