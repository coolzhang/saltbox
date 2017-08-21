#!/bin/bash
#
#

phone="131xxxx0056"
vip={{ vip }}
sms="${1} (VIP:${vip}) Redis Failover from ${4}:${5} to ${6}:${7} by {{ sentinel_ip }}"
oldip=${4}
newip=${6}
if [ ${2} == "leader" ];then
  curl http://10.1.1.119:9999/switch/${vip}/${oldip}/${newip} |grep -q "fail" && stat=" Fail!" || stat=" Sucess!"
  curl -d "phone_numbers=${phone}&content=${sms}${stat}&msg_kind=notice&client_id=sa_alert" http://sms.china.cmug.com/sms/api/send >/dev/null 2>&1
fi
