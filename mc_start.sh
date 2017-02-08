#!/bin/bash
# This is the script that runs the Minecraft server itself, then cleans up after the wrapper once the server exits.
# Don't directly run this. Just run mc_wrapper.sh and it will start this.
cd "$MINECRAFT_DIR"
$JAVA_PATH $LAUNCH_ARGS -jar "$SERVER_JAR" nogui # does leaving off nogui allow gui admin while fifo does its thing?
rm "$WRAPPER_DIR"/"$SERVER_PIDFILE"
rm "$WRAPPER_DIR"/"$MC_INPUT"
rm "$WRAPPER_DIR"/"$MC_OUTPUT"
exit
