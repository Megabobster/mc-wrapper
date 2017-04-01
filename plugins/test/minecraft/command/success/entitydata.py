#!/usr/bin/python

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

import sys, json

executer = sys.argv[1]
nbt_data = json.loads(sys.argv[2])
plugin_exit_code=0

# triggers when an entity's entitydata is successfully updated via the entitydata command
# variables are as follows
# [executer: Entity data updated to: nbt_data]

if nbt_data.get("CustomName") == "xyz":
	mc("say " + str(nbt_data["Pos"][0]) + " " + str(nbt_data["Pos"][1]) + " " + str(nbt_data["Pos"][2]))
elif nbt_data.get("Tags"):
	if "blend" in nbt_data.get("Tags"):
		mc("say test")
else:
	plugin_exit_code = 1

exit(plugin_exit_code)
