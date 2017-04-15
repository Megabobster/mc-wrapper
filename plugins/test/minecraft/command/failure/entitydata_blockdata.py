#!/usr/bin/python

import sys, json

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

trigger_type = sys.argv[1]
nbt_data = json.loads(sys.argv[2])
plugin_exit_code = 0

# triggers when entitydata <entity> {} is run, which spits out the entity's full NBT data
# variables are as follows
# The data tag did not change: "nbt_data"

# Block data
# I think only blocks have the "id" tag, and all blocks should have it
if nbt_data.get("id"):
	pass
	#mc("say " + str(nbt_data["x"]) + " " + str(nbt_data["y"]) + " " + str(nbt_data["z"]))
# Entity data
# I think all entities have the "Pos" tag
elif nbt_data.get("Pos"):
	pass
	#mc("say " + str(nbt_data["Pos"][0]) + " " + str(nbt_data["Pos"][1]) + " " + str(nbt_data["Pos"][2]))
else:
	plugin_exit_code = 1

exit(plugin_exit_code)
