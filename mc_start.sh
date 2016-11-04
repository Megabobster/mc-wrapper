#!/bin/bash
mkfifo mc_input
mkfifo mc_output
tail --follow=name mc_input | minecraft_server > mc_output
exit
