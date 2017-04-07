#!/bin/bash

# function output sends output places!
# usage: output <output_type> <output_data ...>
function output () {
	output_type="$1"
	output_data="${@:2}"
	output_formatting=''
	output_destination=''
	output_exit_code=0 # default = acceptable data type
	if [ "$output_data" ] ; then
		# mc executes arbitrary minecraft commands as a marker armorstand
		# mc creates less errors visible to the players
		if [ "$output_type" = "mc" ] ; then
			output_formatting='execute @r[type=armor_stand,name='"$ARMORSTAND"',tag='"$ARMORSTAND"'] ~ ~ ~ '
			output_destination="$MC_INPUT"
		# mc_ignore_armorstand executes arbitrary minecraft commands as the server
		# mc_ignore_armorstand will always work, even if someone runs 'kill @e'
		elif [ "$output_type" = "mc_ignore_armorstand" ] ; then
			output_formatting=''
			output_destination="$MC_INPUT"
		# wrapper sends output to the wrapper in format
		# [timestamp] [Wrapper thread/INFO]: <output>
		# todo: append to latest.log as well as outputting to wrapper
		elif [ "$output_type" = "wrapper" ] ; then
			output_formatting='['"$(date +%H:%M:%S)"'] [Wrapper thread/INFO]: '
			output_destination="$MC_OUTPUT"
		# debug sends output to stdout by leaving the destination empty
		# for debugging purposes only
		elif [ "$output_type" = "debug" ] ; then
			:
		# Error on anything else
		else
			output wrapper "$ERR_OUTPUT_MALFORMED" "$output_type"
			output_exit_code=1
		fi
		# Don't output if it errored previously
		if [ "$output_exit_code" != 1 ] ; then
			# Only pipe the output if there's somewhere to pipe it to
			if [ "$output_destination" ] ; then
				echo "$output_formatting""$output_data" >> "$output_destination"
			else
				echo "$output_formatting""$output_data"
			fi
		fi
	fi
	return "$output_exit_code"
}

# function trigger runs loaded plugin scripts for a specified trigger
# usage: trigger <trigger_type> <trigger_arguments ...>
function trigger() {
	trigger_type="$1"
	trigger_arguments=("${@:2}")
 	trigger_exit_code=1 # default = no match
	# For every loaded plugin...
	for plugin in "${LOADED_PLUGINS[@]}" ; do
		plugin_location=''
		# Search for plugin files matching $plugin/$DEFAULT_PLUGIN and $plugin/$trigger_type
		# Defaults to $DEFAULT_PLUGIN, then checks $trigger_type
		plugin_possible_locations=("$DEFAULT_PLUGIN" "$trigger_type")
		for location in "${plugin_possible_locations[@]}" ; do
			found_plugin="$(pattern=("$PLUGIN_DIR"/"$plugin"/"$location"*) ; echo "${pattern[0]}")"
			# The first matched plugin will be used
			# This attempts to resolve multiple files named $DEFAULT_PLUGIN or $trigger_type
			if [ -z "$plugin_location" -a -e "$found_plugin" ] ; then
				plugin_location="$found_plugin"
			fi
		done
		# If a matching plugin was found
		if [ "$plugin_location" ] ; then
			# Run the plugin, store the stdout and exit code
			plugin_output="$("$plugin_location" "$trigger_type" "${trigger_arguments[@]}")"
			plugin_exit_code="$?"
			# If there was output, read it into the output function
			if [ "$plugin_output" ] ; then
				echo "$plugin_output" | while read output_line ; do
					output_type="$(echo "$output_line" | sed 's/^\([^ ]*\) \(.*\)$/\1/')"
					output_data="$(echo "$output_line" | sed 's/^\([^ ]*\) \(.*\)$/\2/')"
					# If the output function returns an error, report an error with the plugin, too
					# maybe: make the error a function so all string components are within variables
					if ! output "$output_type" "$output_data" ; then
						output wrapper "$ERR_PLUGIN_MALFORMED" \""$plugin"\" \("$trigger_type"\)
					fi
				done
				# Sets the exit code of the trigger to the last non-failure exit code a plugin outputs
				# Unless one plugin succeeds, then it's kept at success
				if [ "$plugin_exit_code" != 1 -a "$trigger_exit_code" != 0 ] ; then
					trigger_exit_code="$plugin_exit_code"
				fi
			fi
		fi
	done
	return "$trigger_exit_code"
}

# Not Options?:
DEFAULTS="default_config.txt"
CONFIG="config.txt"
DEFAULT_PLUGIN="plugin"

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

# Script Initialization:
if ! [ -e "$SCRIPT_NAME" ] ; then
	echo "$ERR_SCRIPT_MISSING"
	exit
elif [ -e "$WRAPPER_PIDFILE" ] ; then
	echo "$ERR_WRAPPER_RUNNING" # maybe: double check pid to see if it's running
	exit
elif [ -e "$SERVER_PIDFILE" -a -e "$MC_INPUT" -a -e "$MC_OUTPUT" ] ; then
	echo "$ERR_SERVER_RUNNING" # maybe: double check pid to see if it's running
elif [ -e "$SERVER_PIDFILE" -o -e "$MC_INPUT" -o -e "$MC_OUTPUT" ] ; then
	echo "$ERR_BAD_EXIT" # maybe: delete leftovers
	exit
# Only runs if there is no mc_io and both pidfiles aren't present
else
	mkfifo "$MC_INPUT"
	mkfifo "$MC_OUTPUT"
	tail --follow=name "$MC_INPUT" | . lib/server_start.sh > "$MC_OUTPUT" &
	echo "SERVER_PID=$!" > "$SERVER_PIDFILE"
fi
echo "WRAPPER_PID=$$" > "$WRAPPER_PIDFILE"

# Prepare initial wrapper state
output mc_ignore_armorstand say "$WRAPPER_INIT_START"
wrapper_status="starting"
# Start main loop
while [ "$wrapper_status" != "done" ] ; do
	# Read $MC_OUTPUT, piped in at the end of the loop
	read line
	line_timestamp="$(echo "$line" | sed 's/^\(\[..:..:..]\) \[\([^]]*\)]: \(.*\)$/\1/')"
	line_status="$(echo "$line" | sed 's/^\(\[..:..:..]\) \[\([^]]*\)]: \(.*\)$/\2/')"
	line_data="$(echo "$line" | sed 's/^\(\[..:..:..]\) \[\([^]]*\)]: \(.*\)$/\3/')"
	# Initial state of the wrapper
	# Don't echo lines here since they can be stale
	if [ "$wrapper_status" = "starting" ] ; then
		if [ "$line_status" = "Server thread/INFO" ] ; then
			# Server just started
			if echo "$line_data" | grep -q '^Starting minecraft server version .*$' ; then
				wrapper_status="booting"
			# Wrapper now starting
			elif echo "$line_data" | grep -q "^\[Server\] $WRAPPER_INIT_START$" ; then # todo: add timestamp requirement; ignore init starts from the past
				echo "$line"
				trigger wrapper/startup
				output mc_ignore_armorstand say "$WRAPPER_INIT_DONE"
				wrapper_status="running"
			fi
		fi
	# Server starting, so echo all lines
	elif [ "$wrapper_status" = "booting" ] ; then
		echo "$line"
		if [ "$line_status" = "Server thread/INFO" ] ; then
			if echo "$line_data" | grep -q "^\[Server\] $WRAPPER_INIT_START$" ; then # todo: add timestamp requirement; ignore init starts from the past
				trigger wrapper/startup
				output mc_ignore_armorstand say "$WRAPPER_INIT_DONE"
				wrapper_status="running"
			fi
		fi
	# Wrapper stopping, so clean up
	# todo: improve this, add a more clean halt condition
	elif [ "$wrapper_status" = "stopping" ] ; then
		echo "$line"
		if [ "$line_status" = "Server thread/INFO" ] ; then
			if echo "$line_data" | grep -q -e "^\[Server\] $WRAPPER_HALT$" -e "^Saving worlds$" ; then
				rm "$WRAPPER_PIDFILE"
				wrapper_status="done"
			elif echo "$line_data" | grep -q "^\[Server\] $WRAPPER_STOP$" ; then
				output mc_ignore_armorstand stop
			fi
		fi
	# Wrapper running
	# All the plugin related stuff happens here
	elif [ "$wrapper_status" = "running" ] ; then
		echo "$line"
		# Output created by the wrapper
		if [ "$line_status" = "Wrapper thread/INFO" ] ; then
			if echo "$line_data" | grep -q "^$WRAPPER_HALTING$" ; then
				trigger wrapper/shutdown "clean"
				output mc_ignore_armorstand say "$WRAPPER_HALT"
				wrapper_status="stopping"
			elif echo "$line_data" | grep -q "^$WRAPPER_STOPPING$" ; then
				trigger wrapper/shutdown "clean"
				output mc_ignore_armorstand say "$WRAPPER_STOP"
				wrapper_status="stopping"
			fi
		# Normal server output
		elif [ "$line_status" = "Server thread/INFO" ] ; then
			# Server stopping
			if echo "$line_data" | grep -q "^Stopping server$" ; then
				trigger wrapper/shutdown "dirty"
				wrapper_status="stopping"
			# Execute style input
			elif echo "$line_data" | grep -q "^\[.*\].*$" ; then
				executer="$(echo "$line_data" | sed 's/^\[\([^]:]*\)[]:] .*$/\1/')"
				# Executed commands
				if echo "$line_data" | grep -q "^\[.*: .*\]$" ; then
					result="$(echo "$line_data" | sed 's/^\[[^:]*: \(.*\)\]$/\1/')"
					# Scoreboard updates
					if echo "$result" | grep -q "^Set score of .* for player .* to .*$" ; then
						objective="$(echo "$result" | sed 's/^Set score of \(.*\) for player \(.*\) to \(.*\)$/\1/')"
						player="$(echo "$result" | sed 's/^Set score of \(.*\) for player \(.*\) to \(.*\)$/\2/')"
						score="$(echo "$result" | sed 's/^Set score of \(.*\) for player \(.*\) to \(.*\)$/\3/')"
						# Trigger grab if it was executed by the marker, it was on the grab objective, and it was set to 1
						if [ "$executer" = "$ARMORSTAND" -a "$objective" = "grab" -a "$score" = "1" ] ; then
							grab="$player"
							# Make sure the last line was an input
							if echo "$last_line" | grep -q '^Set score of fail for player .* to 0$' ; then
								output mc say "$ERR_GRAB_INPUT_NOT_RECEIVED" "$grab".
							# Make sure there was only one input
							elif ! echo "$fail_line" | grep -q '^Set score of fail for player .* to 0$' ; then
								output mc say "$ERR_MULTIPLE_GRAB_INPUTS" "$grab".
							# Run if all conditions are met
							else
								grabber="$(echo "$fail_line" | sed 's/^Set score of \(.*\) for player \(.*\) to \(.*\)$/\2/')"
								if ! trigger wrapper/grab "$grab" "$grabber" "$last_line" ; then
									output mc say "$ERR_INVALID_GRAB" "$grab".
								fi
							fi
						# Otherwise it's just a normal scoreboard update
						else
							trigger minecraft/command/success/scoreboard_score_set "$executer" "$objective" "$player" "$score"
						fi
					# Teleports
					elif echo "$result" | grep -q "^Teleported .* to .*$" ; then
						player="$(echo "$result" | sed 's/^Teleported \(.*\) to \(.*\)$/\1/')"
						destination="$(echo "$result" | sed 's/^Teleported \(.*\) to \(.*\)$/\2/')"
						# If there are coordinates, then treat them as such
						# todo: [0-9]* instead of .*
						if echo "$destination" | grep -q "^.*, .*, .*$" ; then
							x="$(echo "$destination" | sed 's/^\([-.0-9]*\), \([-.0-9]*\), \([-.0-9]*\)$/\1/')"
							y="$(echo "$destination" | sed 's/^\([-.0-9]*\), \([-.0-9]*\), \([-.0-9]*\)$/\2/')"
							z="$(echo "$destination" | sed 's/^\([-.0-9]*\), \([-.0-9]*\), \([-.0-9]*\)$/\3/')"
							trigger minecraft/command/success/teleport_coordinates "$executer" "$player" "$x" "$y" "$z"
						# Otherwise, it's just teleporting one entity to another
						else
							trigger minecraft/command/success/teleport_entity "$executer" "$player" "$destination"
						fi
					# Entitydata updates
					elif echo "$result" | grep -q "^Entity data updated to: .*$" ; then
						nbt_data="$(echo "$line_data" | ./lib/parse_nbt.sed)"
						trigger minecraft/command/success/entitydata "$executer" "$nbt_data"
					# "Saved the world"
					elif echo "$result" | grep -q "^Saved the world$" ; then
						trigger minecraft/command/success/save-all "$executer"
					fi
				# /say messages
				elif echo "$line_data" | grep -q '^\[.*\] .*$' ; then
					message="$(echo "$line_data" | sed 's/^\[[^]]*\] //')"
					trigger minecraft/command/success/say "$executer" "$message"
				fi
			# Execute command failure
			elif echo "$line_data" | grep -q "^Failed to execute '.*' as .*$" ; then
				command="$(echo "$line_data" | sed "s/^Failed to execute '\(.*\)' as \(.*\)$/\1/")"
				executer="$(echo "$line_data" | sed "s/^Failed to execute '\(.*\)' as \(.*\)$/\2/")"
				trigger minecraft/command/failure/execute "$command" "$executer"
			# NBT data dump
			elif echo "$line_data" | grep -q "^The data tag did not change: .*$" ; then
				nbt_data="$(echo "$line_data" | ./lib/parse_nbt.sed)"
				trigger minecraft/command/failure/entitydata_blockdata "$nbt_data"
			# Player message in chat
			elif echo "$line_data" | grep -q '^<.*> .*$' ; then
				player="$(echo "$line_data" | sed 's/^<\([^>]*\)> \(.*\)$/\1/')"
				message="$(echo "$line_data" | sed 's/^<\([^>]*\)> \(.*\)$/\2/')"
				# If the message begins with the prefix, then trigger global_message_prefix
				if echo "$message" | grep -q "^$PREFIX.*$" ; then
					command=($(echo "$message" | sed "s/^"$PREFIX"\(.*\)$/\1/"))
					if ! trigger wrapper/global_message_prefix "$player" "${command[@]}" ; then
						output mc say "$ERR_INVALID_MESSAGE_COMMAND" "${command[0]}".
					fi
				# Otherwise it's just a message
				else
					trigger minecraft/global_message "$player" "$message"
				fi
			else
				trigger minecraft/line "$line_data"
			fi
			# Remember the last few lines of output for the grab trigger
			temp_line="$fail_line"
			fail_line="$last_line"
			last_line="$line_data"
			# Ignore the line if it's a failed execute
			# The command that failed will throw its own error aside from the execute
			if echo "$last_line" | grep -q "^Failed to execute '.*' as .*$" ; then
				last_line="$fail_line"
				fail_line="$temp_line"
			fi
		fi
	fi
# Pipe server output into the loop. Very important.
done < "$MC_OUTPUT"
exit
