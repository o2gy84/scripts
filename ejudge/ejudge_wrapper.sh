#!/bin/bash

#author: v.mogilin, v.mogilin@corp.mail.ru

BIN_PATH=/home/admin/inst-ejudge/bin/
EJ_USERS=ej-users
EJ_USERS_RUN="${BIN_PATH}${EJ_USERS} -D -C /home/admin/judges /home/admin/judges/data/ejudge.xml"

function is_running() {
# returns 0, if process no running
	gr=`pgrep $1`
	if [ -z $gr ]
	then
		return 0
	fi
	return 1
}

function check_process() {
# check and restart process
	is_running $1
	result=$?
	if [ $result -eq "0" ]
	then
		echo "$1 not running.. force start again"
		`$EJ_USERS_RUN &`
	else
		:
		#echo "[debug] process runnnig"
	fi
}


while true; do

	check_process $EJ_USERS
	sleep 1
done

exit 0
