#!/bin/bash

. default_config.txt
. config.txt

running=1
while [ "$running" = 1 ] ; do
	read line
	if [ "$line" = quit ] ; then
		running=0
	else
		echo "$line" > "$MC_INPUT"
	fi
done
