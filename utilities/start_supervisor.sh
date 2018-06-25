#!/usr/bin/env bash
action=$1
echo turn off supervisord
{ # try
	svid=$(ps aux | grep [s]upervisord | awk '{print echo $2}')
	if [ "$svid" != "" ]; then
		echo Killing kafka manager
		sudo kill $svid
		sleep 5 # pause 5 sec
	fi
} || { # catch
        echo "Failed to kill supervisord"
}

echo copy sv.*.ini to /etc/supervisord.d/
mkdir /var/log/supervisor
mkdir /etc/supervisord.d
cp /home/vagrant/share/sv.*.ini /etc/supervisord.d/

if [ "$action" ==  "on"  ] ; then
	echo turn on supervisord
	supervisord -c /etc/supervisord.conf
fi	


