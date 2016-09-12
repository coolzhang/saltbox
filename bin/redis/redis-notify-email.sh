#!/bin/bash
#
#

dbadir=
mymail=${dbadir}/script/sendEmail

MAIL_FROM="monitor@cmug.com"
MAIL_TO="zhanghai@cmug.org"
MAIL_CC="dba@cmug.com"
MAIL_SRV="smtp.exmail.qq.com:25"
MAIL_USER="monitor@cmug.org"
MAIL_PASS="xxxxx"
 
if [ "$#" = "2" ]; then
    mail_subject="Redis Failover"
    mail_body=$(cat <<EOB

============================================
Redis Notification Script called by Sentinel
 @$(date +"%Y-%m-%d %H:%M:%S")
============================================
 
Event Type: ${1}
Event Description: ${2}
 
EOB
)
    if [ ${1} == "+switch-master" ];then 
    ${mymail}  -u ${mail_subject} -f ${MAIL_FROM} -t ${MAIL_TO} -cc ${MAIL_CC} -m "${mail_body}" -s ${MAIL_SRV} -xu ${MAIL_USER} -xp ${MAIL_PASS}
    fi
fi
