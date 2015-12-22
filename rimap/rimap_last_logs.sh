#!/bin/bash

ALL=""

#for dir in /mnt/maillogs/mycom/f-*-collector.log
for dir in /mnt/maillogs/f-*-collector.log
do
	f=`ls $dir | grep rimap | tail -n 1`
	if [ -n "$f" ]
	then
		full="$dir/$f"
		#echo "$full"
		ALL="${ALL} ${full}"
	fi
done

echo "$ALL"

