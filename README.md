# Safeguard
Custom gamemode based on one from COD:BO3/BO4 with same name. In this round based gamemode, teams alternate in escorting a non-combative Nuke Titan to the enemy Harvester.

## Gamemode overview
The offensive team has to escort a non-combative Nuke Titan along a predetermined path to the Harvester, which is typically near the defensive team's spawn point. The defensive team must prevent the Nuke Titan from getting near Harvester.

Nuke Titan can be damaged with explosive and anti-Titan weapons. After getting into Doomed state, it will be temporary disabled and the offensive team must wait until the Nuke Titan self-repairs automatically or repair it with Titan Battery - they can be found on some maps. Shielding Nuke Titan makes it move even without near allies.

If teams are tied after 2 rounds, game goes to overtime - team with best escort time in previous rounds will play as defensive team, while offensive team should beat this time.

## Gamemode settings
```
"safeguard_titan_maxshield" (Default value: 2500) - Max Nuke Titan Shield Amount.
"safeguard_titan_autorepair_time" ( Default value: 15.0 ) - Nuke Titan auto-repair time.
"safeguard_battery_spawners" ( Default value: 1 ) - Enable Battery spawners.
"safeguard_battery_spawn_delay" ( Default value: 60.0 ) - First Battery spawn delay.
"safeguard_battery_respawn_delay" ( Default value: 30.0 ) - Battery respawn delay.
"safeguard_stopwatch" ( Default value: 0 ) - Stopwatch rules: No overtime rounds, offensive team in second round should beat escort time of previous round.
```

## Known issues
Current version of Northstar (1.30) has problems in round based gamemodes with score calculation and player animations in dropship intro only play in first round and after switching sides. As temporary solution, hosts can use `gamemode_fd_experimental` [**branch of Zanieon's NorthstarMods repository**](https://github.com/Zanieon/NorthstarMods/tree/gamemode_fd_experimental) or [**my small server-side mod**](https://github.com/Gazyi/NorthstarCustom.CustomServers) that have fixes for that ( a bunch of vanilla NorthstarCustomServers scripts modified with Zanieon's code ).

*Credits to [**Zanieon**](https://github.com/Zanieon) for [**PayloadGamemode**](https://github.com/PayloadGamemode) and other code snippets from `NorthstarMods` repository.*