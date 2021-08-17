#include <amxmodx>
#include <reapi>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#pragma semicolon 1

new const g_sPluginName[] = "DEATHMATCH";
new const g_sPluginVersion[] = "v2021.08.16";
new const g_sPluginAuthor[] = "AMXX-ES Dev Team";

new const g_sGlobalPrefix[] = "^4[DEATHMATCH]^1 ";

const MAX_USERS = 33;
const MAX_CSDM_SPAWNS = 120;

/// Player Vars
new g_bConnected;
new g_bAlive;

new g_iPlayerModel[MAX_USERS];
new g_iMenuInfo[MAX_USERS];
new g_iPrimaryWeapons[MAX_USERS];
new g_iPrimaryWeaponsEnt[MAX_USERS];
new g_iSecondaryWeapons[MAX_USERS];
new g_iSecondaryWeaponsEnt[MAX_USERS];
new g_iDontShowTheMenuAgain[MAX_USERS];
new WeaponIdType:g_iCurrentWeapon[MAX_USERS];
new g_iFixChooseWeapon[MAX_USERS];
new g_iSysTimePlayer[MAX_USERS];

enum _:structWeaponData {
	weaponM4A1 = 0,
	weaponFAMAS,
	weaponUSP,
	weaponGLOCK
};
new g_iWeaponData[MAX_USERS][structWeaponData];

/// Global Vars
new g_iMaxUsers = 0;
new g_iSetNextModel = 0;
new g_iSpawnCount = 0;
// new g_iSyncHudSpawn = 0;
new g_iSyncHudDamage = 0;
new g_iAllowRandomSpawns = 1;
new g_iGlobalMenuOne;
new g_iGlobalMenuTwo;

new g_sCurrentMap[32];

new Float:g_fTeams_Time;

// SPAWNS
new TeamName:g_iSpawnsTeam[MAX_CSDM_SPAWNS];

new Float:g_fSpawns[MAX_CSDM_SPAWNS][3];
new Float:g_fSpawnsAngles[MAX_CSDM_SPAWNS][3];

// Cvars
new g_pCvar__CSDM_OnlyHead = 0;
new g_pCvar__CSDM_FreeForAll = 0;
new g_pCvar__CSDM_Grenades = 0;
new g_pCvar__CSDM_MedicKit = 0;

new g_pCvar__CSDM_TimeRespawn = 0;

new g_iCSDM_OnlyHead = 0;
new TeamName:g_iCSDM_FreeForAll = TEAM_UNASSIGNED;

new g_sCSDM_Grenades[3];
new g_bCSDM_Grenades = 0;

new g_iCSDM_MedicKit = 0;

/// Forward Vars
new g_Forward_Spawn = 0;
new g_Forward_PrecacheSound = 0;

/// Message Vars
new g_Message_TeamInfo = 0;

new HamHook:g_iHhCBasePlayerPreThink;

enum _:e_StructWeapons
{
	WeaponIdType:weaponId,
	weaponEnt[54],
	weaponNames[32],
	bool:weaponSilenced
};

new const PRIMARY_WEAPONS[][e_StructWeapons] =
{
	{WEAPON_M4A1, 		"weapon_m4a1", 		"M4A1", 				true},
	{WEAPON_AK47, 		"weapon_ak47", 		"AK-47", 				false},
	{WEAPON_AUG, 		"weapon_aug", 		"AUG", 					false},
	{WEAPON_SG552, 		"weapon_sg552", 	"SG-552", 				false},
	{WEAPON_GALIL, 		"weapon_galil", 	"Galil", 				false},
	{WEAPON_FAMAS, 		"weapon_famas", 	"Famas", 				true},
	{WEAPON_SCOUT, 		"weapon_scout", 	"Scout", 				false},
	{WEAPON_AWP, 		"weapon_awp", 		"AWP", 					false},
	{WEAPON_SG550, 		"weapon_sg550", 	"SG-550", 				false},
	{WEAPON_M249, 		"weapon_m249", 		"M249",					false},
	{WEAPON_G3SG1, 		"weapon_g3sg1", 	"G3-SG1", 				false},
	{WEAPON_UMP45, 		"weapon_ump45", 	"UMP 45", 				false},
	{WEAPON_MP5N, 		"weapon_mp5navy", 	"MP5 Navy", 			false},
	{WEAPON_M3, 		"weapon_m3", 		"M3",					false},
	{WEAPON_XM1014, 	"weapon_xm1014", 	"XM1014", 				false},
	{WEAPON_TMP, 		"weapon_tmp", 		"TMP", 					false},
	{WEAPON_MAC10, 		"weapon_mac10", 	"Mac", 					false},
	{WEAPON_P90, 		"weapon_p90", 		"P90", 					false}
};

new const SECONDARY_WEAPONS[][e_StructWeapons] =
{
	{WEAPON_USP, 		"weapon_usp", 		"USP", 					true},
	{WEAPON_GLOCK18, 	"weapon_glock18", 	"Glock", 				true},
	{WEAPON_DEAGLE, 	"weapon_deagle", 	"Deagle", 				false},
	{WEAPON_P228, 		"weapon_p228", 		"P228", 				false},
	{WEAPON_ELITE, 		"weapon_elite", 	"Elite", 				false},
	{WEAPON_FIVESEVEN, 	"weapon_fiveseven", "Five SeveN", 			false}
};

enum _:structMaps {
	mapName[64],
	mapRandomSpawn
};

new const MAPS_ATTRIB[][structMaps] = {
	{"unnamed", 		0},
	{"32_aztecworld", 	0}, // Chico
	{"cs_assault", 		1}, 
	{"cs_dust3", 		0}, // Chico
	{"cs_italy", 		1},
	{"cs_militia", 		1},
	{"cs_office", 		1},
	{"css_cache", 		1},
	{"css_overpass",	1},
	{"de_aztec", 		1},
	{"de_dust", 		1},
	{"de_dust2", 		1},
	{"de_forge", 		1},
	{"de_inferno", 		1},
	{"de_mirage",		1},
	{"de_nuke", 		1},
	{"de_train", 		1},
	{"de_tuscan", 		1},
	{"dem_kdust", 		0}, // Chico
	{"dm_aztec", 		0}, // Chico
	{"dm_dust", 		0}, // Chico
	{"dm_x", 			0}, // Chico
	{"fy_snow_orange", 	0}  // Chico
};

const BIT_HEGRENADE = 1;
const BIT_FBGRENADE = 2;
const BIT_SGGRENADE = 4;

new const CLASSNAME_ENT_MEDKIT[] = "entMedKit";

enum (+= 123491)
{
	// PLAYER
	TASKID_TEAM = 1234555
};

#define ID_TEAM (taskid - TASKID_TEAM)

#define IsPlayer(%0) 					( 1 <= %0 <= MAX_CLIENTS )

#define GetPlayerBit(%0,%1) 			( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1) 			( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1) 			( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )
#define SwitchPlayerBit(%0,%1) 			( IsPlayer(%1) && ( %0 ^= ( 1 << ( %1 & 31 ) ) ) )

#define IsConnected(%0)					GetPlayerBit(g_bConnected, %0)
#define IsAlive(%0)						GetPlayerBit(g_bAlive, %0)

#define PDATA_SAFE						2
#define OFFSET_JOINSTATE				121
#define OFFSET_CSMENUCODE				205

#define KEYSMENU						((1<<0) | (1<<1) | (1<<2) | (1<<3) | (1<<4) | (1<<5) | (1<<6) | (1<<7) | (1<<8) | (1<<9))

new const MAXBPAMMO[] = { -1, 52, -1, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, -1, 100 };
new const AMMOTYPE[][] = { "", "357sig", "", "762nato", "", "buckshot", "", "45acp", "556nato", "", "9mm", "57mm", "45acp",
"556nato", "556nato", "556nato", "45acp", "9mm", "338magnum", "9mm", "556natobox", "buckshot",
"556nato", "9mm", "762nato", "", "50ae", "556nato", "762nato", "", "57mm" };

new const CS_TEAM_NAMES[][] = { "UNASSIGNED", "TERRORIST", "CT", "SPECTATOR" };

new const OBJECTIVES_ENTITIES[][] = {
	"func_bomb_target", "info_bomb_target",	"info_vip_start", "func_vip_safetyzone", "func_escapezone",
	"hostage_entity", "monster_scientist", "func_hostage_rescue", "info_hostage_rescue", "env_fog",
	"env_rain", "env_snow", "item_longjump", "func_vehicle", "game_player_equip",
	"info_map_parameters", "func_buyzone", "armoury_entity", "game_text"
};

new const g_sModelsTT[][] = {"arctic", "guerilla", "leet", "terror"};
new const g_sModelsCT[][] = {"gign", "gsg9", "sas", "urban"};

new const g_sModel_MedicKit[] = "models/w_medkit.mdl";

new const g_sSound_MedicKit[] = "items/smallmedkit1.wav";
new const g_sSound_WinNoOne[] = "ambience/3dmstart.wav";

public plugin_precache()
{
	new sBuffer[256];
	formatex(sBuffer, 63, "%s %s by FEDERICOMB", g_sPluginName, g_sPluginVersion);
	set_pcvar_string(create_cvar("dm_version", sBuffer, FCVAR_SERVER | FCVAR_SPONLY), sBuffer);
	set_pcvar_string(create_cvar("csdm_version", sBuffer, FCVAR_SERVER | FCVAR_SPONLY), sBuffer);
	set_pcvar_string(create_cvar("csdm_active", "1", FCVAR_SERVER | FCVAR_SPONLY), "1");

	g_pCvar__CSDM_OnlyHead = create_cvar("csdm_only_head", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0);
	g_pCvar__CSDM_FreeForAll = create_cvar("csdm_ffa", "0");
	g_pCvar__CSDM_Grenades = create_cvar("csdm_grenades", "h");
	g_pCvar__CSDM_MedicKit = create_cvar("csdm_drop_medic", "0", .has_min = true, .min_val = 0.0, .has_max = true, .max_val = 1.0);

	g_pCvar__CSDM_TimeRespawn = get_cvar_pointer("mp_forcerespawn");

	g_Forward_Spawn = register_forward(FM_Spawn, "OnFw__Spawn");
	g_Forward_PrecacheSound = register_forward(FM_PrecacheSound, "OnFw__PrecacheSound");

	new i;
	for( i = 0; i < sizeof(g_sModelsTT); ++i )
	{
		formatex(sBuffer, charsmax(sBuffer), "models/player/%s/%s.mdl", g_sModelsTT[i], g_sModelsTT[i]);
		precache_model(sBuffer);
	}

	for( i = 0; i < sizeof(g_sModelsCT); ++i )
	{
		formatex(sBuffer, charsmax(sBuffer), "models/player/%s/%s.mdl", g_sModelsCT[i], g_sModelsCT[i]);
		precache_model(sBuffer);
	}

	precache_model(g_sModel_MedicKit);

	precache_sound(g_sSound_MedicKit);
	precache_sound(g_sSound_WinNoOne);

	get_mapname(g_sCurrentMap, charsmax(g_sCurrentMap));
	strtolower(g_sCurrentMap);

	for( i = 0; i < sizeof(MAPS_ATTRIB); ++i )
	{
		if( equali(g_sCurrentMap, MAPS_ATTRIB[i][mapName]) )
		{
			g_iAllowRandomSpawns = MAPS_ATTRIB[i][mapRandomSpawn];

			break;
		}
	}
}

public plugin_init()
{
	register_plugin(g_sPluginName, g_sPluginVersion, g_sPluginAuthor);

	server_cmd("exec addons/amxmodx/configs/re_csdm_amxx.cfg");
	server_exec();

	loadSpawns(g_sCurrentMap);
	loadCvars();
	loadMenus();

	new const BLOCK_COMMANDS[][] =
	{
		"buy", "buyammo1", "buyammo2", "buyequip", "cl_autobuy", "cl_rebuy", "cl_setautobuy", "cl_setrebuy", "usp", "glock", "deagle", "p228", "elites", "fn57", "m3", "xm1014", "mp5", "tmp", "p90", "mac10", "ump45", "ak47", "galil", "famas", "sg552", "m4a1", "aug", "scout", "awp", "g3sg1",
		"sg550", "m249", "vest", "vesthelm", "flash", "hegren", "sgren", "defuser", "nvgs", "shield", "primammo", "secammo", "km45", "9x19mm", "nighthawk", "228compact", "fiveseven", "12gauge", "autoshotgun", "mp", "c90", "cv47", "defender", "clarion", "krieg552", "bullpup", "magnum",
		"d3au1", "krieg550", "smg", "coverme", "takepoint", "holdpos", "regroup", "followme", "takingfire", "go", "fallback", "sticktog", "getinpos", "stormfront", "report", "roger", "enemyspot", "needbackup", "sectorclear", "inposition", "reportingin", "getout", "negative", "enemydown", "radio1",
		"radio2", "radio3"
	};

	for( new i = 0; i < sizeof(BLOCK_COMMANDS); ++i )
	{
		register_clcmd(BLOCK_COMMANDS[i], "menu__CSBuy");
	}

	register_concmd("csdm_reload_spawns", "ConsoleCommand__Spawns");

	register_clcmd("menuselect", "ClientCommand__MenuSelect");
	register_clcmd("joinclass", "ClientCommand__MenuSelect");
	register_clcmd("drawradar", "ClientCommand__DrawRadar");

	register_clcmd("say guns", "ClientCommand__Weapons");
	register_clcmd("say_team guns", "ClientCommand__Weapons");
	UTIL_RegisterClientCommandAll("guns", "ClientCommand__Weapons");
	UTIL_RegisterClientCommandAll("armas", "ClientCommand__Weapons");

	RegisterHamPlayer(Ham_Spawn, "OnHam__PlayerSpawn_Post", 1);
	RegisterHamPlayer(Ham_TakeDamage, "OnHam__PlayerTakeDamage");
	RegisterHamPlayer(Ham_TraceAttack, "OnHam__PlayerTraceAttack");
	RegisterHamPlayer(Ham_Killed, "OnHam__PlayerKilled");
	RegisterHamPlayer(Ham_Killed, "OnHam__PlayerKilled_Post", 1);
	DisableHamForward(g_iHhCBasePlayerPreThink = RegisterHamPlayer(Ham_Player_PreThink, "OnHam__PlayerPreThink_Post", 1));

	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy", false);

	unregister_forward(FM_Spawn, g_Forward_Spawn);
	unregister_forward(FM_PrecacheSound, g_Forward_PrecacheSound);

	register_forward(FM_SetClientKeyValue, "OnFw__SetClientKeyValue");
	register_forward(FM_ClientUserInfoChanged, "OnFw__ClientUserInfoChanged");
	register_forward(FM_EmitSound, "OnFw__EmitSound");
	register_forward(FM_ClientKill, "OnFw__ClientKill");

	if( g_iCSDM_MedicKit )
	{
		register_touch(CLASSNAME_ENT_MEDKIT, "player", "touch__MedicKit");
		register_think(CLASSNAME_ENT_MEDKIT, "think__MedicKit");
	}

	g_Message_TeamInfo = get_user_msgid("TeamInfo");

	register_message(get_user_msgid("Money"), "message__Money");
	register_message(get_user_msgid("StatusIcon"), "message__StatusIcon");
	register_message(get_user_msgid("RoundTime"), "message__RoundTime");
	register_message(get_user_msgid("NVGToggle"), "message__NVGToggle");
	register_message(get_user_msgid("TextMsg"), "message__TextMsg");
	register_message(get_user_msgid("SendAudio"), "message__SendAudio");

	if( g_iCSDM_FreeForAll )
	{
		set_msg_block(get_user_msgid("Radar"), BLOCK_SET);
	}

	register_menu("MenuEquip", KEYSMENU, "menu__Equip");

	register_menucmd(register_menuid("#Buy", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuyPistol", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuyShotgun", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuySub", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuyRifle", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuyMachine", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuyItem", 1), 511, "menu__CSBuy");
	register_menucmd(register_menuid("BuyEquip", 1), 511, "menu__CSBuy");
	register_menucmd(-28, 511, "menu__CSBuy");
	register_menucmd(-29, 511, "menu__CSBuy");
	register_menucmd(-30, 511, "menu__CSBuy");
	register_menucmd(-32, 511, "menu__CSBuy");
	register_menucmd(-31, 511, "menu__CSBuy");
	register_menucmd(-33, 511, "menu__CSBuy");
	register_menucmd(-34, 511, "menu__CSBuy");

	g_iMaxUsers = get_maxplayers();

	// g_iSyncHudSpawn = CreateHudSyncObj();
	g_iSyncHudDamage = CreateHudSyncObj();
}

public plugin_cfg()
{
	server_cmd("exec addons/amxmodx/configs/re_csdm_amxx.cfg");
	server_exec();

	server_cmd("sv_restart 1");
}

loadSpawns( const map[] )
{
	new sBuffer[64];
	get_configsdir(sBuffer, charsmax(sBuffer));
	format(sBuffer, charsmax(sBuffer), "%s/spawns/%s_spawns.cfg", sBuffer, map);

	g_iSpawnCount = 0;

	if( file_exists(sBuffer) )
	{
		new iFile;
		iFile = fopen(sBuffer, "r");
		
		if( iFile )
		{
			new sLine[64];
			new sTeam[5];
			new sOrigin[3][16];
			new sAngles[3][16];

			while( !feof(iFile) )
			{
				fgets(iFile, sLine, charsmax(sLine));
				
				if( !sLine[0] || sLine[0] == ';' || sLine[0] == ' ' || (sLine[0] == '/' && (sLine[1] == '/' || sLine[1] == '*')) || sLine[0] == '[' || strlen(sLine) < 2 )
				{
					continue;
				}
				
				parse(sLine,
				sTeam, 4,
				sOrigin[0], charsmax(sOrigin[]), sOrigin[1], charsmax(sOrigin[]), sOrigin[2], charsmax(sOrigin[]),
				sAngles[0], charsmax(sAngles[]), sAngles[1], charsmax(sAngles[]), sAngles[2], charsmax(sAngles[]));
				
				g_iSpawnsTeam[g_iSpawnCount] = (sTeam[0] == 'C') ? TEAM_CT : TEAM_TERRORIST;

				g_fSpawns[g_iSpawnCount][0] = str_to_float(sOrigin[0]);
				g_fSpawns[g_iSpawnCount][1] = str_to_float(sOrigin[1]);
				g_fSpawns[g_iSpawnCount][2] = str_to_float(sOrigin[2]);
				
				g_fSpawnsAngles[g_iSpawnCount][0] = str_to_float(sAngles[0]);
				g_fSpawnsAngles[g_iSpawnCount][1] = str_to_float(sAngles[1]);
				g_fSpawnsAngles[g_iSpawnCount][2] = str_to_float(sAngles[2]);
				
				if( ++g_iSpawnCount >= MAX_CSDM_SPAWNS )
				{
					break;
				}
			}
			
			fclose(iFile);
		}
	}
	else
	{
		new const SPAWN_NAME_ENTS[][] = { "info_player_start", "info_player_deathmatch" };
		new Float:vecOrigin[3];
		new Float:vecAngles[3];
		new iEnt;
		new i;

		for( i = 0; i < 2; ++i )
		{
			iEnt = MAX_CLIENTS;
			while( (iEnt = rg_find_ent_by_class(iEnt, SPAWN_NAME_ENTS[i])) > 0 )
			{
				get_entvar(iEnt, var_origin, vecOrigin);
				get_entvar(iEnt, var_angles, vecAngles);

				g_iSpawnsTeam[g_iSpawnCount] = (!i) ? TEAM_CT : TEAM_TERRORIST;

				xs_vec_copy(vecOrigin, g_fSpawns[g_iSpawnCount]);
				xs_vec_copy(vecAngles, g_fSpawnsAngles[g_iSpawnCount]);

				if( ++g_iSpawnCount >= MAX_CSDM_SPAWNS )
				{
					break;
				}
			}
			
			if( g_iSpawnCount >= MAX_CSDM_SPAWNS )
			{
				break;
			}
		}
	}

	server_print("[CSDM] Spawns cargados: %d", g_iSpawnCount);
	return g_iSpawnCount;
}

loadCvars()
{
	g_iCSDM_OnlyHead = get_pcvar_num(g_pCvar__CSDM_OnlyHead);
	g_iCSDM_FreeForAll = TeamName:clamp(get_pcvar_num(g_pCvar__CSDM_FreeForAll), _:TEAM_UNASSIGNED, _:TEAM_CT);

	get_pcvar_string(g_pCvar__CSDM_Grenades, g_sCSDM_Grenades, charsmax(g_sCSDM_Grenades));
	{
		if(containi(g_sCSDM_Grenades, "h") != -1)
		{
			g_bCSDM_Grenades |= BIT_HEGRENADE;
		}

		if(containi(g_sCSDM_Grenades, "f") != -1)
		{
			g_bCSDM_Grenades |= BIT_FBGRENADE;
		}

		if(containi(g_sCSDM_Grenades, "s") != -1)
		{
			g_bCSDM_Grenades |= BIT_SGGRENADE;
		}
	}

	g_iCSDM_MedicKit = get_pcvar_num(g_pCvar__CSDM_MedicKit);
}

loadMenus()
{
	new i;

	// Primary Weapons
	{
		g_iGlobalMenuOne = menu_create(fmt("\y%s :\w Armas primarias\R\y", g_sPluginName), "menu__PrimaryWeapons");

		for( i = 0; i < sizeof(PRIMARY_WEAPONS); ++i )
		{
			menu_additem(g_iGlobalMenuOne, PRIMARY_WEAPONS[i][weaponNames]);
		}

		menu_setprop(g_iGlobalMenuOne, MPROP_NEXTNAME, "Página siguiente");
		menu_setprop(g_iGlobalMenuOne, MPROP_BACKNAME, "Página anterior");
		menu_setprop(g_iGlobalMenuOne, MPROP_EXITNAME, "Salir");
	}

	// Secondary Weapons
	{
		g_iGlobalMenuTwo = menu_create(fmt("\y%s :\w Armas secundarias\R\y", g_sPluginName), "menu__SecondaryWeapons");

		for( i = 0; i < sizeof(SECONDARY_WEAPONS); ++i )
		{
			menu_additem(g_iGlobalMenuTwo, SECONDARY_WEAPONS[i][weaponNames]);
		}

		menu_setprop(g_iGlobalMenuTwo, MPROP_NEXTNAME, "Página siguiente");
		menu_setprop(g_iGlobalMenuTwo, MPROP_BACKNAME, "Página anterior");
		menu_setprop(g_iGlobalMenuTwo, MPROP_EXITNAME, "Salir");
	}
}

public client_putinserver(id)
{
	new i;

	SetPlayerBit(g_bConnected, id);
	ClearPlayerBit(g_bAlive, id);
	g_iPlayerModel[id] = g_iSetNextModel;
	g_iMenuInfo[id] = 0;
	g_iPrimaryWeapons[id] = 0;
	g_iPrimaryWeaponsEnt[id] = 0;
	g_iSecondaryWeapons[id] = 0;
	g_iSecondaryWeaponsEnt[id] = 0;
	g_iDontShowTheMenuAgain[id] = 0;
	g_iCurrentWeapon[id] = WEAPON_NONE;
	g_iFixChooseWeapon[id] = 0;
	g_iSysTimePlayer[id] = get_systime();

	for( i = 0; i < structWeaponData; ++i )
	{
		g_iWeaponData[id][i] = 0;
	}

	switch( g_iCSDM_FreeForAll )
	{
		case TEAM_TERRORIST:
		{
			if( ++g_iSetNextModel > charsmax(g_sModelsTT) )
			{
				g_iSetNextModel = 0;
			}
		}

		case TEAM_CT:
		{
			if( ++g_iSetNextModel > charsmax(g_sModelsCT) )
			{
				g_iSetNextModel = 0;
			}
		}
	}
}

public client_disconnected(id)
{
	remove_task(id + TASKID_TEAM);

	ClearPlayerBit(g_bConnected, id);
	ClearPlayerBit(g_bAlive, id);
}

/*************************************************************************************/
/********************************* CLIENT COMMANDS  *********************************/
/*************************************************************************************/
public menu__CSBuy()
{
	return PLUGIN_HANDLED;
}

public ConsoleCommand__Spawns(const id)
{
	if( ~get_user_flags(id) & ADMIN_IMMUNITY ) 
	{
		return PLUGIN_HANDLED;
	}

	if( loadSpawns(g_sCurrentMap) )
	{
		console_print(id, "[CSDM] Spawns recargados: %d total", g_iSpawnCount);
	}

	return PLUGIN_HANDLED;
}

public ClientCommand__MenuSelect(const id) {
    if(get_pdata_int(id, OFFSET_CSMENUCODE) == 3 && get_pdata_int(id, OFFSET_JOINSTATE) == 4) {
		EnableHamForward(g_iHhCBasePlayerPreThink);
	}
}

public ClientCommand__DrawRadar(const id)
{
	return (g_iCSDM_FreeForAll) ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public ClientCommand__Weapons(const id)
{
	if( !g_iDontShowTheMenuAgain[id] )
	{
		return PLUGIN_HANDLED;
	}

	g_iDontShowTheMenuAgain[id] = 0;
	client_print_color(id, print_team_default, "%sEn tu próxima regeneración podrás seleccionar nuevas armas!", g_sGlobalPrefix);

	return PLUGIN_HANDLED;
}

/*************************************************************************************/
/************************************ HAM PLAYER *************************************/
/*************************************************************************************/
public OnHam__PlayerSpawn_Post(const id)
{
	if( !is_user_alive(id) )
	{
		return;
	}
	
	SetPlayerBit(g_bAlive, id);

	if( g_iCSDM_FreeForAll )
	{
		if( GetUserTeam(id) != g_iCSDM_FreeForAll )
		{
			remove_task(id + TASKID_TEAM);
			
			SetUserTeam(id, g_iCSDM_FreeForAll);
			userTeamUpdate(id);
		}
	}

	if( g_iCSDM_FreeForAll )
	{
		new sCurrentModel[32];
		getUserModel(id, sCurrentModel, charsmax(sCurrentModel));
		
		switch( g_iCSDM_FreeForAll )
		{
			case TEAM_TERRORIST:
			{
				if( !equal(sCurrentModel, g_sModelsTT[g_iPlayerModel[id]]) )
				{
					setUserModel(id, g_sModelsTT[g_iPlayerModel[id]]);
				}
			}

			case TEAM_CT:
			{
				if( !equal(sCurrentModel, g_sModelsCT[g_iPlayerModel[id]]) )
				{
					setUserModel(id, g_sModelsCT[g_iPlayerModel[id]]);
				}
			}
		}
	}

	randomSpawn(id);

	set_rendering(id);

	set_user_health(id, 100);
	set_user_armor(id, 100);

	cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM);

	if( !g_iDontShowTheMenuAgain[id] )
	{
		OnTaskRemoveWeapons(id);
	}

	OnTaskShowMenuWeapons(id);

	set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) | HIDEHUD_MONEY);
}

public OnHam__PlayerTakeDamage(const victim, const inflictor, const attacker, Float:damage, const damage_type)
{
	if( victim == attacker || !IsConnected(attacker) )
	{
		return HAM_IGNORED;
	}

	// if(g_iCSDM_OnlyHead) {
		// if(g_iCurrentWeapon[attacker] == CSW_KNIFE && get_pdata_int(victim, 75) != HIT_HEAD) {
			// set_hudmessage(255, 255, 0, -1.0, 0.57, 0, 0.0, 1.0, 0.0, 0.4, 2);
			// ShowSyncHudMsg(attacker, g_iSyncHudDamage, "¡APUNTA A LA CABEZA!");
			
			// return HAM_SUPERCEDE;
		// }
	// }

	if( g_iCSDM_FreeForAll )
	{
		static TeamName:iTeamVictim;
		iTeamVictim = GetUserTeam(victim);

		if( iTeamVictim == GetUserTeam(attacker) )
		{
			SetUserTeam(victim, (iTeamVictim == TEAM_CT) ? TEAM_TERRORIST : TEAM_CT);
			ExecuteHamB(Ham_TakeDamage, victim, inflictor, attacker, damage, damage_type);
			SetUserTeam(victim, g_iCSDM_FreeForAll);
			
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public OnHam__PlayerTraceAttack( const victim, const attacker, const Float:damage, const Float:direction[3], const tracehandle, const damage_type )
{
	if( victim == attacker || !IsConnected(attacker) )
	{
		return HAM_IGNORED;
	}

	if( g_iCSDM_OnlyHead )
	{
		static iHitGroup;
		iHitGroup = get_tr2(tracehandle, TR_iHitgroup);

		if( iHitGroup != HIT_HEAD )
		{
			if(g_iCurrentWeapon[attacker] == WEAPON_KNIFE)
			{
				set_hudmessage(255, 255, 0, -1.0, 0.57, 0, 0.0, 1.0, 0.0, 0.4, 2);
				ShowSyncHudMsg(attacker, g_iSyncHudDamage, "¡APUNTA A LA CABEZA!");
			}

			return HAM_SUPERCEDE;
		}
	}

	if( g_iCSDM_FreeForAll )
	{
		static TeamName:iTeamVictim;
		iTeamVictim = GetUserTeam(victim);
		
		if( iTeamVictim == GetUserTeam(attacker) )
		{
			SetUserTeam(victim, (iTeamVictim == TEAM_CT) ? TEAM_TERRORIST : TEAM_CT);
			ExecuteHamB(Ham_TraceAttack, victim, attacker, damage, direction, tracehandle, damage_type);
			SetUserTeam(victim, g_iCSDM_FreeForAll);
			
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public OnHam__PlayerKilled( const victim, const killer, const shouldgib )
{
	ClearPlayerBit(g_bAlive, victim);

	for( new i = 0; i < structWeaponData; ++i )
	{
		g_iWeaponData[victim][i] = 0;
	}

	new WeaponIdType:iWid;

	if( PRIMARY_WEAPONS[g_iPrimaryWeapons[victim]][weaponSilenced] )
	{
		iWid = PRIMARY_WEAPONS[g_iPrimaryWeapons[victim]][weaponId];

		if( user_has_weapon(victim, _:iWid) )
		{
			if( is_valid_ent(g_iPrimaryWeaponsEnt[victim]) )
			{
				switch( iWid )
				{
					case CSW_M4A1: g_iWeaponData[victim][weaponM4A1] = cs_get_weapon_silen(g_iPrimaryWeaponsEnt[victim]);
					case CSW_FAMAS: g_iWeaponData[victim][weaponFAMAS] = cs_get_weapon_burst(g_iPrimaryWeaponsEnt[victim]);
				}
			}
		}
	}

	if(SECONDARY_WEAPONS[g_iSecondaryWeapons[victim]][weaponSilenced])
	{
		iWid = SECONDARY_WEAPONS[g_iSecondaryWeapons[victim]][weaponId];

		if( user_has_weapon(victim, _:iWid) )
		{
			if( is_valid_ent(g_iSecondaryWeaponsEnt[victim]) )
			{
				switch( iWid )
				{
					case CSW_USP: g_iWeaponData[victim][weaponUSP] = cs_get_weapon_silen(g_iSecondaryWeaponsEnt[victim]);
					case CSW_GLOCK18: g_iWeaponData[victim][weaponGLOCK] = cs_get_weapon_burst(g_iSecondaryWeaponsEnt[victim]);
				}
			}
		}
	}

	if( get_pdata_int(victim, 76) == DMG_FALL || (IsConnected(killer) && (g_iCurrentWeapon[killer] == WEAPON_AWP || g_iCurrentWeapon[killer] == WEAPON_SCOUT) && get_pdata_int(victim, 75) == HIT_HEAD) )
	{
		SetHamParamInteger(3, 2);
	}

	if( killer == victim || !IsConnected(killer) )
	{
		return HAM_IGNORED;
	}

	if( GetPlayerBit(g_bAlive, killer) )
	{
		set_user_armor(killer, 100);
		cs_set_user_armor(killer, 100, CS_ARMOR_VESTHELM);
	}

	if( g_iCSDM_MedicKit )
	{
		if( random_num(0, 14) <= 3 )
		{
			new Float:vecOrigin[3];
			new Float:vecEndOrigin[3];
			new Float:fFraction;
			new iTraceResult;
			
			entity_get_vector(victim, EV_VEC_origin, vecOrigin);
			getDropOrigin(victim, vecEndOrigin, 20);
			
			iTraceResult = 0;
			engfunc(EngFunc_TraceLine, vecOrigin, vecEndOrigin, IGNORE_MONSTERS, victim, iTraceResult);
			
			get_tr2(iTraceResult, TR_flFraction, fFraction);
			
			if( fFraction == 1.0 )
			{
				dropEntForHumans(victim);
			}
		}
	}

	if( g_iCSDM_FreeForAll )
	{
		static TeamName:iTeamVictim;
		iTeamVictim = GetUserTeam(victim);
		
		if( iTeamVictim == GetUserTeam(killer) )
		{
			SetUserTeam(victim, (iTeamVictim == TEAM_CT) ? TEAM_TERRORIST : TEAM_CT);
			ExecuteHamB(Ham_Killed, victim, killer, shouldgib);
			SetUserTeam(victim, g_iCSDM_FreeForAll);
			
			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public OnHam__PlayerKilled_Post( const victim, const killer, const shouldgib )
{
	set_task(get_pcvar_float(g_pCvar__CSDM_TimeRespawn) + 0.5, "OnTaskRespawnPlayerCheck", victim);
}

public OnHam__PlayerPreThink_Post( const id )
{
	DisableHamForward(g_iHhCBasePlayerPreThink);

	if( !GetPlayerBit(g_bAlive, id) )
	{
		set_task(random_float(0.7, 1.9), "OnTaskRespawnPlayerCheck", id);
	}
}

public CBasePlayerWeapon_DefaultDeploy( const weapon, const sViewModel[], const sWeaponModel[], const iAnim, const sAnimExt[], const skiplocal )
{
	g_iCurrentWeapon[get_member(weapon, m_pPlayer)] = WeaponIdType:get_member(weapon, m_iId);
	return HC_CONTINUE;
}

public OnTaskRemoveWeapons( const id )
{
	if( !GetPlayerBit(g_bAlive, id) )
	{
		return;
	}

	strip_user_weapons(id);
	rg_give_item(id, "weapon_knife");
}

public OnTaskShowMenuWeapons( const id )
{
	if( !GetPlayerBit(g_bAlive, id) )
	{
		return;
	}

	if( g_iDontShowTheMenuAgain[id] && g_iFixChooseWeapon[id] )
	{
		strip_user_weapons(id);
		
		giveWeapons(id, 1);
		giveWeapons(id, 2);
		giveWeapons(id, 3);

		rg_give_item(id, "weapon_knife");

		return;
	}

	show_menu(
		id,
		g_iFixChooseWeapon[id] ? (MENU_KEY_1 | MENU_KEY_2 | MENU_KEY_3) : (MENU_KEY_1),
		fmt("\y%s : Equipamiento^n\rby\y %s^n^n\r1.\w Armas Nuevas^n%s", g_sPluginName, g_sPluginAuthor, g_iFixChooseWeapon[id] ? "\r2.\w Selección Anterior^n\r3.\w 2 + No mostrar más el Menú" : "\d2. Selección Anterior^n3. 2 + No mostrar más el Menú"),
		-1,
		"MenuEquip"
	);
}

public menu__Equip( const id, const key )
{
	if( !GetPlayerBit(g_bAlive, id) )
	{
		return PLUGIN_HANDLED;
	}

	switch( key )
	{
		case 0: showMenu__Weapons(id, 2);

		case 1:
		{
			giveWeapons(id, 1);
			giveWeapons(id, 2);
			giveWeapons(id, 3);
		}

		case 2:
		{
			g_iDontShowTheMenuAgain[id] = 1;

			giveWeapons(id, 1);
			giveWeapons(id, 2);
			giveWeapons(id, 3);

			client_print_color(id, print_team_default, "%sEscribe^4 guns^1 para activar nuevamente el menú de armamento", g_sGlobalPrefix);
		}
	}

	return PLUGIN_HANDLED;
}

showMenu__Weapons( const id, const weapons )
{
	if( !GetPlayerBit(g_bAlive, id) )
	{
		return;
	}

	switch( weapons )
	{
		case 1: menu_display(id, g_iGlobalMenuOne, 0);
		case 2: menu_display(id, g_iGlobalMenuTwo, 0);
	}
}

public menu__PrimaryWeapons( const id, const menuid, const itemid )
{
	if( !GetPlayerBit(g_bAlive, id) || itemid == MENU_EXIT )
	{
		return PLUGIN_HANDLED;
	}

	g_iPrimaryWeapons[id] = itemid;
	giveWeapons(id, 1);
	giveWeapons(id, 3);

	return PLUGIN_HANDLED;
}

public menu__SecondaryWeapons( const id, const menuid, const itemid )
{
	if( !GetPlayerBit(g_bAlive, id) || itemid == MENU_EXIT )
	{
		return PLUGIN_HANDLED;
	}

	g_iSecondaryWeapons[id] = itemid;
	giveWeapons(id, 2);
	
	showMenu__Weapons(id, 1);
	return PLUGIN_HANDLED;
}

public giveWeapons( const id, const weapon )
{
	if( !GetPlayerBit(g_bAlive, id) )
	{
		return;
	}

	new WeaponIdType:iWid;

	switch( weapon )
	{
		case 1:
		{
			if( g_iPrimaryWeapons[id] < 0 || g_iPrimaryWeapons[id] >= sizeof(PRIMARY_WEAPONS) )
			{
				g_iPrimaryWeapons[id] = 0;
			}

			iWid = PRIMARY_WEAPONS[g_iPrimaryWeapons[id]][weaponId];

			g_iPrimaryWeaponsEnt[id] = rg_give_item(id, PRIMARY_WEAPONS[g_iPrimaryWeapons[id]][weaponEnt]);
			ExecuteHamB(Ham_GiveAmmo, id, MAXBPAMMO[_:iWid], AMMOTYPE[_:iWid], MAXBPAMMO[_:iWid]);

			if( iWid == WEAPON_M4A1 || iWid == WEAPON_FAMAS )
			{
				if( is_valid_ent(g_iPrimaryWeaponsEnt[id]) )
				{
					switch( iWid )
					{
						case WEAPON_M4A1:
						{
							cs_set_weapon_silen(g_iPrimaryWeaponsEnt[id], g_iWeaponData[id][weaponM4A1], 0);

							if( g_iWeaponData[id][weaponM4A1] )
							{
								iWid = get_member(id, m_pActiveItem);
								
								if( WeaponIdType:cs_get_weapon_id(_:iWid) == WEAPON_M4A1 )
								{
									setAnimation(id, 5);
								}
							}
						}
						case WEAPON_FAMAS: cs_set_weapon_burst(g_iPrimaryWeaponsEnt[id], g_iWeaponData[id][weaponFAMAS]);
					}
				}
			}
		}

		case 2:
		{
			if( g_iSecondaryWeapons[id] < 0 || g_iSecondaryWeapons[id] >= sizeof(SECONDARY_WEAPONS) )
			{
				g_iSecondaryWeapons[id] = 0;
			}

			iWid = SECONDARY_WEAPONS[g_iSecondaryWeapons[id]][weaponId];

			g_iSecondaryWeaponsEnt[id] = rg_give_item(id, SECONDARY_WEAPONS[g_iSecondaryWeapons[id]][weaponEnt]);
			ExecuteHamB(Ham_GiveAmmo, id, MAXBPAMMO[_:iWid], AMMOTYPE[_:iWid], MAXBPAMMO[_:iWid]);

			if( iWid == WEAPON_USP || iWid == WEAPON_GLOCK18 )
			{
				if( is_valid_ent(g_iSecondaryWeaponsEnt[id]) )
				{
					switch( iWid )
					{
						case CSW_USP: cs_set_weapon_silen(g_iSecondaryWeaponsEnt[id], g_iWeaponData[id][weaponUSP], 0);
						case CSW_GLOCK18: cs_set_weapon_burst(g_iSecondaryWeaponsEnt[id], g_iWeaponData[id][weaponGLOCK]);
					}
				}
			}
		}

		case 3:
		{
			if( g_bCSDM_Grenades & BIT_HEGRENADE )
			{
				rg_give_item(id, "weapon_hegrenade");
			}

			if( g_bCSDM_Grenades & BIT_FBGRENADE )
			{
				rg_give_item(id, "weapon_flashbang");
			}

			if( g_bCSDM_Grenades & BIT_SGGRENADE )
			{
				rg_give_item(id, "weapon_smokegrenade");
			}

			g_iFixChooseWeapon[id] = 1;
		}
	}
}

public OnTaskRespawnPlayerCheck( const id )
{
	if( !GetPlayerBit(g_bConnected, id) || GetPlayerBit(g_bAlive, id) )
	{
		return;
	}

	static TeamName:iTeam;
	iTeam = GetUserTeam(id);

	if( iTeam != TEAM_UNASSIGNED && iTeam != TEAM_SPECTATOR )
	{
		rg_round_respawn(id);
	}

	set_task(get_pcvar_float(g_pCvar__CSDM_TimeRespawn), "OnTaskRespawnPlayerCheck", id);
}

/*************************************************************************************/
/************************************** THINKS  **************************************/
/*************************************************************************************/
public think__MedicKit(const medickit) {
	if(is_valid_ent(medickit)) {
		static Float:fRenderAmt;
		fRenderAmt = entity_get_float(medickit, EV_FL_renderamt);
		
		if(fRenderAmt == 255.0) {
			entity_set_int(medickit, EV_INT_movetype, MOVETYPE_FLY);
			entity_set_int(medickit, EV_INT_rendermode, kRenderTransAlpha);
			entity_set_int(medickit, EV_INT_renderfx, kRenderFxGlowShell);
			
			entity_set_vector(medickit, EV_VEC_rendercolor, Float:{255.0, 255.0, 0.0});
			entity_set_vector(medickit, EV_VEC_velocity, Float:{0.0, 0.0, 20.0});
			
			entity_set_float(medickit, EV_FL_renderamt, fRenderAmt - 25.0);
			entity_set_float(medickit, EV_FL_nextthink, get_gametime() + 0.01);
			
			return;
		}
		
		fRenderAmt -= 25.0;
		
		if(fRenderAmt < 0.0) {
			remove_entity(medickit);
			return;
		}
		
		entity_set_float(medickit, EV_FL_renderamt, fRenderAmt);
		entity_set_float(medickit, EV_FL_nextthink, get_gametime() + 0.1);
	}
}

public OnFw__Spawn(const iEntity) {
	if(!is_valid_ent(iEntity)) {
		return FMRES_IGNORED;
	}

	new sClassName[32];
	entity_get_string(iEntity, EV_SZ_classname, sClassName, 31);
	
	new i;
	for(i = 0; i < sizeof(OBJECTIVES_ENTITIES); ++i) {
		if(equal(sClassName, OBJECTIVES_ENTITIES[i])) {
			remove_entity(iEntity);
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public OnFw__PrecacheSound(const sound[]) {
	if(equal(sound, "hostage", 7)) {
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public OnFw__SetClientKeyValue(const id, const infobuffer[], const key[]) {
	if(g_iCSDM_FreeForAll) {
		if(key[0] == 'm' && key[1] == 'o' && key[2] == 'd' && key[3] == 'e' && key[4] == 'l') {
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public OnFw__ClientUserInfoChanged(const id, const buffer)
{
	if( !IsConnected(id) )
	{
		return FMRES_IGNORED;
	}
	
	if(g_iCSDM_FreeForAll) {
		static sCurrentModel[32];
		getUserModel(id, sCurrentModel, charsmax(sCurrentModel));
		
		switch(g_iCSDM_FreeForAll) {
			case TEAM_TERRORIST: {
				if(!equal(sCurrentModel, g_sModelsTT[g_iPlayerModel[id]])) {
					setUserModel(id, g_sModelsTT[g_iPlayerModel[id]]);
				}
			}

			case TEAM_CT: {
				if(!equal(sCurrentModel, g_sModelsCT[g_iPlayerModel[id]])) {
					setUserModel(id, g_sModelsCT[g_iPlayerModel[id]]);
				}
			}
		}
	}

	return FMRES_IGNORED;
}

public OnFw__EmitSound( const id, const channel, const sample[], const Float:volume, const Float:attn, const flags, const pitch )
{
	// HOSTAGE
	if( sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e' )
	{
		return FMRES_SUPERCEDE;
	}

	// if(g_iCSDM_FreeForAll) {
		// GUNPICKUP2
		// if(sample[6] == 'g' && sample[7] == 'u' && sample[8] == 'n' && sample[9] == 'p' && sample[10] == 'i' && sample[11] == 'c' && sample[12] == 'k' && sample[13] == 'u'	&& sample[14] == 'p' && sample[15] == '2') {
			// return FMRES_SUPERCEDE;
		// }
	// }

	return FMRES_IGNORED;
}

public OnFw__ClientKill()
{
	return FMRES_SUPERCEDE;
}

public touch__MedicKit(const medickit, const id)
{
	if( !is_nullent(medickit) || !IsAlive(id) )
	{
		return;
	}

	new iHealth = get_user_health(id);

	if( iHealth < 100 )
	{
		iHealth += 15;

		if( iHealth > 100 )
		{
			iHealth = 100;
		}

		set_user_health(id, iHealth);
		
		emitSound(id, CHAN_ITEM, g_sSound_MedicKit);
		
		remove_entity(medickit);
	}
}
/*************************************************************************************/
/************************************* MESSAGES  *************************************/
/*************************************************************************************/
public message__Money(const msgId, const destId, const id)
{
	if( IsConnected(id) )
	{
		cs_set_user_money(id, 0, 0);
	}
	
	return PLUGIN_HANDLED;
}

public message__StatusIcon(const msgId, const destId, const id)
{
	static sIcon[8];
	get_msg_arg_string(2, sIcon, 7);
	
	// buyzone
	if(sIcon[0] == 'b' && sIcon[1] == 'u' && sIcon[2] == 'y' && sIcon[3] == 'z' && sIcon[4] == 'o' && sIcon[5] == 'n' && sIcon[6] == 'e' && get_msg_arg_int(1))
	{
		if(pev_valid(id) == PDATA_SAFE)
		{
			set_pdata_int(id, 235, get_pdata_int(id, 235) & ~(1<<0));
		}

		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public message__RoundTime(const msgId, const destId, const id)
{
	set_msg_arg_int(1, ARG_SHORT, get_timeleft());
}

public message__NVGToggle(const msgId, const destId, const id)
{
	return PLUGIN_HANDLED;
}

public message__TextMsg(const msgId, const destId, const id)
{
	static sMsg[22];
	get_msg_arg_string(2, sMsg, 21);
	
	
	if(
		// #Game_teammate_attack
		sMsg[1] == 'G' && sMsg[2] == 'a' && sMsg[3] == 'm' && sMsg[4] == 'e' &&
		sMsg[6] == 't' && sMsg[7] == 'e' && sMsg[8] == 'a' && sMsg[9] == 'm' && sMsg[10] == 'm' && sMsg[11] == 'a' && sMsg[12] == 't' && sMsg[13] == 'e' &&
		sMsg[15] == 'a' && sMsg[16] == 't' && sMsg[17] == 't' && sMsg[18] == 'a' && sMsg[19] == 'c' && sMsg[20] == 'k'
	||
		// #Game_Commencing
		sMsg[1] == 'G' && sMsg[2] == 'a' && sMsg[3] == 'm' && sMsg[4] == 'e' &&
		sMsg[6] == 'C' && sMsg[7] == 'o' && sMsg[8] == 'm' && sMsg[9] == 'm' && sMsg[10] == 'e' && sMsg[11] == 'n' && sMsg[12] == 'c' && sMsg[13] == 'i' && sMsg[14] == 'n' && sMsg[15] == 'g'
	||
		// #Game_will_restart_in
		sMsg[1] == 'G' && sMsg[2] == 'a' && sMsg[3] == 'm' && sMsg[4] == 'e' &&
		sMsg[6] == 'w' && sMsg[7] == 'i' && sMsg[8] == 'l' && sMsg[9] == 'l' &&
		sMsg[11] == 'r' && sMsg[12] == 'e' && sMsg[13] == 's' && sMsg[14] == 't' &&	sMsg[15] == 'a' && sMsg[16] == 'r' && sMsg[17] == 't' &&
		sMsg[19] == 'i' && sMsg[20] == 'n'
	||
		// #Hostages_Not_Rescued
		sMsg[1] == 'H' && sMsg[2] == 'o' && sMsg[3] == 's' && sMsg[4] == 't' &&	sMsg[5] == 'a' && sMsg[6] == 'g' && sMsg[7] == 'e' && sMsg[8] == 's' &&
		sMsg[10] == 'N' && sMsg[11] == 'o' && sMsg[12] == 't' &&
		sMsg[14] == 'R' &&	sMsg[15] == 'e' && sMsg[16] == 's' && sMsg[17] == 'c' && sMsg[18] == 'u' && sMsg[19] == 'e' && sMsg[20] == 'd'
	||
		// #Round_Draw
		sMsg[1] == 'R' && sMsg[2] == 'o' && sMsg[3] == 'u' && sMsg[4] == 'n' &&	sMsg[5] == 'd' &&
		sMsg[7] == 'D' && sMsg[8] == 'r' && sMsg[9] == 'a' && sMsg[10] == 'w'
	||
		// #Terrorists_Win
		sMsg[1] == 'T' && sMsg[2] == 'e' && sMsg[3] == 'r' && sMsg[4] == 'r' &&	sMsg[5] == 'o' && sMsg[6] == 'r' && sMsg[7] == 'i' && sMsg[8] == 's' && sMsg[9] == 't' && sMsg[10] == 's' &&
		sMsg[12] == 'W' && sMsg[13] == 'i' && sMsg[14] == 'n'
	||
		// #CTs_Win
		sMsg[1] == 'C' && sMsg[2] == 'T' && sMsg[3] == 's' &&
		sMsg[5] == 'W' && sMsg[6] == 'i' && sMsg[7] == 'n'
	)
	{
		return PLUGIN_HANDLED;
	}

	// #Fire_in_the_hole
	if(get_msg_args() == 5 && (get_msg_argtype(5) == ARG_STRING)) {
		get_msg_arg_string(5, sMsg, 21);
		
		if(sMsg[1] == 'F' && sMsg[2] == 'i' && sMsg[3] == 'r' && sMsg[4] == 'e' &&
		sMsg[6] == 'i' && sMsg[7] == 'n' &&
		sMsg[9] == 't' && sMsg[10] == 'h' && sMsg[11] == 'e' &&
		sMsg[13] == 'h' && sMsg[14] == 'o' && sMsg[15] == 'l' && sMsg[16] == 'e') {
			return PLUGIN_HANDLED;
		}
	} else if(get_msg_args() == 6 && (get_msg_argtype(6) == ARG_STRING)) {
		get_msg_arg_string(6, sMsg, 21);
		
		if(sMsg[1] == 'F' && sMsg[2] == 'i' && sMsg[3] == 'r' && sMsg[4] == 'e' &&
		sMsg[6] == 'i' && sMsg[7] == 'n' &&
		sMsg[9] == 't' && sMsg[10] == 'h' && sMsg[11] == 'e' &&
		sMsg[13] == 'h' && sMsg[14] == 'o' && sMsg[15] == 'l' && sMsg[16] == 'e') {
			return PLUGIN_HANDLED;
		}
	}
	
	return PLUGIN_CONTINUE;
}

public message__SendAudio(const msgId, const destId, const id)
{
	static sAudio[19];
	get_msg_arg_string(2, sAudio, 18);
	
	if((sAudio[7] == 't' && sAudio[8] == 'e' && sAudio[9] == 'r' && sAudio[10] == 'w' && sAudio[11] == 'i' && sAudio[12] == 'n') ||
	(sAudio[7] == 'c' && sAudio[8] == 't' && sAudio[9] == 'w' && sAudio[10] == 'i' && sAudio[11] == 'n') ||
	(sAudio[7] == 'r' && sAudio[8] == 'o' && sAudio[9] == 'u' && sAudio[10] == 'n' && sAudio[11] == 'd' && sAudio[12] == 'd' && sAudio[13] == 'r' && sAudio[14] == 'a' && sAudio[15] == 'w') ||
	(sAudio[7] == 'F' && sAudio[8] == 'I' && sAudio[9] == 'R' && sAudio[10] == 'E' && sAudio[11] == 'I' && sAudio[12] == 'N' && sAudio[13] == 'H' && sAudio[14] == 'O' && sAudio[15] == 'L' && sAudio[16] == 'E')) {
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

/*************************************************************************************/
/************************************ STOCKS, ETC ************************************/
/*************************************************************************************/
public randomSpawn(const id)
{
	if( !g_iSpawnCount )
	{
		return;
	}

	new iHull;
	new iSpawnId;
	new TeamName:iTeam;
	new iCount = 0;
	new iSpawnPass = 0;
	new iFinal = -1;
	new i;

	new Float:fOriginPlayer[MAX_USERS][3];
	
	iHull = (get_entity_flags(id) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
	iSpawnId = random_num(0, g_iSpawnCount - 1);
	iTeam = GetUserTeam(id);

	for(i = 1; i <= g_iMaxUsers; ++i)
	{
		if( !GetPlayerBit(g_bAlive, i) || i == id || (!g_iCSDM_FreeForAll && iTeam == GetUserTeam(i)) )
		{
			continue;
		}

		entity_get_vector(i, EV_VEC_origin, fOriginPlayer[iCount++]);
	}

	while(iSpawnPass <= g_iSpawnCount) {
		if(iSpawnPass == g_iSpawnCount) { // Paso por todos los spawns?
			break;
		}

		if(++iSpawnId >= g_iSpawnCount) {
			iSpawnId = 0;
		}

		++iSpawnPass;

		if(!g_iCSDM_FreeForAll && !g_iAllowRandomSpawns && iTeam != g_iSpawnsTeam[iSpawnId]) {
			continue;
		}

		iFinal = iSpawnId;

		for(i = 0; i < iCount; ++i) {
			if(get_distance_f(g_fSpawns[iSpawnId], fOriginPlayer[i]) < 500.0) {
				iFinal = -1;
				break;
			}
		}

		if(iFinal == -1) {
			continue;
		}

		if(!isHullVacant(g_fSpawns[iFinal], iHull)) {
			continue;
		}

		if(iCount < 1) {
			break;
		}

		if(iFinal != -1) {
			break;
		}
	}

	if(iFinal != -1) {
		entity_set_int(id, EV_INT_fixangle, 1);
		entity_set_vector(id, EV_VEC_angles, g_fSpawnsAngles[iFinal]);
		entity_set_int(id, EV_INT_fixangle, 1);
		
		entity_set_vector(id, EV_VEC_origin, g_fSpawns[iFinal]);
	}

	set_task(0.25, "checkStuck", id);
}

public checkStuck(const id)
{
	if( GetPlayerBit(g_bAlive, id) && isUserStuck(id) )
	{
		randomSpawn(id);
	}
}

public isHullVacant(const Float:origin[3], const hull) {
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0);
	
	if(!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen)) {
		return 1;
	}
	
	return 0;
}

public isUserStuck(const id) {
	new Float:vecOrigin[3];
	entity_get_vector(id, EV_VEC_origin, vecOrigin);
	
	engfunc(EngFunc_TraceHull, vecOrigin, vecOrigin, 0, (entity_get_int(id, EV_INT_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0);
	
	if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen)) {
		return 1;
	}
	
	return 0;
}

public TeamName:GetUserTeam(const id)
{
	return get_member(id, m_iTeam);
}

public SetUserTeam(const id, const TeamName:team)
{
	set_member(id, m_iTeam, team);
}

public userTeamUpdate(const id) {
	static Float:fCurrentTime;
	fCurrentTime = get_gametime();
	
	if(fCurrentTime - g_fTeams_Time >= 0.1) {
		set_task(0.1, "setUserTeamMsg", id + TASKID_TEAM);
		g_fTeams_Time = fCurrentTime + 0.1;
	} else {
		set_task((g_fTeams_Time + 0.1) - fCurrentTime, "setUserTeamMsg", id + TASKID_TEAM);
		g_fTeams_Time = g_fTeams_Time + 0.1;
	}
}

public setUserTeamMsg(const taskid)
{
	emessage_begin(MSG_ALL, g_Message_TeamInfo);
	ewrite_byte(ID_TEAM);
	ewrite_string(CS_TEAM_NAMES[_:g_iCSDM_FreeForAll]);
	emessage_end();
}

public getUserModel(const id, model[], const len) {
	get_user_info(id, "model", model, len);
}

public setUserModel(const id, const model[]) {
	set_user_info(id, "model", model);
}

setAnimation(const id, const animation)
{
	set_entvar(id, var_weaponanim, animation);
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, _, id);
	write_byte(animation);
	write_byte(get_entvar(id, var_body));
	message_end();
}

emitSound(const id, const channel, const sample[], Float:vol = 1.0, Float:att = ATTN_NORM, flags = 0, pitch = PITCH_NORM) {
	emit_sound(id, channel, sample, vol, att, flags, pitch);
}

dropEntForHumans(const id) {
	new iEnt = create_entity("info_target");
	
	if(is_valid_ent(iEnt)) {
		new Float:vecVelocity[3];
		new Float:vecOrigin[3];
		
		entity_set_string(iEnt, EV_SZ_classname, CLASSNAME_ENT_MEDKIT);
		entity_set_model(iEnt, g_sModel_MedicKit);
		entity_set_size(iEnt, Float:{-23.16, -13.66, 0.0}, Float:{11.47, 12.78, 6.72});
		
		entity_set_int(iEnt, EV_INT_solid, SOLID_TRIGGER);
		entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_TOSS);
		entity_set_int(iEnt, EV_INT_rendermode, kRenderNormal);
		entity_set_int(iEnt, EV_INT_renderfx, kRenderFxNone);
		
		velocity_by_aim(id, 300, vecVelocity);
		getDropOrigin(id, vecOrigin);
		entity_set_vector(iEnt, EV_VEC_origin, vecOrigin);
		entity_set_vector(iEnt, EV_VEC_velocity, vecVelocity);
		entity_set_vector(iEnt, EV_VEC_mins, Float:{-23.16, -13.66, 0.0});
		entity_set_vector(iEnt, EV_VEC_maxs, Float:{11.47, 12.78, 6.72});
		
		entity_set_float(iEnt, EV_FL_renderamt, 255.0);
		entity_set_float(iEnt, EV_FL_takedamage, DAMAGE_NO);
		entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 15.0);
	}
}

getDropOrigin(const id, Float:vecOrigin[3], iVelAdd = 0) {
	new Float:vecAim[3];
	new Float:vecViewOfs[3];
	
	entity_get_vector(id, EV_VEC_view_ofs, vecViewOfs);
	entity_get_vector(id, EV_VEC_origin, vecOrigin);
	xs_vec_add(vecOrigin, vecViewOfs, vecOrigin);
	
	velocity_by_aim(id, 50 + iVelAdd, vecAim);
	
	vecOrigin[0] += vecAim[0];
	vecOrigin[1] += vecAim[1];
}

stock UTIL_RegisterClientCommandAll(const command[], function[], flags = -1, const info[] = "", FlagManager = -1, bool:info_ml = false)
{
	new sFormatCommand[PLATFORM_MAX_PATH];

	formatex(sFormatCommand, charsmax(sFormatCommand), "say %s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);
	
	formatex(sFormatCommand, charsmax(sFormatCommand), "say /%s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);

	formatex(sFormatCommand, charsmax(sFormatCommand), "say !%s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);
	
	formatex(sFormatCommand, charsmax(sFormatCommand), "say .%s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);

	formatex(sFormatCommand, charsmax(sFormatCommand), "say_team %s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);
	
	formatex(sFormatCommand, charsmax(sFormatCommand), "say_team /%s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);

	formatex(sFormatCommand, charsmax(sFormatCommand), "say_team !%s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);
	
	formatex(sFormatCommand, charsmax(sFormatCommand), "say_team .%s", command);
	register_clcmd(sFormatCommand, function, flags, info, FlagManager, info_ml);
}