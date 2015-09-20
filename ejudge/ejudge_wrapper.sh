#!/bin/bash
#author: v.mogilin, v.mogilin@corp.mail.ru

EJ_CONTROL=/home/ejudge/inst-ejudge/bin/ejudge-control
EJ_USERS=ej-users

EJ_PROBLEM_UPLOADER_PATH=/home/ejudge/inst-ejudge-scrips/ej-problems-uploader.py
EJ_PROBLEM_UPLOADER=ej-problems-uploader.py

function is_running()
{
    # returns 0, if process no running

    gr=`pgrep -f $1`
    if [ -z $gr ]
    then
        return 0
    fi
    return 1
}

while true; do

    is_running $EJ_USERS
    result=$?
    if [ $result -eq "0" ]
    then
        echo "$EJ_USERS not running.. restart ejudge!"
        ${EJ_CONTROL} stop
        sleep 1
        ${EJ_CONTROL} start
    else
        :
        #echo "[debug] process (${EJ_USERS}) runnnig OK"
    fi

    is_running $EJ_PROBLEM_UPLOADER
    result=$?
    if [ $result -eq "0" ]
    then
        echo "$EJ_PROBLEM_UPLOADER not running.. restart uploader!"
        nohup ${EJ_PROBLEM_UPLOADER_PATH} 2>/dev/null &
    else
        :
        #echo "[debug] process (${EJ_PROBLEM_UPLOADER}) runnnig OK"
    fi

	sleep 3
done

exit 0
