#!/usr/bin/python

import sys, json

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

nbt_data = json.loads(sys.argv[1])

# triggers when entitydata <entity> {} is run, which spits out the entity's full NBT data
# variables are as follows
# The data tag did not change: "nbt_data"

# Block data
try:
	if nbt_data["id"]:
		mc("say " + str(nbt_data["x"]) + " " + str(nbt_data["y"]) + " " + str(nbt_data["z"]))
# Entity data
except KeyError:
	try:
		if nbt_data["CustomName"] == "xyz":
			mc("say " + str(nbt_data["Pos"][0]) + " " + str(nbt_data["Pos"][1]) + " " + str(nbt_data["Pos"][2]))
	except KeyError:
		pass
