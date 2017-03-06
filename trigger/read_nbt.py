#!/usr/bin/python

import sys
nbtdata = sys.argv[1]

# triggers when entitydata <entity> {} is run, which spits out the entity's full NBT data
# variables are as follows
# The data tag did not change: "$nbtdata"

print "say " + str(nbtdata)
print "say test"
print "say " + str(nbtdata)
