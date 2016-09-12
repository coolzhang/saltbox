#!/bin/bash
#
#

phone="131abcd0056"
vip={{ vip }}
if [ "$#" = "2" ]; then
  sms=$(cat <<EOB
$(echo "${2}" |awk '{print $1}')(VIP:${vip}) Redis Failover from $(echo "${2}" |awk '{print $2":"$3}') to $(echo "${2}" |awk '{print $4":"$5}') by {{ sentinel_ip }}
EOB
)
  oldip=$(echo "${2}" |awk '{print $2}')
  newip=$(echo "${2}" |awk '{print $4}')
  if [ ${1} == "+switch-master" ];then
    curl http://10.0.1.1:9999/switch/${vip}/${oldip}/${newip} |grep -q "fail" && stat=" Fail!" || stat=" Sucess!"
    curl -d "phone_numbers=${phone}&content=${sms}${stat}&msg_kind=notice&client_id=sa_alert" http://sms.cmug.org/sms/api/send >/dev/null 2>&1
  fi
fi
