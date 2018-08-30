#!/bin/bash
echo begin hosts update...
readonly prefix="# bvt hosts start"
readonly suffix="# bvt hosts end"
readonly remark=", do not edit this line"

if [[ ${1} != "" ]]; then
	loopback=$(sed -n "/127.0.0.1\t${1}/{=;}" /etc/hosts)
	if [[ $loopback != "" ]]; then
		echo "Remove 127.0.0.1 ${1}"	
		x=($loopback)
		y=($loopback)
		ycnt=${#y[@]}
		echo 'script: sed -i "'${x[0]}','${y[$ycnt-1]}'d" /etc/hosts'
		sed -i "${x[0]},${y[$ycnt-1]}d" /etc/hosts
	fi
fi

starter=$(sed -n "/$prefix/{=;}" /etc/hosts)
ender=$(sed -n "/$suffix/{=;}" /etc/hosts)
if [[ $starter == "" ]]; then
	echo insert hostnames into /etc/hosts
else
	echo Replace hostnames in /etc/hosts	
	x=($starter)
	y=($ender)
	ycnt=${#y[@]}
	echo 'script: sed -i "'${x[0]}','${y[$ycnt-1]}'d" /etc/hosts'
	sed -i "${x[0]},${y[$ycnt-1]}d" /etc/hosts
fi
echo $prefix$remark >> /etc/hosts
printf '%b\n' "$(cat /vagrant/hostnames)" >> /etc/hosts
echo $suffix$remark >> /etc/hosts
echo /etc/hosts updated.
