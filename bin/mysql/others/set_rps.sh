#!/bin/bash
mask=0
i=0
cpu_nums=`cat /proc/cpuinfo |grep processor |wc -l`
if(($cpu_nums==0));then
	exit 0
fi

#nic_queues=`ls /sys/class/net/eth1/queues/ |grep rx- |wc -l`
nic_queues=`ls /sys/class/net/eth0/queues/ |grep rx- |wc -l`
if(($nic_queues==0));then
    exit 0
fi

echo "cpu number" $cpu_nums "nic queues" $nic_queues

mask=$(echo "obase=16;2^$cpu_nums - 1" |bc)
flow_entries=$(echo "$nic_queues * 4096" |bc)

#for i in {0..$nic_queues}
while (($i < $nic_queues))  
do
	#echo $mask > /sys/class/net/eth1/queues/rx-$i/rps_cpus
	#echo 4096 > /sys/class/net/eth1/queues/rx-$i/rps_flow_cnt 
	echo $mask > /sys/class/net/eth0/queues/rx-$i/rps_cpus
	echo 4096 > /sys/class/net/eth0/queues/rx-$i/rps_flow_cnt
	i=$(($i+1)) 
done

echo $flow_entries > /proc/sys/net/core/rps_sock_flow_entries 
