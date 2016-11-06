#!/bin/bash
cd "$MINECRAFT_DIR"
$JAVA_PATH $LAUNCH_ARGS -jar "$SERVER_JAR" nogui # does leaving off nogui allow gui admin while fifo does its thing?
rm "$WRAPPER_DIR"/dummy
rm "$WRAPPER_DIR"/"$MC_INPUT"
rm "$WRAPPER_DIR"/"$MC_OUTPUT"
exit
