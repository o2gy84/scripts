#!/bin/bash

ALL=""

for dir in /mnt/maillogs/f-rimap*-collector.log
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
[v.mogilin@grepmaillog2 ~]$ 
[v.mogilin@grepmaillog2 ~]$ 
[v.mogilin@grepmaillog2 ~]$ cat tail_rimap_email.sh 
#!/bin/bash

if [ -z $1 ]; then 
	echo "Enter the email"
	exit 1
fi

if [ $1 == "-h" ]; then
	echo "denanik@yandex.ru@external"
	echo "danikin1@gmail.com@external"

	exit 1
fi

echo -n "date: "
echo `date`
echo "GREP THIS EMAIL: $1"

tail -f `./rimap_logs.sh` | grep $1