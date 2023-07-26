#if defined _dm_global_included_
	#endinput
#endif
#define _dm_global_included_

#define DM_VERSION_MAJOR                0
#define DM_VERSION_MINOR                0
#define DM_VERSION_PATCH                5

#define PLUGIN_NAME                     "DeathMatch CS"
#define PLUGIN_VERSION                  fmt("v%d.%d.%d", DM_VERSION_MAJOR, DM_VERSION_MINOR, DM_VERSION_PATCH)
#define PLUGIN_AUTHOR                   "FEDERICOMB"
#define PLUGIN_URL                      "https://github.com/FEDERICOMB96/amxx-re-deathmatch"

#define DM_CONFIG_FOLDER                "re_dm"

#define DM_WEAPONS_FILENAME             "weapons.json"

#define LOG_FILENAME                    "error_re_deathmatch.log"

#define MAX_USERS                        MAX_CLIENTS+1

#define IsPlayer(%0)                    (1 <= %0 <= MAX_CLIENTS)

#define GetPlayerBit(%0,%1)             (IsPlayer(%1) && (%0 & (1 << (%1 & 31))))
#define SetPlayerBit(%0,%1)             (IsPlayer(%1) && (%0 |= (1 << (%1 & 31))))
#define ClearPlayerBit(%0,%1)           (IsPlayer(%1) && (%0 &= ~(1 << (%1 & 31))))
#define SwitchPlayerBit(%0,%1)          (IsPlayer(%1) && (%0 ^= (1 << (%1 & 31))))

#define IsConnected(%0)                 GetPlayerBit(g_bConnected, %0)
#define IsAlive(%0)                     GetPlayerBit(g_bAlive, %0)

new const OBJECTIVES_ENTITIES[][] =
{
	"func_bomb_target", "info_bomb_target",	"info_vip_start", "func_vip_safetyzone", "func_escapezone",
	"hostage_entity", "monster_scientist", "func_hostage_rescue", "info_hostage_rescue", "env_fog",
	"env_rain", "env_snow", "item_longjump", "func_vehicle", "game_player_equip",
	"info_map_parameters", "func_buyzone", "armoury_entity", "game_text"
};

new const TXTMSG_BLOCK[][] =
{
	"#Game_teammate_attack", "#Game_Commencing", "#Game_will_restart_in", 
	"#Hostages_Not_Rescued", "#Round_Draw", "#Terrorists_Win", "#CTs_Win"
};

new const SENDAUDIO_BLOCK[][] =
{
	"%!MRAD_ctwin", "%!MRAD_terwin", "%!MRAD_rounddraw", "%!MRAD_FIREINHOLE",
	"%!MRAD_BOMBPL", "%!MRAD_BOMBDEF", "%!MRAD_rescued"
};

/* ===========================================================================
*                 [ GLOBAL STUFF ]
* ============================================================================ */

new const g_szGlobalPrefix[]            = "^4[DEATHMATCH]^1";

new const g_szMedKitClass[]             = "MedKit";
new const g_szModel_MedicKit[]          = "models/w_medkit.mdl";
new const g_szSound_MedicKit[]          = "items/smallmedkit1.wav";

new const g_szSound_KillDing[]          = "buttons/bell1.wav";

new g_bConnected;
new g_bAlive;

new g_iSyncHudDamage;
new g_iMsgScreenFade;

new g_Forward_Spawn;

/* ===========================================================================
*                 [ CVARS ]
* ============================================================================ */

new g_iCSDM_AllowRandomSpawns;
new g_iCSDM_OnlyHead;
new g_iCSDM_MedicKit;
new g_iCSDM_RefillArmorOnKill;
new g_iCSDM_KillDingSound;
new g_iCSDM_ScreenFadeOnKill;
new g_iCSDM_InstantReloadWeaponsOnKill;
new g_iCSDM_BlockKillCommand;
new g_iCSDM_BlockSpawnSounds;
new g_iCSDM_BlockDrop;
new g_iCSDM_FreeForAll;
new Float:g_flCSDM_ItemStaytime;

/* ===========================================================================
*                 [ WEAPONS ]
* ============================================================================ */

#define BUY_PRIMARY_ITEM                 (1<<0)
#define BUY_SECONDARY_ITEM               (1<<1)

const PRIMARY_WEAPONS_BIT_SUM            = (1<<CSW_SCOUT) | (1<<CSW_XM1014) | (1<<CSW_MAC10) | (1<<CSW_AUG) | (1<<CSW_UMP45) | (1<<CSW_SG550) | (1<<CSW_GALIL) | (1<<CSW_FAMAS) | (1<<CSW_AWP) | (1<<CSW_MP5NAVY) | (1<<CSW_M249) | (1<<CSW_M3) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_G3SG1) | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_P90);
const SECONDARY_WEAPONS_BIT_SUM          = (1<<CSW_P228) | (1<<CSW_ELITE) | (1<<CSW_FIVESEVEN) | (1<<CSW_USP) | (1<<CSW_GLOCK18) | (1<<CSW_DEAGLE);

enum _:WeaponStruct_e
{
	WeaponIdType:WeaponId,
	WeaponEnt[32],
	WeaponName[32],
};

enum _:WeaponData_e
{
	WeaponDataM4A1 = 0,
	WeaponDataFAMAS,
	WeaponDataUSP,
	WeaponDataGLOCK
};

new Array:g_aPrimaryWeapons;
new Array:g_aSecondaryWeapons;

new g_iPrimaryWeapons[MAX_USERS];
new g_iSecondaryWeapons[MAX_USERS];
new g_iDontShowTheMenuAgain[MAX_USERS];
new g_iBuyItem[MAX_USERS];

new g_iWeaponData[MAX_USERS][WeaponData_e];

/* ===========================================================================
*                 [ SPAWNS ]
* ============================================================================ */

enum _:ArraySpawns_e
{
	TeamName:SpawnTeam,
	Float:SpawnOrigin[3],
	Float:SpawnAngles[3],
};

new Array:g_aSpawns;