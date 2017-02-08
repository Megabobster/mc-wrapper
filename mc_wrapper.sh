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
#	@e[type=ArmorStand,name="$PLAYER",tag="$ARMORSTAND"] maybe?
#	do as much of this as possible in game to make it faster
#	then triiiiiiiiig
# todo: write clear for block inventories

# function mc runs arbitrary minecraft command
# usage: mc <arbitrary minecraft command>
# like so: mc setblock 1 2 3 air
# or like so: mc execute @r "~ ~ ~" tp @p "~ ~1 ~"
# feel free to get fancy/use variables/insert $(echo $line | sed s///)
# entity selectors are allowed as well!
# just make sure to escape or quote special characters if necessary

function mc() {
	echo "execute @r[type=ArmorStand,name=$ARMORSTAND,tag=$ARMORSTAND] ~ ~ ~ $*" > "$MC_INPUT" # $* necessary to preserve spaces
}

# function mc_ignore_armorstand is identical to mc, however, it executes as the server and
# mc executes as a marker armorstand; this results in less spam to players
# mc is fancier, mc_ignore_armorstand will always work

function mc_ignore_armorstand() {
	echo "$*" > "$MC_INPUT"
}

# function grab runs arbitrary minecraft command and gets arbitrary output
# usage: grab <$grab> <arbitrary minecraft command>
# and it also makes sure it isn't interrupted so you get *only* the output you want
# like so: grab piggy entitydata @r[type=Pig] {}
# then define them in the grab section:
#	elif [ "$grab" = "piggy" ] ; then
#		if echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: The data tag did not change: {.*}$' ; then
#			(do stuff with the pig's NBT data here; feel free to
#			get fancy with regex/sed/variables/that kind of stuff)
#		else # make sure to put this else at the end of each grab
#			mc say "$ERR_INVALID_GRAB" "$grab".
#		fi
# DO NOT FORGET TO DEFINE YOUR GRABS
# it won't break anything (yet) but it makes me sad
# also it doesn't currently work for commands that result in more than one line of output
# for example it throws $ERR_MULTIPLE_GRAB_INPUTS on a failed execute command

function grab() {
	mc scoreboard players set fail grab 0
	mc "${@:2}"
	mc scoreboard players set "$1" grab 1
}

# while you're here
# $set_score_zero sets $player's $objective score to 0 at the end of the server tick
# usage: $set_score_zero=<objective>
# use this to prevent $player spamming things and breaking them

# Not Options?:
DEFAULTS="default_config.txt"
CONFIG="config.txt"
WRAPPER_DIR="$PWD" # todo: figure this the hell out, I think this script must be run from PWD to function

# Load Config:
if ! [ -e "$DEFAULTS" ] ; then
	echo "Default configuration ($DEFAULTS) not present or renamed, exiting..."
	exit # maybe: put default settings here instead of in a separate file, then generate config.txt
fi
. "$DEFAULTS"
if ! [ -e "$CONFIG" ] ; then
	echo "$ERR_NEW_CONFIG"
	cp "$DEFAULTS" "$CONFIG" # todo: make this fancier?
fi
. "$CONFIG"

# Not Option?:
LEVEL_NAME="$(grep level-name= $MINECRAFT_DIR/server.properties | sed 's/level-name=//')"

# Script Initialization:
if ! [ -e "$SCRIPT_NAME" ] ; then
	echo "$ERR_SCRIPT_MISSING"
	exit
elif ! [ -d "$TRIGGER" ] ; then
	echo "$ERR_TRIGGER_MISSING"
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
	tail --follow=name "$MC_INPUT" | . mc_start.sh > "$MC_OUTPUT" & # todo: maybe use cat instead of tail, also make this not output stuff on tail's end
	echo "SERVER_PID=$!" > "$SERVER_PIDFILE"
fi
echo "WRAPPER_PID=$$" > "$WRAPPER_PIDFILE"

# Start Wrapper:
mc_ignore_armorstand say "$WRAPPER_INIT_START"
running="1"
while [ "$running" = "1" ] ; do
	read line
	if echo "$line" | grep '^\[..:..:..\] \[Server thread/INFO\]: Starting minecraft server version .*$' ; then
		running="2"
		while [ "$running" = "2" ] ; do
			read line
			echo "$line"
			if echo "$line" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: Done (.*)! For help, type "help" or "?"$' ; then # todo: make sure this is indeed outputting everything
				running="1"
			fi
		done
	elif echo "$line" | grep "^\[..:..:..\] \[Server thread/INFO\]: \[Server\] $WRAPPER_INIT_START$" ; then
		mc_ignore_armorstand kill @e[type=ArmorStand,name="$ARMORSTAND",tag="$ARMORSTAND"]
		mc_ignore_armorstand summon ArmorStand 0 0 0 "{CustomName:\"$ARMORSTAND\",Invulnerable:true,Marker:true,Invisible:true,NoGravity:true,Tags:[0:\"$ARMORSTAND\"]}"
# todo: constant for worldspawn instead of 0 0 0
# mc_ignore_armorstand isn't necessary after this point, it just creates less errors if commands fail (like if the scoreboard already exists)
		mc_ignore_armorstand scoreboard objectives add grab dummy
# <put commands to be run once on script init here; use this with caution>
		mc_ignore_armorstand scoreboard objectives add blend dummy
		mc_ignore_armorstand scoreboard objectives add smash dummy
# </end commands to be run once>
		running="0"
	fi
done < "$MC_OUTPUT"
mc say "$WRAPPER_INIT_DONE"

running="1"
# main loop starts here
while [ "$running" = "1" ] ; do
# <the magic>
	read line
	echo "$line"
	if echo "$line" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: \[.*: Set score of .* for player .* to .*]$' ; then
		executer="$(echo "$line" | sed 's/^.*\]: \[//;s/: Set.*$//')"
		objective="$(echo "$line" | sed 's/^.*score of //;s/ for player.*$//')"
		player="$(echo "$line" | sed 's/^.*for player //;s/ to .*$//')"
		score="$(echo "$line" | sed 's/^.* to //;s/\]$//')"
		if [ "$executer" = "$ARMORSTAND" -a "$objective" = "grab" -a "$score" = "1" ] ; then
			grab="$player"
			if echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: Set score of grab for player fail to 0$' ; then
				mc say "$ERR_GRAB_INPUT_NOT_RECEIVED" "$grab".
			elif ! echo "$fail" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: Set score of grab for player fail to 0$' ; then
				mc say "$ERR_MULTIPLE_GRAB_INPUTS" "$grab".
			else
				. "$TRIGGER/grab"
			fi
		else
			. "$TRIGGER/scoreboard_value"
		fi
	elif echo "$line" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: <.*> .*$' ; then
		player="$(echo "$line" | sed 's/^.*<//;s/>.*$//')"
		message="$(echo "$line" | sed 's/^[^>]*> //')"
		if echo "$message" | grep -q "^$PREFIX.*$" ; then
			message="$(echo "$line" | sed "s/^[^>]*> $PREFIX//")" # todo: make this based on $message instead of $line, also maybe use $command or something
#			message="$(echo "$message" | sed "s/^[^"$PREFIX"]*"$PREFIX"//")" # variable expansion and quoting...brace quotes might fix this https://google.github.io/styleguide/shell.xml?showone=Variable_expansion#Variable_expansion
			. "$TRIGGER/global_message_prefix" $message
		else
			. "$TRIGGER/global_message"
		fi
	elif echo "$line" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: \[.*\] .*$' ; then
		trim="$(echo "$line" | sed 's/^\[..:..:..\] \[Server thread\/INFO\]: \[//')" # todo: make this regex not suck
		player="$(echo "$trim" | sed 's/\].*//')"
		message="$(echo "$trim" | sed 's/.*[^\]]*] //')"
		. "$TRIGGER/say_command"
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: Failed to execute '.*' as .*$" ; then
		command="$(echo "$line" | sed "s/^[^']*'//;s/' as .*$//")"
		executer="$(echo "$line" | sed "s/^.*' as //")"
		. "$TRIGGER/execute_failure"
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: \[$ARMORSTAND: Saved the world\]$" ; then # todo: change $ARMORSTAND to $player, make this another trigger
		zip -r "$BACKUP_DIR"/"$LEVEL_NAME"\_"$(date +%Y-%m-%d.%H.%M.%S)".zip "$MINECRAFT_DIR"/"$LEVEL_NAME"
		cd "$BACKUP_DIR" # maybe: create directory or error if it doesn't exist
		ls -td "$LEVEL_NAME"* | sed -e '1,7d' | xargs -d '\n' rm
		cd "$WRAPPER_DIR"
		mc save-on
		mc_ignore_armorstand say Server backup complete.
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: Stopping server$" ; then
		running="0"
	# do not put an else here unless you explicitly want to run a command on every line the server outputs
	fi
# </the magic>
	temp="$fail" # this section is some stuff for grabs that has to be done at the end of the loop
	fail="$last" # specifically, grabs ignore failed execute commands and only care about the errors
	last="$line" # as said errors can be generic, be careful about what you feed a grab
	if echo "$last" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: Failed to execute '.*' as .*$" ; then
		last="$fail"
		fail="$temp"
	fi
	if [ -n "$set_score_zero" ] ; then
		mc scoreboard players set "$player" "$set_score_zero" 0
		set_score_zero=
	fi
done < "$MC_OUTPUT"
# shutdown commands could theoretically be put here but be very careful as they
# won't be run if the wrapper does not exit cleanly, which could potentially
# bork your world if there is anything that depends on the shutdown commands
mc say "$WRAPPER_HALT"
mc kill @e[type=ArmorStand,name="$ARMORSTAND",tag="$ARMORSTAND"]
running="1"
while [ "$running" = "1" ] ; do
	read line
	echo "$line"
	if echo "$line" | grep -q -e "\[..:..:..\] \[Server thread/INFO\]: \[$ARMORSTAND\] $WRAPPER_HALT" -e "^\[..:..:..\] \[Server thread/INFO\]: Saving worlds$" ; then
		running="0"
		rm "$WRAPPER_PIDFILE"
	fi
done < "$MC_OUTPUT"
exit
