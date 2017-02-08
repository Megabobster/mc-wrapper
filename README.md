# Hey look, it's a server wrapper!

It's written, so far, entirely in bash script. It's not quite done.

Start it by running mc_wrapper.sh. Edit settings in config.txt, which is generated after running once.

# How does it work?

mc_wrapper captures the stdin and stdout of the Minecraft server, which lets us to some fun stuff. Reading stdout from the server, we can use regular expressions to extract useful information on what's going on inside the server. Using stdin, we can send it commands based on the information gathered previously.

Using said information, I've set up a series of trigger conditions. Putting conditional statements in the appropriate script in the trigger folder will allow you to easily perform much more complex logic than vanilla Minecraft commands would allow.
