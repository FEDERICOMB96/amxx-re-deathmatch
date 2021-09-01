[![AMX MOD X](https://badgen.net/badge/Powered%20by/AMXMODX/0e83cd)](https://amxmodx.org)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

# AMXX Re DeathMatch CS 1.6
El clásico modo DeathMatch para Counter Strike 1.6 utilizando todas las nuevas características que provee ReGameDLL y ReAPI, lo que ha logrado simplificar mucho el plugin. Este plugin lo cree en 2016 donde lo usé por primera vez en el servidor DeathMatch de [Xtreme Addictions](https://xa-cs.com.ar), desde entonces vengo mejorándolo. Dejo libre el código que actualmente (2021) se está utilizando y que aún sigo mejorando para quién quiera sea libre de usarlo. Todos los errores a corregir o sugerencias son bienvenidas.
Este plugin fue pensado como una mejora del antiguo [CSDM](https://forums.alliedmods.net/showthread.php?t=79583) desarrollado por [Bailopan](https://github.com/dvander).

## Requerimientos
- [AmxModX](https://github.com/alliedmodders/amxmodx) >= 1.9.0.5263
- [ReHLDS](https://github.com/dreamstalker/rehlds) >= 3.9.0.752-dev
- [ReGameDLL](https://github.com/s1lentq/ReGameDLL_CS) >= 5.20.0.525
- [ReAPI](https://github.com/s1lentq/reapi) >= 5.19.0.217

## Características
En el archivo [dm_game.cfg](https://github.com/FEDERICOMB96/amxx-re-deathmatch/blob/main/dm_game.cfg) se encuentran las configuraciones por defecto "optimas" para un buen DeathMatch + He. El archivo debe ir ubicado en la raíz del servidor, dentro de la carpeta cstrike. Se puede jugar en modo FFA (Todos contra todos) estableciendo la CVAR `mp_freeforall 1`

## Cvars propias del plugin
| Cvar                                | Defecto | Mín | Máx          | Descripción                                    |
| :---------------------------------- | :-----: | :-: | :----------: | :--------------------------------------------- |
| csdm_only_head                      | 0       | 0   | 1            | Jugar en modo "only head"                      |
| csdm_drop_medic                     | 0       | 0   | 1            | Dropea un kit médico al matar un enemigo que al recogerlo otorga 15 de vida extra |