#!/usr/bin/python

import sys, json
nbtdata = json.loads(sys.argv[1])

# triggers when entitydata <entity> {} is run, which spits out the entity's full NBT data
# variables are as follows
# The data tag did not change: "nbtdata"

# Block data
try:
	if nbtdata["id"]:
		print "say", nbtdata["x"], nbtdata["y"], nbtdata["z"]
# Entity data
except KeyError:
	if nbtdata["CustomName"] == "xyz":
		print "say", nbtdata["Pos"][0], nbtdata["Pos"][1], nbtdata["Pos"][2]
