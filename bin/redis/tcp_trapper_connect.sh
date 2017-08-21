#!/bin/bash
####zabbix system connect trapper####
# by Cailu


file=/etc/zabbix/ret/system_connect
OPTION=(CONN[TIME_WAIT] CONN[ESTABLISHED] CONN[SYN_RECV] CONN[FIN_WAIT] CONN[CLOSE_WAIT])
UinxTimeStamp=$(date "+%s")
PostLog="/etc/zabbix/ret/postlog"

host=zabbix_agent_hostname
server=zabbix_server_ip

COMMAND() {
             case $2 in
                    "CONN[TIME_WAIT]")
                        netstat -tn | awk '/TIME_WAIT/{++NUM}END{print NUM}'
                      ;;
                    "CONN[ESTABLISHED]")
                        netstat -tn | awk '/ESTABLISHED/{++NUM}END{print NUM}'
                      ;;
                    "CONN[SYN_RECV]")
                        netstat -tn | awk '/SYN_RECV/{++NUM}END{print NUM}'
                      ;;
                    "CONN[FIN_WAIT]")
                        netstat -tn | awk '/FIN_WAIT/{++NUM}END{print NUM}'
                      ;;
                    "CONN[CLOSE_WAIT]")
                        netstat -tn | awk '/FIN_WAIT/{++NUM}END{print NUM}'
                      ;;
             esac
}


/bin/rm -fr ${file}

 
for((i=0;i<${#OPTION[@]};i++))
do
        Middle=$(COMMAND ${host} ${OPTION[${i}]})
        ret=${Middle:-0}
        key=$(echo ${OPTION[${i}]})
        echo "${host}" "${key}" "${UinxTimeStamp}" "${ret}" >> ${file}
done
 

sleep 2
echo >> ${PostLog}
date "+%F %H:%M" >> ${PostLog}

zabbix_sender -z ${server} -p 10051 -i ${file} -T -vv &>> ${PostLog}

echo $((RANDOM % 100))
