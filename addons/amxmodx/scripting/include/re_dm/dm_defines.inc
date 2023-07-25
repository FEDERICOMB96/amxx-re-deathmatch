#if defined _dm_defines_included_
	#endinput
#endif
#define _dm_defines_included_

#define DM_VERSION_MAJOR                0
#define DM_VERSION_MINOR                0
#define DM_VERSION_PATCH                2

#define PLUGIN_NAME                     "DeathMatch CS"
#define PLUGIN_VERSION                  fmt("v%d.%d.%d", DM_VERSION_MAJOR, DM_VERSION_MINOR, DM_VERSION_PATCH)
#define PLUGIN_AUTHOR                   "FEDERICOMB"
#define PLUGIN_URL                      "https://github.com/FEDERICOMB96/amxx-re-deathmatch"

#define DM_CONFIG_FOLDER                "re_dm"

#define DM_WEAPONS_FILENAME             "weapons.json"

#define LOG_FILENAME                    "error_re_deathmatch.log"

#define MAX_USERS                        MAX_CLIENTS+1

#define BUY_PRIMARY_ITEM                 (1<<0)
#define BUY_SECONDARY_ITEM               (1<<1)