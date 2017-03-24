#!/bin/bash

. default_config.txt
. config.txt

running=1
while [ "$running" = 1 ] ; do
	read line
	if [ "$line" = quit ] ; then
		running=0
	elif [ "$line" = halt ] ; then
		./mc_output.sh "Wrapper halting..." # todo: config
	elif [ "$line" = start ] ; then
		./mc_wrapper.sh
	elif [ "$line" = help ] ; then # todo: better help message
		echo "quit	quits this"
		echo "halt	kills the wrapper"
		echo "start	starts the wrapper"
		echo "help	displays this help message"
	else
		echo "$line" >> "$MC_INPUT"
	fi
done
