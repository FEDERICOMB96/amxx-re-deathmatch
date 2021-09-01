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
new const g_sPluginVersion[] = "v4";
new const g_sPluginAuthor[] = "FEDERICOMB";

new const g_sGlobalPrefix[] = "^4[DEATHMATCH]^1 ";

const MAX_USERS = 33;
const MAX_CSDM_SPAWNS = 120;

/// Player Vars
new g_bConnected;
new g_bAlive;

new g_iMenuInfo[MAX_USERS];
new g_iPrimaryWeapons[MAX_USERS];
new g_iPrimaryWeaponsEnt[MAX_USERS];
new g_iSecondaryWeapons[MAX_USERS];
new g_iSecondaryWeaponsEnt[MAX_USERS];
new g_iDontShowTheMenuAgain[MAX_USERS];

enum _:structWeaponData {
	weaponM4A1 = 0,
	weaponFAMAS,
	weaponUSP,
	weaponGLOCK
};
new g_iWeaponData[MAX_USERS][structWeaponData];

/// Global Vars
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

/// Message Vars
new g_Message_TeamInfo = 0;

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

	loadSpawns();
	loadCvars();
	loadMenus();

	register_concmd("csdm_reload_spawns", "ConsoleCommand__Spawns");

	UTIL_RegisterClientCommandAll("guns", "ClientCommand__Weapons");
	UTIL_RegisterClientCommandAll("armas", "ClientCommand__Weapons");

	RegisterHamPlayer(Ham_Spawn, "OnHam__PlayerSpawn_Post", 1);
	RegisterHamPlayer(Ham_TraceAttack, "OnHam__PlayerTraceAttack");
	RegisterHamPlayer(Ham_Killed, "OnHam__PlayerKilled");
	RegisterHamPlayer(Ham_Killed, "OnHam__PlayerKilled_Post", 1);

	unregister_forward(FM_Spawn, g_Forward_Spawn);

	register_forward(FM_ClientKill, "OnFw__ClientKill");

	if( g_iCSDM_MedicKit )
	{
		register_touch(CLASSNAME_ENT_MEDKIT, "player", "touch__MedicKit");
		register_think(CLASSNAME_ENT_MEDKIT, "think__MedicKit");
	}

	g_Message_TeamInfo = get_user_msgid("TeamInfo");

	register_message(get_user_msgid("RoundTime"), "message__RoundTime");
	register_message(get_user_msgid("NVGToggle"), "message__NVGToggle");
	register_message(get_user_msgid("TextMsg"), "message__TextMsg");
	register_message(get_user_msgid("SendAudio"), "message__SendAudio");

	set_msg_block(get_user_msgid("Radar"), BLOCK_SET);

	// g_iSyncHudSpawn = CreateHudSyncObj();
	g_iSyncHudDamage = CreateHudSyncObj();
}

public OnConfigsExecuted()
{
	server_cmd("exec addons/amxmodx/configs/re_csdm_amxx.cfg");
	server_cmd("sv_restart 1");
}

loadSpawns()
{
	g_iSpawnCount = 0;

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
	SetPlayerBit(g_bConnected, id);
	ClearPlayerBit(g_bAlive, id);
	g_iMenuInfo[id] = 0;
	g_iPrimaryWeapons[id] = random(2);
	g_iPrimaryWeaponsEnt[id] = 0;
	g_iSecondaryWeapons[id] = random(2);
	g_iSecondaryWeaponsEnt[id] = 0;
	g_iDontShowTheMenuAgain[id] = 0;

	arrayset(g_iWeaponData[id], 0, structWeaponData);
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
public ConsoleCommand__Spawns(const id)
{
	if(~get_user_flags(id) & ADMIN_IMMUNITY)
		return PLUGIN_HANDLED;

	if(loadSpawns())
		console_print(id, "[CSDM] Spawns recargados: %d total", g_iSpawnCount);

	return PLUGIN_HANDLED;
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

public OnHam__PlayerTraceAttack( const victim, const attacker, const Float:damage, const Float:direction[3], const tracehandle, const damage_type )
{
	if(victim == attacker || !IsConnected(attacker))
		return HAM_IGNORED;

	if(g_iCSDM_OnlyHead)
	{
		static iHitGroup;
		iHitGroup = get_tr2(tracehandle, TR_iHitgroup);

		if(iHitGroup != HIT_HEAD)
		{
			if(GetCurrentWeapon(attacker) == WEAPON_KNIFE)
			{
				set_hudmessage(255, 255, 0, -1.0, 0.57, 0, 0.0, 1.0, 0.0, 0.4, 2);
				ShowSyncHudMsg(attacker, g_iSyncHudDamage, "¡APUNTA A LA CABEZA!");
			}

			return HAM_SUPERCEDE;
		}
	}

	return HAM_IGNORED;
}

public OnHam__PlayerKilled( const victim, const killer, const shouldgib )
{
	ClearPlayerBit(g_bAlive, victim);

	arrayset(g_iWeaponData[victim], 0, structWeaponData);

	new WeaponIdType:iWid;

	if( PRIMARY_WEAPONS[g_iPrimaryWeapons[victim]][weaponSilenced] )
	{
		iWid = PRIMARY_WEAPONS[g_iPrimaryWeapons[victim]][weaponId];

		if(user_has_weapon(victim, _:iWid) && is_valid_ent(g_iPrimaryWeaponsEnt[victim]))
		{
			switch( iWid )
			{
				case CSW_M4A1: g_iWeaponData[victim][weaponM4A1] = cs_get_weapon_silen(g_iPrimaryWeaponsEnt[victim]);
				case CSW_FAMAS: g_iWeaponData[victim][weaponFAMAS] = cs_get_weapon_burst(g_iPrimaryWeaponsEnt[victim]);
			}
		}
	}

	if(SECONDARY_WEAPONS[g_iSecondaryWeapons[victim]][weaponSilenced])
	{
		iWid = SECONDARY_WEAPONS[g_iSecondaryWeapons[victim]][weaponId];

		if(user_has_weapon(victim, _:iWid) && is_valid_ent(g_iSecondaryWeaponsEnt[victim]))
		{
			switch( iWid )
			{
				case CSW_USP: g_iWeaponData[victim][weaponUSP] = cs_get_weapon_silen(g_iSecondaryWeaponsEnt[victim]);
				case CSW_GLOCK18: g_iWeaponData[victim][weaponGLOCK] = cs_get_weapon_burst(g_iSecondaryWeaponsEnt[victim]);
			}
		}
	}

	if(get_pdata_int(victim, 76) == DMG_FALL
	|| (IsConnected(killer) && (GetCurrentWeapon(killer) == WEAPON_AWP || GetCurrentWeapon(killer) == WEAPON_SCOUT) && get_pdata_int(victim, 75) == HIT_HEAD))
	{
		SetHamParamInteger(3, 2);
	}

	if(killer == victim || !IsConnected(killer))
		return HAM_IGNORED;

	if(GetPlayerBit(g_bAlive, killer))
	{
		set_user_armor(killer, 100);
		cs_set_user_armor(killer, 100, CS_ARMOR_VESTHELM);
	}

	if(g_iCSDM_MedicKit)
	{
		if(random_num(0, 14) <= 3)
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
			
			if(fFraction == 1.0)
			{
				dropEntForHumans(victim);
			}
		}
	}

	return HAM_IGNORED;
}

public OnHam__PlayerKilled_Post( const victim, const killer, const shouldgib )
{
	set_task(get_pcvar_float(g_pCvar__CSDM_TimeRespawn) + 0.5, "OnTaskRespawnPlayerCheck", victim);
}

public OnTaskRemoveWeapons(const id)
{
	if(!GetPlayerBit(g_bAlive, id))
		return;

	strip_user_weapons(id);
	rg_give_item(id, "weapon_knife");
}

public OnTaskShowMenuWeapons(const id)
{
	if(!GetPlayerBit(g_bAlive, id))
		return;

	if(g_iDontShowTheMenuAgain[id])
	{
		strip_user_weapons(id);
		
		giveWeapons(id, 1);
		giveWeapons(id, 2);
		giveWeapons(id, 3);

		rg_give_item(id, "weapon_knife");

		return;
	}

	new iMenuId = menu_create(fmt("\y%s : Equipamiento", g_sPluginName, g_sPluginAuthor), "menu__Equip");

	menu_additem(iMenuId, "Armas Nuevas");
	menu_additem(iMenuId, "Selección Anterior");
	menu_additem(iMenuId, "2 + No mostrar más el Menú");

	menu_addblank(iMenuId);
	menu_addtext(iMenuId, fmt("\wArma primaria\r:\y %s", PRIMARY_WEAPONS[g_iPrimaryWeapons[id]][weaponNames]));
	menu_addtext(iMenuId, fmt("\wArma secundaria\r:\y %s", SECONDARY_WEAPONS[g_iSecondaryWeapons[id]][weaponNames]));

	menu_setprop(iMenuId, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, iMenuId);
}

public menu__Equip(const id, const menuid, const itemid)
{
	menu_destroy(menuid);

	if(!GetPlayerBit(g_bAlive, id))
		return PLUGIN_HANDLED;

	switch(itemid)
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

showMenu__Weapons(const id, const weapons)
{
	if(!GetPlayerBit(g_bAlive, id))
		return;

	switch(weapons)
	{
		case 1: menu_display(id, g_iGlobalMenuOne, 0);
		case 2: menu_display(id, g_iGlobalMenuTwo, 0);
	}
}

public menu__PrimaryWeapons(const id, const menuid, const itemid)
{
	if(!GetPlayerBit(g_bAlive, id) || itemid == MENU_EXIT)
		return PLUGIN_HANDLED;

	g_iPrimaryWeapons[id] = itemid;
	giveWeapons(id, 1);
	giveWeapons(id, 3);

	return PLUGIN_HANDLED;
}

public menu__SecondaryWeapons(const id, const menuid, const itemid)
{
	if(!GetPlayerBit(g_bAlive, id) || itemid == MENU_EXIT)
		return PLUGIN_HANDLED;

	g_iSecondaryWeapons[id] = itemid;
	giveWeapons(id, 2);
	
	showMenu__Weapons(id, 1);
	return PLUGIN_HANDLED;
}

public giveWeapons(const id, const weapon)
{
	if(!GetPlayerBit(g_bAlive, id))
		return;

	switch(weapon)
	{
		case 1:
		{
			if( g_iPrimaryWeapons[id] < 0 || g_iPrimaryWeapons[id] >= sizeof(PRIMARY_WEAPONS) )
			{
				g_iPrimaryWeapons[id] = 0;
			}

			new WeaponIdType:iWid = PRIMARY_WEAPONS[g_iPrimaryWeapons[id]][weaponId];

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
								setAnimation(id, 5);
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

			new WeaponIdType:iWid = SECONDARY_WEAPONS[g_iSecondaryWeapons[id]][weaponId];

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
			if(g_bCSDM_Grenades & BIT_HEGRENADE)
				rg_give_item(id, "weapon_hegrenade");

			if(g_bCSDM_Grenades & BIT_FBGRENADE)
				rg_give_item(id, "weapon_flashbang");

			if(g_bCSDM_Grenades & BIT_SGGRENADE)
				rg_give_item(id, "weapon_smokegrenade");
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
	static szMsg[22];
	get_msg_arg_string(2, szMsg, charsmax(szMsg));
	
	if(equal(szMsg, "#Game_teammate_attack")
	|| equal(szMsg, "#Game_Commencing")
	|| equal(szMsg, "#Game_will_restart_in")
	|| equal(szMsg, "#Hostages_Not_Rescued")
	|| equal(szMsg, "#Round_Draw")
	|| equal(szMsg, "#Terrorists_Win")
	|| equal(szMsg, "#CTs_Win"))
	{
		return PLUGIN_HANDLED;
	}

	// #Fire_in_the_hole
	if(get_msg_args() == 5 && (get_msg_argtype(5) == ARG_STRING))
	{
		get_msg_arg_string(5, szMsg, 21);

		if(equal(szMsg, "#Fire_in_the_hole"))
			return PLUGIN_HANDLED;
	}
	else if(get_msg_args() == 6 && (get_msg_argtype(6) == ARG_STRING))
	{
		get_msg_arg_string(6, szMsg, 21);
		
		if(equal(szMsg, "#Fire_in_the_hole"))
			return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public message__SendAudio(const msgId, const destId, const id)
{
	static szAudio[19];
	get_msg_arg_string(2, szAudio, charsmax(szAudio));

	if(equal(szAudio, "%!MRAD_ctwin")
	|| equal(szAudio, "%!MRAD_terwin")
	|| equal(szAudio, "%!MRAD_rounddraw")
	|| equal(szAudio, "%!MRAD_FIREINHOLE")
	|| equal(szAudio, "%!MRAD_BOMBPL")
	|| equal(szAudio, "%!MRAD_BOMBDEF")
	|| equal(szAudio, "%!MRAD_rescued"))
	{
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

	for(i = 1; i <= MAX_CLIENTS; ++i)
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

WeaponIdType:GetCurrentWeapon(const id)
{
	return WeaponIdType:get_member(get_member(id, m_pActiveItem), m_iId);
}

stock UTIL_RegisterClientCommandAll(const command[], function[], flags = -1, const info[] = "", FlagManager = -1, bool:info_ml = false)
{
	register_clcmd(fmt("say %s", command), function, flags, info, FlagManager, info_ml);
	register_clcmd(fmt("say /%s", command), function, flags, info, FlagManager, info_ml);
	register_clcmd(fmt("say !%s", command), function, flags, info, FlagManager, info_ml);
	register_clcmd(fmt("say .%s", command), function, flags, info, FlagManager, info_ml);

	register_clcmd(fmt("say_team %s", command), function, flags, info, FlagManager, info_ml);
	register_clcmd(fmt("say_team /%s", command), function, flags, info, FlagManager, info_ml);
	register_clcmd(fmt("say_team !%s", command), function, flags, info, FlagManager, info_ml);
	register_clcmd(fmt("say_team .%s", command), function, flags, info, FlagManager, info_ml);
}