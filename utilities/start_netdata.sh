#!/usr/bin/env bash
action=$1
echo turn off netdata
{
	killall netdata
	sleep 5
}||{
	echo nothing killed
}
if [ "$action" ==  "on"  ] ; then
	echo turn on netdata
	/usr/sbin/netdata
fi	


