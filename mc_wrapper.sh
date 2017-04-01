#!/bin/bash

# notes:
# google minecraft server fifo for other people's projects? not really helpful
# maybe: look up minecraft /trigger command, maybe use that to help with triggers and grabs, possibly need to hardcore use that since op might be required?
# todo: ops support/permission levels
# todo: stderr https://google.github.io/styleguide/shell.xml?showone=STDOUT_vs_STDERR#STDOUT_vs_STDERR
# todo: add constants (variables) for where files/fifos are stored and what tmux sessions are named
# maybe: constants in separate config file/"include"
#	https://google.github.io/styleguide/shell.xml?showone=Constants_and_Environment_Variable_Names#Constants_and_Environment_Variable_Names
#	idea for plugins: source plugins/*
#	would load everything in plugins directory at a certain point in the script, might be worth looking into
# maybe: minecraft_server.jar >> mc_output.txt then in scripts tail -f mc_output.txt might allow multiple scripts simultaneously
#	read current directory, check if it's scripts directory, autostart scripts, that kind of thing
# maybe: figure out "if" regex to reduce echo $line | grep $* and echo $line | sed s/// if at all possible (bash substitution regex/glob? see man [)
#	https://google.github.io/styleguide/shell.xml?showone=Builtin_Commands_vs._External_Commands#Builtin_Commands_vs._External_Commands
# maybe: sed variable for current time, trigger for current time? (time=$(echo $line | grep ^[...
# todo: way to list current players (/list + regex)
# maybe: player voting (based on scoreboards)
# todo: trigger on more things like /me
# todo: currently no way to admin server from command line, possibly allow command line input via wrapper (or maybe background then read in a loop)
#	http://tldp.org/LDP/abs/html/special-chars.html (ctrl+f "cat -"), or cat > mc_input (if I can get it to terminate when the server does)
# todo: let the player run a backup and give it a clickable link for download, unless a backup has been run in the last [time interval]
# todo: way to get player coordinates (summon a marker, tp marker to $player, get marker's xyz (tp to ~ ~ ~) and entitydata (for rotation)
#	@e[type=armor_stand,name="$PLAYER",tag="$ARMORSTAND"] maybe?
#	do as much of this as possible in game to make it faster
#	then triiiiiiiiig
# todo: write clear for block inventories
# todo: consistent quoting scheme
# todo: todos

# function output sends output places!
# usage: output <output_type> <output_data ...>
function output () {
	output_type="$1"
	output_data="${@:2}"
	output_formatting=''
	output_destination=''
	output_exit_code=0 # default = acceptable data type
	if [ "$output_data" ] ; then
		# debug sends output to stdout for debugging purposes
		if [ "$output_type" = "debug" ] ; then
			output_formatting=''
			output_destination=''
		# mc executes arbitrary minecraft commands as a marker armorstand
		# mc creates less errors visible to the players
		elif [ "$output_type" = "mc" ] ; then
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
		else
			output wrapper "$ERR_OUTPUT_MALFORMED" "$output_type"
			output_exit_code=1
		fi
		if [ "$output_exit_code" != 1 ] ; then
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
	for plugin in "${LOADED_PLUGINS[@]}" ; do
		if [ -e "$PLUGIN_DIR"/"$plugin"/"$trigger_type" ] ; then
			plugin_output="$("$PLUGIN_DIR"/"$plugin"/"$trigger_type" "${trigger_arguments[@]}")"
			plugin_exit_code="$?"
			echo "$plugin_output" | while read output_line ; do
				output_type="$(echo "$output_line" | sed 's/^\([^ ]*\) \(.*\)$/\1/')"
				output_data="$(echo "$output_line" | sed 's/^\([^ ]*\) \(.*\)$/\2/')"
				if ! output "$output_type" "$output_data" ; then # run output, but if it returns an error code, return an error for this line from the plugin
					output wrapper "$ERR_PLUGIN_MALFORMED" \""$plugin"\" \("$trigger_type"\) # maybe: make this a function so all string components are within variables
				fi
			done
			if [ "$plugin_exit_code" != 1 -a "$trigger_exit_code" != 0 ] ; then
				trigger_exit_code="$plugin_exit_code"
			fi
		fi
	done
	return "$trigger_exit_code"
}

# Not Options?:
DEFAULTS="default_config.txt"
CONFIG="config.txt"
WRAPPER_DIR="$(pwd)" # todo: figure this the hell out, I think this script must be run from PWD to function
OUTPUT_TYPES=("debug" "mc" "mc_ignore_armorstand" "wrapper") # todo: implement this into output

# Load Config:
if ! [ -e "$DEFAULTS" ] ; then
	echo 'Default configuration ('"$DEFAULTS"') not present or renamed, exiting...'
	exit # maybe: put default settings here instead of in a separate file, then generate config.txt
fi
. "$DEFAULTS"
if ! [ -e "$CONFIG" ] ; then
	echo "$ERR_NEW_CONFIG"
	cp "$DEFAULTS" "$CONFIG" # todo: make this fancier?
fi
. "$CONFIG"

# Not Option?:
LEVEL_NAME="$(grep level-name= $MINECRAFT_DIR/server.properties | sed 's/^level-name=//')"

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
else # only runs if there is no mc_io and both pidfiles aren't present
	mkfifo "$MC_INPUT"
	mkfifo "$MC_OUTPUT"
	tail --follow=name "$MC_INPUT" | . lib/server_start.sh > "$MC_OUTPUT" & # todo: maybe use cat instead of tail, also make this not output stuff on tail's end
	echo "SERVER_PID=$!" > "$SERVER_PIDFILE"
fi
echo "WRAPPER_PID=$$" > "$WRAPPER_PIDFILE"

output mc_ignore_armorstand say "$WRAPPER_INIT_START"
wrapper_status="starting"
while [ "$wrapper_status" != "done" ] ; do
	read line
	line_timestamp="$(echo "$line" | sed 's/^\(\[..:..:..]\) \[\([^]]*\)]: \(.*\)$/\1/')"
	line_status="$(echo "$line" | sed 's/^\(\[..:..:..]\) \[\([^]]*\)]: \(.*\)$/\2/')"
	line_data="$(echo "$line" | sed 's/^\(\[..:..:..]\) \[\([^]]*\)]: \(.*\)$/\3/')"
	if [ "$wrapper_status" = "starting" ] ; then
		if echo "$line_data" | grep '^Starting minecraft server version .*$' ; then
			wrapper_status="booting"
		elif echo "$line" | grep "^\[..:..:..\] \[Server thread/INFO\]: \[Server\] $WRAPPER_INIT_START$" ; then # todo: add timestamp requirement; ignore init starts from the past
			trigger wrapper/startup
			output mc_ignore_armorstand say "$WRAPPER_INIT_DONE"
			wrapper_status="running"
		fi
	elif [ "$wrapper_status" = "booting" ] ; then
		echo "$line"
		if echo "$line_data" | grep -q '^Done (.*)! For help, type "help" or "?"$' ; then # todo: make sure this is indeed outputting everything
			wrapper_status="starting"
		fi
	elif [ "$wrapper_status" = "stopping" ] ; then
		echo "$line"
		if echo "$line_data" | grep -q -e "^\[Server\] $WRAPPER_HALT" -e "^Saving worlds$" ; then
			rm "$WRAPPER_PIDFILE"
			wrapper_status="done"
		fi
	elif [ "$wrapper_status" = "running" ] ; then
		echo "$line"
		if [ "$line_status" = "Wrapper thread/INFO" ] ; then

			if echo "$line_data" | grep -q "^Wrapper halting...$" ; then
				trigger wrapper/shutdown
				output mc_ignore_armorstand say "$WRAPPER_HALT"
				wrapper_status="stopping"
			fi
		elif [ "$line_status" = "Server thread/INFO" ] ; then
			# Server stopping
			if echo "$line_data" | grep -q "^Stopping server$" ; then
				trigger wrapper/shutdown
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
						if [ "$executer" = "$ARMORSTAND" -a "$objective" = "grab" -a "$score" = "1" ] ; then
							grab="$player"
							if echo "$last_line" | grep -q '^Set score of fail for player .* to 0$' ; then
								output mc say "$ERR_GRAB_INPUT_NOT_RECEIVED" "$grab".
							elif ! echo "$fail_line" | grep -q '^Set score of fail for player .* to 0$' ; then
								output mc say "$ERR_MULTIPLE_GRAB_INPUTS" "$grab".
							else
								grabber="$(echo "$fail_line" | sed 's/^Set score of \(.*\) for player \(.*\) to \(.*\)$/\2/')"
								if ! trigger wrapper/grab "$grab" "$grabber" "$last_line" ; then
									output mc say "$ERR_INVALID_GRAB" "$grab".
								fi
							fi
						else
							trigger minecraft/command/success/scoreboard_score_set "$executer" "$objective" "$player" "$score"
						fi
					# Teleports
					elif echo "$result" | grep -q "^Teleported .* to .*$" ; then
						player="$(echo "$result" | sed 's/^Teleported \(.*\) to \(.*\)$/\1/')"
						destination="$(echo "$result" | sed 's/^Teleported \(.*\) to \(.*\)$/\2/')"
						if echo "$destination" | grep -q "^.*, .*, .*$" ; then
							x="$(echo "$destination" | sed 's/^\([-.0-9]*\), \([-.0-9]*\), \([-.0-9]*\)$/\1/')"
							y="$(echo "$destination" | sed 's/^\([-.0-9]*\), \([-.0-9]*\), \([-.0-9]*\)$/\2/')"
							z="$(echo "$destination" | sed 's/^\([-.0-9]*\), \([-.0-9]*\), \([-.0-9]*\)$/\3/')"
							trigger minecraft/command/success/teleport_coordinates "$executer" "$player" "$x" "$y" "$z"
						else
							trigger minecraft/command/success/teleport_entity "$executer" "$player" "$destination"
						fi
					# Entitydata updates
					elif echo "$result" | grep -q "^Entity data updated to: .*$" ; then
						nbt_data="$(echo "$line_data" | ./lib/parse_nbt.sed)"
						trigger minecraft/command/success/entitydata.py "$executer" "$nbt_data"
					# Saved the world
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
				trigger minecraft/command/failure/entitydata_blockdata.py "$nbt_data"
			# Player message in chat
			elif echo "$line_data" | grep -q '^<.*> .*$' ; then
				player="$(echo "$line_data" | sed 's/^<\([^>]*\)> \(.*\)$/\1/')"
				message="$(echo "$line_data" | sed 's/^<\([^>]*\)> \(.*\)$/\2/')"
				if echo "$message" | grep -q "^$PREFIX.*$" ; then
					command=($(echo "$message" | sed "s/^"$PREFIX"\(.*\)$/\1/"))
					if ! trigger wrapper/global_message_prefix "$player" "${command[@]}" ; then
						output mc say "$ERR_INVALID_MESSAGE_COMMAND" "${command[0]}".
					fi
				else
					trigger minecraft/global_message "$player" "$message"
				fi
			# do not put an else here unless you explicitly want to run a command on every line the server outputs
			fi
			temp_line="$fail_line" # this section is some stuff for grabs that has to be done at the end of the loop
			fail_line="$last_line" # specifically, grabs ignore failed execute commands and only care about the errors
			last_line="$line_data" # as said errors can be generic, be careful about what you feed a grab
			if echo "$last_line" | grep -q "^Failed to execute '.*' as .*$" ; then
				last_line="$fail_line"
				fail_line="$temp_line"
			fi
		fi
	fi
done < "$MC_OUTPUT"
exit
