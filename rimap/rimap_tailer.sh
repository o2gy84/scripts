#!/bin/bash

if [ -z $1 ]; then 
    echo "Enter fgrep pattern"
    exit 1
fi

if [ $1 == "-h" ]; then
    echo "denanik@yandex.ru@external"
    echo "danikin1@gmail.com@external"
    exit 1
fi

echo -n "date: "
echo `date`
echo "GREP THIS PATTENR: $1"

tail -f `./rimap_last_logs.sh` | fgrep $1
