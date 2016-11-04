#!/bin/bash
# google minecraft server fifo for other people's projects? not really helpful
# maybe: look up /trigger command, maybe use that to help with triggers and grabs, possibly need to hardcore use that since op might be required?
# todo: ops support/permission levels
# todo: stderr https://google.github.io/styleguide/shell.xml?showone=STDOUT_vs_STDERR#STDOUT_vs_STDERR
# todo: add constants (variables) for where files/fifos are stored and what tmux sessions are named
# maybe: constants in separate config file/"include"
#	https://google.github.io/styleguide/shell.xml?showone=Constants_and_Environment_Variable_Names#Constants_and_Environment_Variable_Names
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
#	then triiiiiiiiig
# todo: write clear for block inventories

# Options:
PREFIX="!"
ARMORSTAND="-"
LEVEL_NAME="$(grep level-name= server.properties | sed 's/level-name=//')"

# Tranlsation:
ERR_GRAB_INPUT_NOT_RECEIVED="Input not received in grab"
ERR_MULTIPLE_GRAB_INPUTS="Too many inputs in grab"
ERR_UNEXPECTED_GRAB_INPUT="Unexpected input in grab"
ERR_INVALID_GRAB="No grab defined with name"
ERR_INVALID_MESSAGE_COMMAND="Invalid command"

WRAPPER_INIT_START="Wrapper initializing."
WRAPPER_INIT_DONE="Wrapper initialized."
WRAPPER_HALT="Wrapper halted."

# function mc runs arbitrary minecraft command
# usage: mc <arbitrary minecraft command>
# like so: mc setblock 1 2 3 air
# or like so: mc execute @r "~ ~ ~" tp @p "~ ~1 ~"
# feel free to get fancy/use variables/insert $(echo $line | sed s///)
# entity selectors are allowed as well!
# just make sure to escape or quote special characters if necessary

function mc() {
	echo "execute @r[type=ArmorStand,name=$ARMORSTAND,tag=$ARMORSTAND] ~ ~ ~ $*" > mc_input # $* necessary to preserve spaces
}

# function mc_ignore_armorstand is identical to mc, however, it executes as the server and
# mc executes as a marker armorstand; this results in less spam to players
# mc is fancier, mc_ignore_armorstand will always work

function mc_ignore_armorstand() {
	echo "$*" > mc_input
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

# tirggers when the grab function is run
# variables available are "$grab", the argument passed to the grab function
trigger_grab() {
	if [ "$grab" = "blend" ] ; then
		player="$grabber"
		if echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: .* has .* that match the criteria$' ; then
			mc scoreboard players set "$player" blend 1
			mc execute "$player" "~ ~ ~" scoreboard players set @e[type=Item,c=1,r=3] blend 2
		elif echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: Could not clear the inventory of .*, no items to remove$' ; then
			mc tellraw "$player" [\"["$ARMORSTAND"] Blending costs 1 book\"]
		elif echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: The data tag did not change: {.*}$' ; then
			set_score_zero="blend"
			if echo "$last" | grep -q '^.*{ench:.*}$' ; then
				#repair_cost="$(echo \"$last\" | sed 's///')"
				mc kill "$item"
				mc clear "$player" minecraft:book -1 1
				mc xp -5L "$player" # todo make this based on RepairCost, maybe also increase RepairCost with blend, and check to make sure the player can afford it
				mc give "$player" minecraft:enchanted_book 1 0 "$(echo "$last" | sed 's/^.*{ench:/{StoredEnchantments:/;s/,Damage:0s.*$//')"
			else # not necessary if there's ever a NBT wildcard for dataTag selectors {Item:{tag:{ench:*}}}
				mc tellraw "$player" [\"["$ARMORSTAND"] Item not enchanted\"]
				mc scoreboard players reset "$item" blend
			fi
		else # make sure to put this else at the end of each grab
			mc say "$ERR_UNEXPECTED_GRAB_INPUT" "$grab".
		fi
#	elif [ "$grab" = "xyz" ] ; then
#		if echo "$last" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: \[-: Teleported Armor Stand to .*, .*, .*\]$' ; then
#			mc say beep
#			kill @e[type=ArmorStand,name=xyz,tag=xyz]
#		else
#			mc say "$ERR_UNEXPECTED_GRAB_INPUT" "$grab".
#		fi
	elif [ "$grab" = "smash" ] ; then
		player="$grabber"
		set_score_zero="smash"
		mc say boop
	else # make sure to leave this here
		mc say "$ERR_INVALID_GRAB" "$grab".
	fi
}

# triggers when a scoreboard value is updated
# variables available are as follows:
# ["$executer": Set score of "$objective" for player "$player" to "$score"]
trigger_scoreboard_value() {
	if [ "$objective" = "blend" -a "$score" = "2" ] ; then
		item="$player" # use this variable with caution
		grab blend entitydata "$item" {}
	elif [ "$objective" = "smash" -a "$score" = "1" ] ; then
		grabber="$player"
		grab smash blockdata -11 4 -9 {} # todo: implement multiple smashers in a world
	elif [ "$objective" = "onGround" -a "$score" = "1" ] ; then
		mc effect "$player" minecraft:levitation 1 1 true
	fi
}

# triggers when a message starting with $PREFIX is said in global chat
# passes $message as arguments so prefix commands can have arbitrary arguments
# variables available are as follows:
# <"$player"> $PREFIX"$message"
trigger_global_message_prefix() {
	if [ "$player" = "Megabobster" -a "$1" = "halt" ] ; then
		running="0"
	elif [ "$1" = "blend" ] ; then
		grabber="$player"
		grab blend clear @a[name="$player",score_blend=0] minecraft:book -1 0
	elif [ "$1" = "bork" ] ; then
		if [ "$2" = "1" ] ; then
			grab bork tp @a[score_bork=0] "~ ~ ~"		# ERR_GRAB_INPUT_NOT_RECEIVED
		elif [ "$2" = "2" ] ; then
			grab bork execute @a "~ ~ ~" entitydata @e {}	# ERR_MULTIPLE_GRAB_INPUTS
		elif [ "$2" = "3" ] ; then
			grab blend say bork				# ERR_UNEXPECTED_GRAB_INPUT
		elif [ "$2" = "4" ] ; then
			grab bork tell "$player" bork			# ERR_INVALID_GRAB
		else
			mc tellraw "$player" [\"["$ARMORSTAND"] Usage: !bork <1-4>\"]
		fi
	elif [ "$1" = "k" ] ; then
		if [ "$2" -le "16" ] ; then
			for i in $(seq 1 "$2") ; do
				mc say k
			done
		else
			mc say no
		fi
	elif [ "$1" = "run" ] ; then
		if [ "$2" -le "16" ] ; then
                        for i in $(seq 1 "$2") ; do
                                mc execute "$player" "~ ~ ~" "${@:3}"
                        done
                else
                        mc say Run cannot exceed 16 loops.
                fi
	elif [ "$1" = "level-name" ] ; then
		mc say "$LEVEL_NAME"
#	elif [ "$1" = "xyz" ] ; then # todo: trigger like grab, not grab...
#		mc execute "$player" "~ ~ ~" summon ArmorStand "~ ~ ~" "{CustomName:\"xyz\",Invulnerable:true,Marker:true,Invisible:true,NoGravity:true,Tags:[0:\"xyz\"]}"
#		grab xyz tp @e[name=xyz,tag=xyz,c=1] "~ ~ ~"
	else
		mc say "$ERR_INVALID_MESSAGE_COMMAND" "$1".
	fi
}

# triggers when a message is said in global chat
# variables available are as follows:
# <"$player"> "$message"
trigger_global_message() {
	if [ "$message" = "xyzzy" ] ; then
		mc tp "$player" 0 4 0
	elif [ "$message" = "foo" ] ; then
		for i in $(seq 1 16) ; do
			mc execute "$player" "~ ~ ~" summon Pig
			mc give "$player" dirt
		done
	elif echo "$message" | grep -q -e 'https\?://.* ' -e 'https\?://.*$' ; then
		url="$(echo "$message" | sed 's|^.*https?://|https?://|;s| .*$||')"
		mc tellraw @a [\"[-] [\",\{\"text\":\"link\",\"underlined\":true,\"clickEvent\":\{\"action\":\"open_url\",\"value\":\""$url"\"\}\},\"]\"]
	fi
}

# triggers when the /say command is run
# variables available are as follows:
# ["$player"] "$message"
trigger_say_command() {
#	if [ "$player" = "Server" -a "$message" = "Server backing up." ] ; then # todo: make this a separate function that other things can call, add backup "Saved the world" trigger to main loop
	if [ "$message" = "Server backing up." ] ; then
		mc_ignore_armorstand say This will disable all wrapper-enhanced functionality until the backup is complete.
		mc save-off
		mc save-all flush
	fi
}

# triggers on failed execute commands
# variables available are as follows:
# Failed to execute '"$command"' as "$player"
trigger_execute_failure() {
	if [ "$command" = "scoreboard players set @e[type=Item,c=1,r=3] blend 2" ] ; then
		set_score_zero="blend"
		mc tellraw "$executer" [\"["$ARMORSTAND"] Put your item on the ground!\"]
	fi
}

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
#	elif echo "$line" | grep -e '^\[..:..:..\] \[Server thread/INFO\]: Done (.*)! For help, type "help" or "?"$' -e "^\[..:..:..\] \[Server thread/INFO\]: \[Server\] $WRAPPER_INIT_START$"; then
	elif echo "$line" | grep "^\[..:..:..\] \[Server thread/INFO\]: \[Server\] $WRAPPER_INIT_START$" ; then
		mc_ignore_armorstand kill @e[type=ArmorStand,name="$ARMORSTAND",tag="$ARMORSTAND"]
		mc_ignore_armorstand summon ArmorStand 0 0 0 "{CustomName:\"$ARMORSTAND\",Invulnerable:true,Marker:true,Invisible:true,NoGravity:true,Tags:[0:\"$ARMORSTAND\"]}"
		# todo: constant for worldspawn
		# mc_ignore_armorstand isn't necessary after this point, it just creates less errors if commands fail (like if the scoreboard already exists)
		mc_ignore_armorstand scoreboard objectives add grab dummy
# <put commands to be run once on script init here; use this with caution>
		mc_ignore_armorstand scoreboard objectives add blend dummy
		mc_ignore_armorstand scoreboard objectives add smash dummy
# </end commands to be run once>
		running="0"
	fi
done < mc_output
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
				trigger_grab
			fi
		else
			trigger_scoreboard_value
		fi
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: <.*> $PREFIX.*$" ; then
		player="$(echo "$line" | sed 's/^.*<//;s/>.*$//')"
		message="$(echo "$line" | sed "s/^[^>]*> $PREFIX//")"
		trigger_global_message_prefix $message
	elif echo "$line" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: <.*> .*$' ; then
		player="$(echo "$line" | sed 's/^.*<//;s/>.*$//')"
		message="$(echo "$line" | sed 's/^[^>]*> //')"
		trigger_global_message
	elif echo "$line" | grep -q '^\[..:..:..\] \[Server thread/INFO\]: \[.*\] .*$' ; then
		trim="$(echo "$line" | sed 's/^\[..:..:..\] \[Server thread\/INFO\]: \[//')" # todo: make this regex not suck
		player="$(echo "$trim" | sed 's/\].*//')"
		message="$(echo "$trim" | sed 's/.*[^\]]*] //')"
		trigger_say_command
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: Failed to execute '.*' as .*$" ; then
		command="$(echo "$line" | sed "s/^[^']*'//;s/' as .*$//")"
		executer="$(echo "$line" | sed "s/^.*' as //")"
		trigger_execute_failure
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: \[$ARMORSTAND: Saved the world\]$" ; then # todo: change $ARMORSTAND to $player, make this another trigger
		zip -r backups/"$LEVEL_NAME"\_"$(date +%Y-%m-%d.%H.%M.%S)".zip "$LEVEL_NAME"
		cd backups/ # todo: constant for backups directory, possibly create it if it doesn't exist (or just error)
		ls -td "$LEVEL_NAME"* | sed -e '1,7d' | xargs -d '\n' rm
		cd ..
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
done < mc_output
# shutdown commands could theoretically be put here but be very careful as they
# won't be run if the wrapper does not exit cleanly, which could potentially
# bork your world if there is anything that depends on the shutdown commands
mc say "$WRAPPER_HALT"
running="1"
while [ "$running" = "1" ] ; do
	read line
	echo "$line"
	if echo "$line" | grep -q "\[..:..:..\] \[Server thread/INFO\]: \[$ARMORSTAND\] $WRAPPER_HALT" ; then
		running="0"
	elif echo "$line" | grep -q "^\[..:..:..\] \[Server thread/INFO\]: Saving worlds$" ; then
		rm mc_input
		rm mc_output
		running="0"
	fi
done < mc_output
exit
