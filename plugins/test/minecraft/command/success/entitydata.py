#!/usr/bin/python

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

import sys, json

trigger_type = sys.argv[1]
executer = sys.argv[2]
nbt_data = json.loads(sys.argv[3])
plugin_exit_code = 0

# triggers when an entity's entitydata is successfully updated via the entitydata command
# variables are as follows
# [executer: Entity data updated to: nbt_data]

if nbt_data.get("Tags"):
	if "blend" in nbt_data.get("Tags"):
		mc("say test")
else:
	plugin_exit_code = 1

exit(plugin_exit_code)
