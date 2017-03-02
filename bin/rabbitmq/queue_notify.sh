#!/bin/bash
#
#

source /root/.bash_profile
rabbitmqcmd=$(which rabbitmqctl)
mymail=/usr/bin/sendEmail
vhosts=$(${rabbitmqcmd} list_vhosts | grep -iv "Listing vhosts")
email_ready=3000
email_unack=3000
sms_ready=6000
sms_unack=6000

email_notification()
{
mail_from="monitor@cmug.org"
mail_to="zhanghai@cmug.org"
mail_cc="dba@cmug.org"
mail_srv="smtp.exmail.qq.com:25"
mail_user="monitor@cmug.org"
mail_pass="xxxxx"
mail_subject="MQ Warning"
ip=$(/sbin/ifconfig eth0 | awk '/inet addr:/ {print $2}' | awk -F':' '{print $2}')
mail_prefix="[RabbitMQ@${ip}]"
mail_body="${mail_prefix} ${mail_body}"
${mymail}  -u ${mail_subject} -f ${mail_from} -t ${mail_to} -cc ${mail_cc} -m "${mail_body}" -s ${mail_srv} -xu ${mail_user} -xp ${mail_pass}
}

sms_notification()
{
ip=$(/sbin/ifconfig eth0 | awk '/inet addr:/ {print $2}' | awk -F':' '{print $2}')
sms_prefix="[RabbitMQ@${ip}]"
sms_content="${sms_prefix} ${sms_body}"
phones="131abcd0056"
curl -d "phone_numbers=${phones}&content=${sms_content}&msg_kind=notice&client_id=sa_alert" http://sms.cmug.org/sms/api/send >/dev/null 2>&1
}


for vhost in $vhosts
do
${rabbitmqcmd} -p ${vhost} list_queues name messages_ready messages_unacknowledged | grep -v 'queues' | while read queue_name msg_ready msg_unack
do
if [ "${msg_ready}" -ge "${email_ready}" -a "${msg_ready}" -lt "${email_ready}" ];then
mail_body="Queue ${vhost}.${queue_name} Ready: ${msg_ready}"
email_notification
elif [ "${msg_ready}" -ge "${sms_ready}" ];then
sms_body="Queue ${vhost}.${queue_name} Ready: ${msg_ready}"
sms_notification
fi
if [ "${msg_unack}" -ge "${email_unack}" -a "${msg_unack}" -lt "${email_unack}" ];then
mail_body="Queue ${vhost}.${queue_name} Unacked: ${msg_unack}"
email_notification
elif [ "${msg_unack}" -ge "${sms_unack}" ];then
sms_body="Queue ${vhost}.${queue_name} Unacked: ${msg_unack}"
sms_notification
fi
done
done

hosts=$(${rabbitmqcmd} cluster_status | grep running_nodes | awk -F'[,@]' '{print $3" "$5" "$7}' | sed -e 's/]}//')
for host in ${hosts}
do
ip=$(getent hosts ${host} | awk '{print $1}' | grep -v "127.0.0.1")
nc -z ${ip} 5672 | grep succeeded >/dev/null
if [ "$?" != "0" ];then
sms_body="${host}@${ip} is not okay"
sms_notification
fi
done

partitions=$(${rabbitmqcmd} cluster_status | awk -F'[,}]' '/partitions/ {print $2}')
if [ "${partitions}" != "[]" ];then
sms_body="*${partitions}* network partition happend"
sms_notification
fi
