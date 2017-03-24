#!/bin/bash

# Sends wrapper output.
# todo: test multiline support
# todo: append to latest.log as well as outputting to wrapper

echo $* | while read line ; do
	echo "["$(date +%H:%M:%S)"] [Wrapper thread/INFO]: $line" >> mc_output
done
