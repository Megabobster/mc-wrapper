#!/bin/sed -f

# Parses NBT/JSON output from Minecraft entity and block data into standard JSON

# Strips irrelevant error message
s/^The data tag did not change: //

# Strips unwanted list numbers
s/\([[,]\)[0-9]\+:/\1/g

# Adds quotes part 1 (key indices and lists)
s/\([[{,]\)\([^]}[{,"][^]},:]*\)\([]},:]\)/\1"\2"\3/g

# Adds quotes part 2 (key values and second pass of lists)
s/\([,:]\)\([^[{"][^]},"]*\)\([]},]\)/\1"\2"\3/g

# Formats numbers, tries to avoid indices
s/\([[,:]\)"\(-\?[0-9]\+\.\?[0-9]*\)[bslfdL]\?"/\1\2/g
