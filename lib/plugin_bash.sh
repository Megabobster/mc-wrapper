#!/bin/bash

# Not Options?:
DEFAULTS="default_config.txt"
CONFIG="config.txt"

# Load Config:
if ! [ -e "$DEFAULTS" ] ; then
	echo 'Default configuration ('"$DEFAULTS"') not present or renamed, exiting...'
	exit
fi
. "$DEFAULTS"
if ! [ -e "$CONFIG" ] ; then
	echo "$ERR_NEW_CONFIG"
	cp "$DEFAULTS" "$CONFIG"
fi
. "$CONFIG"

# Not Option?:
LEVEL_NAME="$(grep level-name= $MINECRAFT_DIR/server.properties | sed 's/^level-name=//')"

trigger_type="$1"
plugin_exit_code=0

function mc() {
	echo 'mc' $@
}

function mc_ignore_armorstand() {
	echo 'mc_ignore_armorstand' $@
}

function wrapper() {
	echo 'wrapper' $@
}

function debug() {
	echo 'debug' $@
}

# todo: good programming might make grab go away

# function grab runs arbitrary minecraft command and gets arbitrary output
# usage: grab <grab_type> <command ...>
# and it also makes sure it isn't interrupted so you get *only* the output you want
# like so: grab piggy entitydata @r[type=Pig] {}
# then define them in the grab section:
#       elif [ "$grab" = "piggy" ] ; then
#               if echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: The data tag did not change: {.*}$' ; then
#                       (do stuff with the pig's NBT data here; feel free to
#                       get fancy with regex/sed/variables/that kind of stuff)
#               else # make sure to put this else at the end of each grab
#                       mc say "$ERR_INVALID_GRAB" "$grab".
#               fi
# DO NOT FORGET TO DEFINE YOUR GRABS
# it won't break anything (yet) but it makes me sad
# also it doesn't currently work for commands that result in more than one line of output
# for example it throws $ERR_MULTIPLE_GRAB_INPUTS on a failed execute command
function grab() {
	grab_type="$1"
	grab_command="${@:2}"
	mc scoreboard players set "$player" fail 0
	mc "$grab_command"
	mc scoreboard players set "$grab_type" grab 1
}
