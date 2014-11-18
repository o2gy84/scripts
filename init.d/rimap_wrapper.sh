#!/bin/bash

DAEMON_NAME=collector
PIDFILE="/var/run/${DAEMON_NAME}.pid"
WRAPPER_PIDFILE="/var/run/${DAEMON_NAME}-wrapper.pid"

LOG="/var/log/collector_error.log"



if [ -f $WRAPPER_PIDFILE ];then
        if kill -0 `cat $WRAPPER_PIDFILE` ;then \
                echo "Already started!"
                exit 1
        else
                echo "It was started but it is dead now"
        fi
fi

echo $$ > $WRAPPER_PIDFILE


while true
do
        ulimit -n 650000
        ulimit -c unlimited
        nohup /usr/local/mpop/libexec/collector --proto=imap >> ${LOG} 2>&1 &
        CHILDPID=$!
        echo $CHILDPID > $PIDFILE
        wait $CHILDPID
        rm -f $PIDFILE
        sleep 2
done

