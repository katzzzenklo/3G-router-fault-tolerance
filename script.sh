#!/bin/sh

echo "----------------------------------------------"
date

#Site1
KCELL_SERVER1=10.101.110.63
BEELINE_SERVER1=10.113.89.204
#Site2
KCELL_SERVER2=10.101.110.64
BEELINE_SERVER2=10.113.89.209

. /mnt/rwfs/settings/settings.openvpn
. /mnt/rwfs/settings/settings.ppp



if [ `uptime | awk '{print $4}'` = "min," ] && [ `uptime | awk '{print $3}'` -lt "5" ]; then
	echo "too early"
	exit
fi

if [ "$PPP_SIMCARD" = "0" ]; then 
	echo "no connection"
	exit
fi

if [ "$OPENVPN_STAT" = "0" ]; then
	echo "openvpn is turned off"
	exit
fi

if ifconfig | grep -q '10.197'; then
	if  ! ping -c 10 10.197.0.1 | grep '100% packet loss'; then
	echo "openvpn tunnel is up"
		exit
	fi
fi
if ifconfig | grep -q '10.199'; then
	if ! ping -c 10 10.199.0.1 | grep '100% packet loss'; then
	echo "openvpn tunnel is up"
		exit
	fi
fi
echo "openvpn tunnel is down"
switch_server
switch_sim
switch_server
echo "connection failed. rebooting"
reboot

switch_server ()
{
	OPERATOR="none"
	if ifconfig | grep -q '10.101'; then
		OPERATOR='KCELL'
	fi
	if ifconfig | grep -q '10.113'; then
		OPERATOR='BEELINE'
	fi
	case $OPERATOR in
		'KCELL')
			echo "kcell"
			check_connection $KCELL_SERVER1 
			check_connection $KCELL_SERVER2
			;;
		'BEELINE')
			echo "beeline"
			check_connection $BEELINE_SERVER1
			check_connection $BEELINE_SERVER2
			;;
	esac
}

check_connection ()
{
	ntpdate -b "$1"
	sed -i "s/^OPENVPN_REMOTE_IPADDR=.*/OPENVPN_REMOTE_IPADDR=$1/" /mnt/rwfs/settings/settings.openvpn
	/etc/init.d/openvpn restart
	sleep 40
	if ifconfig | grep -q 'tun0'; then
		echo "tunnel is up. connected to $1"
		exit
	fi
	echo "can't connect to $1"
}

switch_sim ()
{
	echo "sim switching"
	SIM1=`cat /sys/class/gpio/SIM1_PRES/value`
	SIM2=`cat /sys/class/gpio/SIM2_PRES/value`
	if [ "$PPP_SIMCARD" = 2 ] && [ "$SIM1" = "1" ] || [ "$PPP_SIMCARD" = 1 ] && [ "$SIM2" = "1" ]; then
		echo "one sim is absent"
		exit
	fi
	if [ "$PPP_SIMCARD" = "1" ]; then
		next_sim="2"
	else next_sim="1"
	fi
	sed -i "s/^PPP_SIMCARD=.*/PPP_SIMCARD=$next_sim/" /mnt/rwfs/settings/settings.ppp
	/etc/init.d/ppp restart
	sleep 150
}

