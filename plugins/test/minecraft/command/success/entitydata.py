#!/usr/bin/python

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

import sys, json

executer = sys.argv[1]
nbtdata = json.loads(sys.argv[2])

# triggers when an entity's entitydata is successfully updated via the entitydata command
# variables are as follows
# ["$executer": Entity data updated to: "$nbtdata"]

try:
	if nbtdata["CustomName"] == "xyz":
		mc("say " + " " str(nbtdata["Pos"][0]) + " " + str(nbtdata["Pos"][1]) + " " + str(nbtdata["Pos"][2]))
except KeyError:
	try:
		if "blend" in nbtdata["Tags"]:
			mc("say test")
	except KeyError:
		pass
