# KissMP-Soccar
A car soccer game-mode for KISS Multiplayer servers

### How to use
- Put the "soccar" folder in your servers "addon" directory
- Run the server
    - Ensure the vehicle limit on the server is at least 2
    - A configuration file will be generated for the game mode
    - Here you can set the limit type to "Goals", "Time", or "None"
    - You can also customize the time/goals limit
    - You can reload this config file while the server is running by typing "reload" in the server console
- Have the host (or otherwise *one* player only) spawn a soccer ball prop
    - After doing this, 'TAB' over to the ball and type in chat "/ball" or "/setball"
- All players will then set their teams by typing "/team red" or "/team blue"
- After teams are set, the game will start
