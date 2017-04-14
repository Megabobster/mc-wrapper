# Hey look, it's a server wrapper!

It's written, so far, almost entirely in bash script (and a bit of Python). It's not quite done.

Start it by running mc_wrapper.sh. Edit settings in config.txt, which is generated after running the wrapper once. Alternatively, copy default_config.txt.

You can also run cli_admin.sh and type `help` or `start`. Any commands not handled directly by that script (listed in the `help` command) will be passed directly to the Minecraft server.

# How does it work?

mc_wrapper captures the stdin and stdout of the Minecraft server, which lets us do some fun stuff. Reading stdout from the server, we can use regular expressions to extract useful information on what's going on inside the server. Using stdin, we can send it commands.

With those abilities, I've set up a series of trigger conditions. Writing a plugin using these can allow you to easily perform much more complex logic than vanilla Minecraft commands would allow.

Please annoy me to write good documentation on how these work :)

# License

Feel free to use this program, write software to be used by it, and modify it to fit your needs, as long as your needs aren't commercial or nefarious (in plainer English: contact me if your use case isn't personal). If you make modifications and want to share them, make the source publicly available.
