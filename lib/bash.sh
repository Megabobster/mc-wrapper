#!/bin/bash

. default_config.txt
. config.txt

function mc() {
	echo 'mc' $@
}

function mc_ignore_armorstand() {
	echo 'mc_ignore_armorstand' $@
}

function wrapper() {
	echo 'wrapper' $@
}

function grab() {
	mc scoreboard players set "$player" fail 0
	mc "${@:2}"
	mc scoreboard players set "$1" grab 1
}
