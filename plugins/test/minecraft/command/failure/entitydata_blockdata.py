#!/usr/bin/python

import sys, json

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

nbtdata = json.loads(sys.argv[1])

# triggers when entitydata <entity> {} is run, which spits out the entity's full NBT data
# variables are as follows
# The data tag did not change: "nbtdata"

# Block data
try:
	if nbtdata["id"]:
		mc("say " + str(nbtdata["x"]) + " " + str(nbtdata["y"]) + " " + str(nbtdata["z"]))
# Entity data
except KeyError:
	try:
		if nbtdata["CustomName"] == "xyz":
			mc("say " + str(nbtdata["Pos"][0]) + " " + str(nbtdata["Pos"][1]) + " " + str(nbtdata["Pos"][2]))
	except KeyError:
		pass
