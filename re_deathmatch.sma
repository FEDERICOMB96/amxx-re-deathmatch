#include <amxmodx>
#include <reapi>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <xs>

/* ===========================================================================
* 				[ Initiation & Global stuff ]
* ============================================================================ */

new const g_szPluginName[]     = "DEATHMATCH";
new const g_szPluginVersion[]  = "v8";
new const g_szPluginAuthor[]   = "FEDERICOMB";
new const g_szGlobalPrefix[]   = "^4[DEATHMATCH]^1 ";

#define MAX_USERS              MAX_CLIENTS+1

new g_bConnected;
new g_bAlive;

new g_iMenuInfo[MAX_USERS];
new g_iPrimaryWeapons[MAX_USERS];
new g_iPrimaryWeaponsEnt[MAX_USERS];
new g_iSecondaryWeapons[MAX_USERS];
new g_iSecondaryWeaponsEnt[MAX_USERS];
new g_iDontShowTheMenuAgain[MAX_USERS];

enum _:structWeaponData
{
	weaponM4A1 = 0,
	weaponFAMAS,
	weaponUSP,
	weaponGLOCK
};
new g_iWeaponData[MAX_USERS][structWeaponData];

new g_iSyncHudDamage;
new g_iGlobalMenuOne;
new g_iGlobalMenuTwo;

new bool:g_bAllowRandomSpawns = true;

enum _:ArraySpawns_e
{
	TeamName:SpawnTeam,
	Float:SpawnOrigin[3],
	Float:SpawnAngles[3],
};
new Array:g_aSpawns;

new g_iCSDM_OnlyHead;
new g_iCSDM_MedicKit;
new g_iCSDM_FreeForAll;
new Float:g_flCSDM_ItemStaytime;

new g_Forward_Spawn;

enum _:e_StructWeapons
{
	WeaponIdType:weaponId,
	weaponEnt[54],
	weaponNames[32],
	bool:weaponSilenced
};

new const PRIMARY_WEAPONS[][e_StructWeapons] =
{
	{WEAPON_M4A1,       "weapon_m4a1",      "M4A1",                 true},
	{WEAPON_AK47,       "weapon_ak47",      "AK-47",                false},
	{WEAPON_AUG,        "weapon_aug",       "AUG",                  false},
	{WEAPON_SG552,      "weapon_sg552",     "SG-552",               false},
	{WEAPON_GALIL,      "weapon_galil",     "Galil",                false},
	{WEAPON_FAMAS,      "weapon_famas",     "Famas",                true},
	{WEAPON_SCOUT,      "weapon_scout",     "Scout",                false},
	{WEAPON_AWP,        "weapon_awp",       "AWP",                  false},
	{WEAPON_SG550,      "weapon_sg550",     "SG-550",               false},
	{WEAPON_M249,       "weapon_m249",      "M249",                 false},
	{WEAPON_G3SG1,      "weapon_g3sg1",     "G3-SG1",               false},
	{WEAPON_UMP45,      "weapon_ump45",     "UMP 45",               false},
	{WEAPON_MP5N,       "weapon_mp5navy",   "MP5 Navy",             false},
	{WEAPON_M3,         "weapon_m3",        "M3",                   false},
	{WEAPON_XM1014,     "weapon_xm1014",    "XM1014",               false},
	{WEAPON_TMP,        "weapon_tmp",       "TMP",                  false},
	{WEAPON_MAC10,      "weapon_mac10",     "Mac",                  false},
	{WEAPON_P90,        "weapon_p90",       "P90",                  false}
};

new const SECONDARY_WEAPONS[][e_StructWeapons] =
{
	{WEAPON_USP,        "weapon_usp",       "USP",                  true},
	{WEAPON_GLOCK18,    "weapon_glock18",   "Glock",                true},
	{WEAPON_DEAGLE,     "weapon_deagle",    "Deagle",               false},
	{WEAPON_P228,       "weapon_p228",      "P228",                 false},
	{WEAPON_ELITE,      "weapon_elite",     "Elite",                false},
	{WEAPON_FIVESEVEN,  "weapon_fiveseven", "Five SeveN",           false}
};

new const CLASSNAME_ENT_MEDKIT[]        = "entMedKit";

#define IsPlayer(%0)                    ( 1 <= %0 <= MAX_CLIENTS )

#define GetPlayerBit(%0,%1)             ( IsPlayer(%1) && ( %0 & ( 1 << ( %1 & 31 ) ) ) )
#define SetPlayerBit(%0,%1)             ( IsPlayer(%1) && ( %0 |= ( 1 << ( %1 & 31 ) ) ) )
#define ClearPlayerBit(%0,%1)           ( IsPlayer(%1) && ( %0 &= ~( 1 << ( %1 & 31 ) ) ) )
#define SwitchPlayerBit(%0,%1)          ( IsPlayer(%1) && ( %0 ^= ( 1 << ( %1 & 31 ) ) ) )

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

new const g_sModel_MedicKit[] = "models/w_medkit.mdl";
new const g_sSound_MedicKit[] = "items/smallmedkit1.wav";

/* =================================================================================
* 				[ Plugin events ]
* ================================================================================= */

public plugin_precache()
{
	new sBuffer[256];
	formatex(sBuffer, 63, "%s %s by FEDERICOMB", g_szPluginName, g_szPluginVersion);
	set_pcvar_string(create_cvar("dm_version", sBuffer, FCVAR_SERVER | FCVAR_SPONLY), sBuffer);
	set_pcvar_string(create_cvar("csdm_version", sBuffer, FCVAR_SERVER | FCVAR_SPONLY), sBuffer);
	set_pcvar_string(create_cvar("csdm_active", "1", FCVAR_SERVER | FCVAR_SPONLY), "1");

	g_Forward_Spawn = register_forward(FM_Spawn, "OnFw__Spawn");

	precache_model(g_sModel_MedicKit);
	precache_sound(g_sSound_MedicKit);
}

public plugin_init()
{
	register_plugin(g_szPluginName, g_szPluginVersion, g_szPluginAuthor);

	g_aSpawns = ArrayCreate(ArraySpawns_e);

	loadSpawns();
	loadMenus();

	bind_pcvar_num(create_cvar("csdm_only_head", "0"), g_iCSDM_OnlyHead);
	bind_pcvar_num(create_cvar("csdm_drop_medic", "0"), g_iCSDM_MedicKit);
	bind_pcvar_num(get_cvar_pointer("mp_freeforall"), g_iCSDM_FreeForAll);
	bind_pcvar_float(get_cvar_pointer("mp_item_staytime"), g_flCSDM_ItemStaytime);

	RegisterHookChain(RG_CBasePlayer_Spawn, "OnCBasePlayer_Spawn_Post", 1);
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "OnCBasePlayer_TraceAttack");
	RegisterHookChain(RG_CBasePlayer_Killed, "OnCBasePlayer_Killed");

	unregister_forward(FM_Spawn, g_Forward_Spawn);

	register_forward(FM_ClientKill, "OnFw__ClientKill");

	register_message(get_user_msgid("RoundTime"), "message__RoundTime");
	register_message(get_user_msgid("TextMsg"), "message__TextMsg");
	register_message(get_user_msgid("SendAudio"), "message__SendAudio");

	set_msg_block(get_user_msgid("Radar"), BLOCK_SET);

	UTIL_RegisterClientCommandAll("guns", "ClientCommand__Weapons");
	UTIL_RegisterClientCommandAll("armas", "ClientCommand__Weapons");

	g_iSyncHudDamage = CreateHudSyncObj();
}

public OnConfigsExecuted()
{
	server_cmd("exec dm_game.cfg");
	server_cmd("sv_restart 1");
}

public plugin_end()
{
	if(g_iGlobalMenuOne) menu_destroy(g_iGlobalMenuOne);
	if(g_iGlobalMenuTwo) menu_destroy(g_iGlobalMenuTwo);

	if(g_aSpawns != Invalid_Array) ArrayDestroy(g_aSpawns);
}

/* ===========================================================================
* 				[ Zone Events ]
* ============================================================================ */

loadSpawns()
{
	ArrayClear(g_aSpawns);

	new const SPAWN_NAME_ENTS[][] = { "info_player_start", "info_player_deathmatch" };

	for(new i = 0, iEnt, aSpawn[ArraySpawns_e]; i < sizeof(SPAWN_NAME_ENTS); ++i)
	{
		iEnt = MAX_CLIENTS;
		while((iEnt = rg_find_ent_by_class(iEnt, SPAWN_NAME_ENTS[i])) > 0)
		{
			get_entvar(iEnt, var_origin, aSpawn[SpawnOrigin]);
			get_entvar(iEnt, var_angles, aSpawn[SpawnAngles]);

			aSpawn[SpawnTeam] = (!i) ? TEAM_CT : TEAM_TERRORIST;

			ArrayPushArray(g_aSpawns, aSpawn);
		}
	}

	new iCount = ArraySize(g_aSpawns);
	server_print("[CSDM] Spawns cargados: %d", iCount);
	return iCount;
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
	ClearPlayerBit(g_bConnected, id);
	ClearPlayerBit(g_bAlive, id);
}

public OnCBasePlayer_Spawn_Post(const this)
{
	if(!is_user_alive(this))
		return;
	
	SetPlayerBit(g_bAlive, this);

	if(g_iCSDM_FreeForAll && GetUserTeam(this) != TEAM_TERRORIST)
		rg_set_user_team(this, TEAM_TERRORIST);

	randomSpawn(this);

	OnTaskShowMenuWeapons(this);

	set_member(this, m_iHideHUD, get_member(this, m_iHideHUD) | HIDEHUD_MONEY);
}

public OnCBasePlayer_TraceAttack(const this, pevAttacker, Float:flDamage, Float:vecDir[3], tracehandle, bitsDamageType)
{
	if(this == pevAttacker || !IsConnected(pevAttacker))
		return HC_CONTINUE;

	if(g_iCSDM_OnlyHead)
	{
		static iHitGroup;
		iHitGroup = get_tr2(tracehandle, TR_iHitgroup);

		if(iHitGroup != HIT_HEAD)
		{
			set_hudmessage(255, 255, 0, -1.0, 0.57, 0, 0.0, 1.0, 0.0, 0.4, 2);
			ShowSyncHudMsg(pevAttacker, g_iSyncHudDamage, "¡APUNTA A LA CABEZA!");

			return HC_SUPERCEDE;
		}
	}

	return HC_CONTINUE;
}

public OnCBasePlayer_Killed(const this, pevAttacker, iGib)
{
	ClearPlayerBit(g_bAlive, this);

	arrayset(g_iWeaponData[this], 0, structWeaponData);

	new WeaponIdType:iWid;

	if( PRIMARY_WEAPONS[g_iPrimaryWeapons[this]][weaponSilenced] )
	{
		iWid = PRIMARY_WEAPONS[g_iPrimaryWeapons[this]][weaponId];

		if(user_has_weapon(this, _:iWid) && !is_nullent(g_iPrimaryWeaponsEnt[this]))
		{
			switch(iWid)
			{
				case CSW_M4A1: g_iWeaponData[this][weaponM4A1] = GetWeaponSilen(g_iPrimaryWeaponsEnt[this]);
				case CSW_FAMAS: g_iWeaponData[this][weaponFAMAS] = GetWeaponBurst(g_iPrimaryWeaponsEnt[this]);
			}
		}
	}

	if(SECONDARY_WEAPONS[g_iSecondaryWeapons[this]][weaponSilenced])
	{
		iWid = SECONDARY_WEAPONS[g_iSecondaryWeapons[this]][weaponId];

		if(user_has_weapon(this, _:iWid) && !is_nullent(g_iSecondaryWeaponsEnt[this]))
		{
			switch(iWid)
			{
				case CSW_USP: g_iWeaponData[this][weaponUSP] = GetWeaponSilen(g_iSecondaryWeaponsEnt[this]);
				case CSW_GLOCK18: g_iWeaponData[this][weaponGLOCK] = GetWeaponBurst(g_iSecondaryWeaponsEnt[this]);
			}
		}
	}

	if(get_member(this, m_bitsDamageType) & DMG_FALL
	|| (IsConnected(pevAttacker) && (GetCurrentWeapon(pevAttacker) == WEAPON_AWP || GetCurrentWeapon(pevAttacker) == WEAPON_SCOUT) && get_member(this, m_LastHitGroup) == HIT_HEAD))
	{
		SetHookChainArg(3, ATYPE_INTEGER, 2);
	}

	if(pevAttacker == this || !IsConnected(pevAttacker))
		return HC_CONTINUE;

	if(GetPlayerBit(g_bAlive, pevAttacker))
		cs_set_user_armor(pevAttacker, 100, CS_ARMOR_VESTHELM);

	if(g_iCSDM_MedicKit)
	{
		new Float:vecOrigin[3];
		new Float:vecEndOrigin[3];
		new Float:flFraction;
		
		get_entvar(this, var_origin, vecOrigin);
		GetDropOrigin(this, vecEndOrigin, 20);
		
		engfunc(EngFunc_TraceLine, vecOrigin, vecEndOrigin, IGNORE_MONSTERS, this, 0);
		
		get_tr2(0, TR_flFraction, flFraction);
		
		if(flFraction == 1.0)
			DropMedKit(this);
	}

	return HC_CONTINUE;
}

public OnFw__Spawn(const entity)
{
	if(is_nullent(entity))
		return FMRES_IGNORED;

	new szClassName[32];
	get_entvar(entity, var_classname, szClassName, charsmax(szClassName));

	for(new i = 0; i < sizeof(OBJECTIVES_ENTITIES); ++i)
	{
		if(equal(szClassName, OBJECTIVES_ENTITIES[i]))
		{
			remove_entity(entity);
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public OnFw__ClientKill()
{
	return FMRES_SUPERCEDE;
}

public message__RoundTime(const msgId, const destId, const id)
{
	set_msg_arg_int(1, ARG_SHORT, get_timeleft());
}

public message__TextMsg(const msgId, const destId, const id)
{
	static szMsg[22];
	get_msg_arg_string(2, szMsg, charsmax(szMsg));

	for(new i = 0; i < sizeof(TXTMSG_BLOCK); ++i)
	{
		if(equal(szMsg, TXTMSG_BLOCK[i]))
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

	for(new i = 0; i < sizeof(SENDAUDIO_BLOCK); ++i)
	{
		if(equal(szAudio, SENDAUDIO_BLOCK[i]))
			return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

/* ===========================================================================
* 				[ Client Menus ]
* ============================================================================ */

loadMenus()
{
	// Primary Weapons
	{
		g_iGlobalMenuOne = menu_create(fmt("\y%s :\w Armas primarias\R\y", g_szPluginName), "menu__PrimaryWeapons");

		for(new i = 0; i < sizeof(PRIMARY_WEAPONS); ++i)
			menu_additem(g_iGlobalMenuOne, PRIMARY_WEAPONS[i][weaponNames]);

		menu_setprop(g_iGlobalMenuOne, MPROP_NEXTNAME, "Página siguiente");
		menu_setprop(g_iGlobalMenuOne, MPROP_BACKNAME, "Página anterior");
		menu_setprop(g_iGlobalMenuOne, MPROP_EXITNAME, "Salir");
	}

	// Secondary Weapons
	{
		g_iGlobalMenuTwo = menu_create(fmt("\y%s :\w Armas secundarias\R\y", g_szPluginName), "menu__SecondaryWeapons");

		for(new i = 0; i < sizeof(SECONDARY_WEAPONS); ++i)
			menu_additem(g_iGlobalMenuTwo, SECONDARY_WEAPONS[i][weaponNames]);

		menu_setprop(g_iGlobalMenuTwo, MPROP_NEXTNAME, "Página siguiente");
		menu_setprop(g_iGlobalMenuTwo, MPROP_BACKNAME, "Página anterior");
		menu_setprop(g_iGlobalMenuTwo, MPROP_EXITNAME, "Salir");
	}
}

public OnTaskShowMenuWeapons(const id)
{
	if(!GetPlayerBit(g_bAlive, id))
		return;

	if(g_iDontShowTheMenuAgain[id])
	{
		giveWeapons(id, 1);
		giveWeapons(id, 2);

		return;
	}

	new iMenuId = menu_create(fmt("\y%s : Equipamiento", g_szPluginName, g_szPluginAuthor), "menu__Equip");

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
		}

		case 2:
		{
			g_iDontShowTheMenuAgain[id] = 1;

			giveWeapons(id, 1);
			giveWeapons(id, 2);

			client_print_color(id, print_team_default, "%sEscribe^4 guns^1 para activar nuevamente el menú de armamento", g_szGlobalPrefix);
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
			new WeaponIdType:iWid = PRIMARY_WEAPONS[g_iPrimaryWeapons[id]][weaponId];

			g_iPrimaryWeaponsEnt[id] = rg_give_item(id, PRIMARY_WEAPONS[g_iPrimaryWeapons[id]][weaponEnt]);

			if((iWid == WEAPON_M4A1 || iWid == WEAPON_FAMAS) && !is_nullent(g_iPrimaryWeaponsEnt[id]))
			{
				switch(iWid)
				{
					case WEAPON_M4A1:
					{
						cs_set_weapon_silen(g_iPrimaryWeaponsEnt[id], g_iWeaponData[id][weaponM4A1], 0);

						if(g_iWeaponData[id][weaponM4A1])
							setAnimation(id, 5);
					}
					case WEAPON_FAMAS: cs_set_weapon_burst(g_iPrimaryWeaponsEnt[id], g_iWeaponData[id][weaponFAMAS]);
				}
			}
		}

		case 2:
		{
			new WeaponIdType:iWid = SECONDARY_WEAPONS[g_iSecondaryWeapons[id]][weaponId];

			g_iSecondaryWeaponsEnt[id] = rg_give_item(id, SECONDARY_WEAPONS[g_iSecondaryWeapons[id]][weaponEnt]);

			if((iWid == WEAPON_USP || iWid == WEAPON_GLOCK18) && !is_nullent(g_iSecondaryWeaponsEnt[id]))
			{
				switch(iWid)
				{
					case CSW_USP: cs_set_weapon_silen(g_iSecondaryWeaponsEnt[id], g_iWeaponData[id][weaponUSP], 0);
					case CSW_GLOCK18: cs_set_weapon_burst(g_iSecondaryWeaponsEnt[id], g_iWeaponData[id][weaponGLOCK]);
				}
			}
		}
	}
}

/* ===========================================================================
* 				[ Client Commands ]
* ============================================================================ */

public ClientCommand__Weapons(const id)
{
	if(!g_iDontShowTheMenuAgain[id])
	{
		OnTaskShowMenuWeapons(id);
		return PLUGIN_HANDLED;
	}

	g_iDontShowTheMenuAgain[id] = 0;
	client_print_color(id, print_team_default, "%sEn tu próxima regeneración podrás seleccionar nuevas armas!", g_szGlobalPrefix);

	return PLUGIN_HANDLED;
}

/* ===========================================================================
* 				[ Util Stuff ]
* ============================================================================ */

public randomSpawn(const id)
{
	new iArraySize = ArraySize(g_aSpawns);
	if(iArraySize < 1)
		return;

	new iHull = (get_entvar(id, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
	new iSpawnId = random_num(0, iArraySize - 1);
	new TeamName:iTeam = GetUserTeam(id);
	new iCount = 0;
	new iSpawnPass = 0;
	new iFinal = -1;
	new i;

	new Float:vecOriginPlayer[MAX_USERS][3];
	new Float:vecTemp[3];

	new aSpawns[ArraySpawns_e];

	for(i = 1; i <= MAX_CLIENTS; ++i)
	{
		if(!GetPlayerBit(g_bAlive, i) || i == id || (!g_iCSDM_FreeForAll && iTeam == GetUserTeam(i)))
			continue;

		get_entvar(i, var_origin, vecOriginPlayer[iCount++]);
	}

	while(iSpawnPass <= iArraySize)
	{
		if(iSpawnPass == iArraySize) // Paso por todos los spawns?
			break;

		if(++iSpawnId >= iArraySize)
			iSpawnId = 0;

		++iSpawnPass;

		ArrayGetArray(g_aSpawns, iSpawnId, aSpawns);

		if(!g_iCSDM_FreeForAll && !g_bAllowRandomSpawns && iTeam != aSpawns[SpawnTeam])
			continue;

		iFinal = iSpawnId;
		xs_vec_copy(aSpawns[SpawnOrigin], vecTemp);

		for(i = 0; i < iCount; ++i)
		{
			if(get_distance_f(vecTemp, vecOriginPlayer[i]) < 500.0)
			{
				iFinal = -1;
				break;
			}
		}

		if(iFinal == -1)
			continue;

		ArrayGetArray(g_aSpawns, iFinal, aSpawns);
		xs_vec_copy(aSpawns[SpawnOrigin], vecTemp);

		if(!IsHullVacant(vecTemp, iHull))
			continue;

		if(iCount < 1)
			break;

		if(iFinal != -1)
			break;
	}

	if(iFinal != -1)
	{
		ArrayGetArray(g_aSpawns, iFinal, aSpawns);

		set_entvar(id, var_fixangle, 1);
		set_entvar(id, var_angles, aSpawns[SpawnAngles]);
		set_entvar(id, var_fixangle, 1);
		
		set_entvar(id, var_origin, aSpawns[SpawnOrigin]);
	}

	set_task(0.25, "checkStuck", id);
}

public checkStuck(const id)
{
	if(GetPlayerBit(g_bAlive, id) && IsUserStuck(id))
		randomSpawn(id);
}

bool:IsHullVacant(const Float:origin[3], const hull)
{
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, 0, 0);
	
	if(!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid) && get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

bool:IsUserStuck(const id)
{
	new Float:vecOrigin[3];
	get_entvar(id, var_origin, vecOrigin);
	
	engfunc(EngFunc_TraceHull, vecOrigin, vecOrigin, 0, (get_entvar(id, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN, id, 0);
	
	if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true;
	
	return false;
}

public TeamName:GetUserTeam(const id)
{
	return TeamName:get_member(id, m_iTeam);
}

setAnimation(const id, const animation)
{
	set_entvar(id, var_weaponanim, animation);
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, _, id);
	write_byte(animation);
	write_byte(get_entvar(id, var_body));
	message_end();
}

DropMedKit(const id)
{
	new iEnt = rg_create_entity("info_target");
	
	if(!is_nullent(iEnt))
	{
		new Float:vecVelocity[3];
		new Float:vecOrigin[3];
		
		set_entvar(iEnt, var_classname, CLASSNAME_ENT_MEDKIT);
		entity_set_model(iEnt, g_sModel_MedicKit);
		entity_set_size(iEnt, Float:{-23.16, -13.66, 0.0}, Float:{11.47, 12.78, 6.72});
		
		set_entvar(iEnt, var_solid, SOLID_TRIGGER);
		set_entvar(iEnt, var_movetype, MOVETYPE_TOSS);
		set_entvar(iEnt, var_rendermode, kRenderNormal);
		set_entvar(iEnt, var_renderfx, kRenderFxNone);
		
		velocity_by_aim(id, 300, vecVelocity);
		GetDropOrigin(id, vecOrigin);
		set_entvar(iEnt, var_origin, vecOrigin);
		set_entvar(iEnt, var_velocity, vecVelocity);
		
		set_entvar(iEnt, var_renderamt, 255.0);
		set_entvar(iEnt, var_takedamage, DAMAGE_NO);

		SetTouch(iEnt, "OnTouch_MedicKit");
		SetThink(iEnt, "OnThink_MedicKit");

		set_entvar(iEnt, var_nextthink, get_gametime() + g_flCSDM_ItemStaytime);
	}
}

public OnTouch_MedicKit(const medickit, const id)
{
	if(is_nullent(medickit) || !IsAlive(id))
		return;

	new Float:flHealth = Float:get_entvar(id, var_health);

	if(flHealth < 100.0)
	{
		set_entvar(id, var_health, floatmin((flHealth + 15.0), 100.0));
		
		rh_emit_sound2(id, 0, CHAN_ITEM, g_sSound_MedicKit);
		
		SetTouch(medickit, "");
		SetThink(medickit, "");

		set_entvar(medickit, var_modelindex, 0);
		set_entvar(medickit, var_solid, SOLID_NOT);
		set_entvar(medickit, var_flags, FL_KILLME);
	}
}

public OnThink_MedicKit(const medickit)
{
	if(is_nullent(medickit))
		return;

	static Float:flRenderAmt;
	flRenderAmt = Float:get_entvar(medickit, var_renderamt);
	
	if(flRenderAmt == 255.0)
	{
		set_entvar(medickit, var_solid, SOLID_NOT);
		set_entvar(medickit, var_movetype, MOVETYPE_FLY);
		set_entvar(medickit, var_rendermode, kRenderTransAlpha);
		
		set_entvar(medickit, var_velocity, Float:{0.0, 0.0, 20.0});
		set_entvar(medickit, var_avelocity, Float:{0.0, 120.0, 0.0});
		
		set_entvar(medickit, var_renderamt, flRenderAmt - 15.0);
		set_entvar(medickit, var_nextthink, get_gametime() + 0.01);
		
		return;
	}
	
	flRenderAmt -= 15.0;
	
	if(flRenderAmt < 0.0)
	{
		SetTouch(medickit, "");
		SetThink(medickit, "");

		set_entvar(medickit, var_modelindex, 0);
		set_entvar(medickit, var_solid, SOLID_NOT);
		set_entvar(medickit, var_flags, FL_KILLME);
		return;
	}
	
	set_entvar(medickit, var_renderamt, flRenderAmt);
	set_entvar(medickit, var_nextthink, get_gametime() + 0.1);
}

GetDropOrigin(const id, Float:vecOrigin[3], iVelAdd = 0)
{
	new Float:vecAim[3];
	new Float:vecViewOfs[3];
	
	get_entvar(id, var_view_ofs, vecViewOfs);
	get_entvar(id, var_origin, vecOrigin);
	xs_vec_add(vecOrigin, vecViewOfs, vecOrigin);
	
	velocity_by_aim(id, 50 + iVelAdd, vecAim);
	
	vecOrigin[0] += vecAim[0];
	vecOrigin[1] += vecAim[1];
}

WeaponIdType:GetCurrentWeapon(const id)
{
	return WeaponIdType:get_member(get_member(id, m_pActiveItem), m_iId);
}

bool:GetWeaponBurst(const pWeapon)
{
	switch(WeaponIdType:get_member(pWeapon, m_iId))
	{
		case WEAPON_GLOCK18: return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_GLOCK18_BURST_MODE);
		case WEAPON_FAMAS:   return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_FAMAS_BURST_MODE);
	}

	return false;
}

bool:GetWeaponSilen(const pWeapon)
{
	switch(WeaponIdType:get_member(pWeapon, m_iId))
	{
		case WEAPON_M4A1: return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_M4A1_SILENCED);
		case WEAPON_USP:  return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_USP_SILENCED);
	}

	return false;
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