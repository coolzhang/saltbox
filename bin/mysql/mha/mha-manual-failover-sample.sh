#!/bin/bash
# 
#

vip=
app_name=
salt_fileroots=
phone="131abcd0056"
sms=" mha failover(VIP:${vip})"
gconf=${salt_fileroots}/conf/mha/masterha_default.cnf
conf=${salt_fileroots}/conf/mha/mha-${app_name}.cnf
mha_log=/var/log/masterha/${app_name}/${app_name}.log

masterha_master_switch --master_state=alive --global_conf=${gconf} --conf=${conf} --orig_master_is_new_slave --interactive=0 > ${mha_log} 2>&1
grep "completed successfully" ${mha_log} >/dev/null

if [ "$?" = "0" ];then
  oldip=$(grep -E "\(current master\)" ${mha_log} |awk -F'(' '{print $1}')
  newip=$(grep -E "\(new master\)" ${mha_log} |awk -F'(' '{print $1}')
  curl http://10.1.1.1:9999/switch/${vip}/${oldip}/${newip} |grep -q "fail" && stat=" Fail!" || stat=" Sucess!"
  curl -d "phone_numbers=${phone}&content=${app_name}${sms}${stat}&msg_kind=notice&client_id=sa_alert" http://sms.cmug.org/sms/api/send >/dev/null 2>&1
else
  echo ${app_name} ${sms} failed!
  echo -- mha failover log: ${mha_log}
fi
