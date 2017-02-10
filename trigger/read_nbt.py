#!/usr/bin/python

import sys

def mc(command): # todo: config
	print "execute @r[type=armor_stand,name=-,tag=-] ~ ~ ~", command

nbtdata = sys.argv[1]

mc("say " + str(nbtdata))
mc("say test")
mc("say " + str(nbtdata))
