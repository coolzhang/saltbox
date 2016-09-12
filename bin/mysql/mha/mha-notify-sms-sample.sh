#!/bin/bash
# 
#

app_name=
phone="131abcd0056"
sms=$(grep 'MySQL Master failover' /var/log/masterha/${app_name}/${app_name}.log |tail -n1)
vip=${VIP}

if [ -n "${sms}" ];then
  sms=${sms}
  oldip=$(echo ${sms} |awk '{print $5}' |awk -F'(' '{print $1}')
  newip=$(echo ${sms} |awk '{print $7}' |awk -F'(' '{print $1}')
  curl http://10.1.1.1:9999/switch/${vip}/${oldip}/${newip} |grep -q "fail" && stat=" Fail!" || stat=" Sucess!"
else
  sms="mha-${app_name}: MySQL failover failed!"
fi
  curl -d "phone_numbers=${phone}&content=${sms}${stat}&msg_kind=notice&client_id=sa_alert" http://sms.cmug.org/sms/api/send >/dev/null 2>&1
