[![AMX MOD X](https://badgen.net/badge/Powered%20by/AMXMODX/0e83cd)](https://amxmodx.org)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# [AMXX] Re DeathMatch CS [v0.0.1]
Original plugin [CSDM](https://forums.alliedmods.net/showthread.php?t=79583) developed by [Bailopan](https://github.com/dvander).

## Requirements:
- [AmxModX](https://github.com/alliedmodders/amxmodx) >= 1.10.0.5461
- [ReHLDS](https://github.com/dreamstalker/rehlds) >= 3.12.0.780
- [ReGameDLL](https://github.com/s1lentq/ReGameDLL_CS) >= 5.22.0.593
- [ReAPI](https://github.com/s1lentq/reapi) >= 5.22.0.254

## Cvars
| Cvar                                | Default | Min | Max          | Description                                                                 |
| :---------------------------------- | :-----: | :-: | :----------: | :-------------------------------------------------------------------------- |
| csdm_allow_random_spawns            | 1       | 0   | 1            | Allow random spawns.                                                        | 
| csdm_only_head                      | 0       | 0   | 1            | Play mode "only head".                                                      |
| csdm_drop_medic                     | 0       | 0   | 1            | Drops a med kit by killing an enemy which grants extra life when picked up. |
| csdm_medic_health				      | 50      | 1   | 100          | Health of the med kit (Use in conjunction with the cvar 'csdm_drop_medic'). |
| csdm_refill_armor_on_kill           | 1       | 0   | 1            | Instantly refill player armor on kill.                                      |
| csdm_kill_ding_sound                | 1       | 0   | 1            | Play a ding sound on kill.                                                  |
| csdm_screenfade_on_kill             | 1       | 0   | 1            | Screenfade effect on kill.                                                  |
| csdm_instant_reload_weapons_on_kill | 1       | 0   | 1            | Instantly reload player weapons on kill.                                    |
| csdm_block_kill_command             | 1       | 0   | 1            | Block kill console command.                                                 |
| csdm_block_spawn_sounds             | 1       | 0   | 1            | Block spawn sounds.                                                         |
| csdm_block_drop                     | 0       | 0   | 1            | Block drop of weapons.                                                      |

## Say / Say_Team commands
| Command                             | Description                                    |
| :---------------------------------- | :--------------------------------------------- |
| guns / armas                        | Opens the weapon selection menu.               |
