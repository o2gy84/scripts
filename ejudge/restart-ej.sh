#!/bin/bash

#author: v.mogilin, v.mogilin@corp.mail.ru

# NB: first need to restart only ej-contest process !

BIN_PATH=/home/ejudge/inst-ejudge/bin/
EJ_CONTEST=ej-contests
EJ_USERS=
EJ_JOBS=
EJ_COMPILE=
EJ_SUPER_RUN=
EJ_SUPER_SERVER=

EJ_CONTEST_RUN="${BIN_PATH}${EJ_CONTEST} -D -C /home/ejudge/judges /home/ejudge/judges/data/ejudge.xml"

function check_process() {
	gr=`pgrep $1`
	if [ -z $gr ]
	then
		:
		echo "not runnig"
	else
		kill -9 $gr
		echo "killed $gr"
	fi

	`$EJ_CONTEST_RUN &`
}

check_process $EJ_CONTEST

exit 0
