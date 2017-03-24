#!/usr/bin/python

import sys, json

executer = sys.argv[1]
nbtdata = json.loads(sys.argv[2])

# triggers when an entity's entitydata is successfully updated via the entitydata command
# variables are as follows
# ["$executer": Entity data updated to: "$nbtdata"]

try:
	if nbtdata["CustomName"] == "xyz":
		print "say", nbtdata["Pos"][0], nbtdata["Pos"][1], nbtdata["Pos"][2]
except KeyError:
	try:
		if "blend" in nbtdata["Tags"]:
			print 'say test'
	except KeyError:
		pass
