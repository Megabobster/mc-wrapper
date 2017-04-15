#!/usr/bin/python

def mc(command):
	print "mc", command

def wrapper(command):
	print "wrapper", command

import sys, json, math

trigger_type = sys.argv[1]
executer = sys.argv[2]
nbt_data = json.loads(sys.argv[3])
plugin_exit_code = 0

# triggers when an entity's entitydata is successfully updated via the entitydata command
# variables are as follows
# [executer: Entity data updated to: nbt_data]

if nbt_data.get("CustomName") == "trig_marker" and nbt_data.get("trig"):
	speed_modifier = 1
	rotation_rad = [math.radians(nbt_data["Rotation"][0] + 90), math.radians(nbt_data["Rotation"][1] * -1)]
	vertical_modifier = math.cos(rotation_rad[1]) * speed_modifier
	new_motion = [math.cos(rotation_rad[0]) * vertical_modifier, math.sin(rotation_rad[1]) * speed_modifier, math.sin(rotation_rad[0]) * vertical_modifier]
	for i, item in enumerate(new_motion):
		new_motion[i] = round(item,4)
	mc("summon armor_stand " + str(nbt_data["Pos"][0]) + " " + str(nbt_data["Pos"][1]) + " " + str(nbt_data["Pos"][2]) + " {CustomName:\"trig_output\",Motion:[" + str(new_motion[0]) + "d," + str(new_motion[1]) + "d," + str(new_motion[2]) + "d]}")
else:
	plugin_exit_code = 1

exit(plugin_exit_code)
