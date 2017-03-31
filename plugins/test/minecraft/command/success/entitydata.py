#!/usr/bin/python

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

import sys, json

executer = sys.argv[1]
nbt_data = json.loads(sys.argv[2])

# triggers when an entity's entitydata is successfully updated via the entitydata command
# variables are as follows
# [executer: Entity data updated to: nbt_data]

try:
	if nbt_data["CustomName"] == "xyz":
		mc("say " + " " str(nbt_data["Pos"][0]) + " " + str(nbt_data["Pos"][1]) + " " + str(nbt_data["Pos"][2]))
except KeyError:
	try:
		if "blend" in nbt_data["Tags"]:
			mc("say test")
	except KeyError:
		pass
