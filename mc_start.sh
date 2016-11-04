#!/bin/bash
mkfifo mc_input
mkfifo mc_output
tail --follow=name mc_input | ~/programs/jre1.8.0_73/bin/java -Xmx1024M -Xms1024M -jar minecraft_server.jar nogui > mc_output
exit
