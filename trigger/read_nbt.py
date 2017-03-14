#!/usr/bin/python

import sys, json
nbtdata = json.loads(sys.argv[1])

# triggers when entitydata <entity> {} is run, which spits out the entity's full NBT data
# variables are as follows
# The data tag did not change: "nbtdata"

if nbtdata["CustomName"] == "xyz":
	print "say " + str(nbtdata["Pos"])
