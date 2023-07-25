#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <json>
#include <xs>
#include "include/re_dm/dm_global"
#include "include/re_dm/dm_utils"
#include "include/re_dm/dm_weapons"

/* =================================================================================
* 				[ Plugin events ]
* ================================================================================= */

public plugin_precache()
{
	new sBuffer[256];
	formatex(sBuffer, 63, "%s %s by FEDERICOMB", PLUGIN_NAME, PLUGIN_VERSION);
	set_pcvar_string(create_cvar("dm_version", sBuffer, FCVAR_SERVER | FCVAR_SPONLY), sBuffer);
	set_pcvar_string(create_cvar("dm_url", PLUGIN_URL, FCVAR_SERVER | FCVAR_SPONLY), PLUGIN_URL);
	set_pcvar_string(create_cvar("csdm_version", sBuffer, FCVAR_SERVER | FCVAR_SPONLY), sBuffer);
	set_pcvar_string(create_cvar("csdm_active", "1", FCVAR_SERVER | FCVAR_SPONLY), "1");

	g_Forward_Spawn = register_forward(FM_Spawn, "OnFw__Spawn");

	precache_model(g_szModel_MedicKit);
	precache_sound(g_szSound_MedicKit);
	precache_sound(g_szSound_KillDing);
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR, PLUGIN_URL);

	g_aSpawns = ArrayCreate(ArraySpawns_e, 1);
	g_aPrimaryWeapons = ArrayCreate(WeaponStruct_e, 1);
	g_aSecondaryWeapons = ArrayCreate(WeaponStruct_e, 1);

	loadSpawns();
	WeaponsInit();

	bind_pcvar_num(create_cvar("csdm_only_head", "0"), g_iCSDM_OnlyHead);
	bind_pcvar_num(create_cvar("csdm_drop_medic", "0"), g_iCSDM_MedicKit);
	bind_pcvar_num(create_cvar("csdm_refill_armor_on_kill", "1"), g_iCSDM_RefillArmorOnKill);
	bind_pcvar_num(create_cvar("csdm_kill_ding_sound", "1"), g_iCSDM_KillDingSound);
	bind_pcvar_num(create_cvar("csdm_screenfade_on_kill", "1"), g_iCSDM_ScreenFadeOnKill);
	bind_pcvar_num(create_cvar("csdm_instant_reload_weapons_on_kill", "1"), g_iCSDM_InstantReloadWeaponsOnKill);
	bind_pcvar_num(create_cvar("csdm_block_kill_command", "1"), g_iCSDM_BlockKillCommand);
	bind_pcvar_num(create_cvar("csdm_block_spawn_sounds", "1"), g_iCSDM_BlockSpawnSounds);
	bind_pcvar_num(create_cvar("csdm_block_drop", "0"), g_iCSDM_BlockDrop);
	bind_pcvar_num(get_cvar_pointer("mp_freeforall"), g_iCSDM_FreeForAll);
	bind_pcvar_float(get_cvar_pointer("mp_item_staytime"), g_flCSDM_ItemStaytime);

	RegisterHookChain(RH_SV_StartSound, "OnRH_SV_StartSound", 0);
	RegisterHookChain(RG_CBasePlayer_Spawn, "OnCBasePlayer_Spawn_Post", 1);
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "OnCBasePlayer_TraceAttack", 0);
	RegisterHookChain(RG_CBasePlayer_Killed, "OnCBasePlayer_Killed", 0);
	RegisterHookChain(RG_CBasePlayer_Killed, "OnCBasePlayer_Killed_Post", 1);

	unregister_forward(FM_Spawn, g_Forward_Spawn);

	register_forward(FM_ClientKill, "OnFw__ClientKill");

	g_iMsgScreenFade = get_user_msgid("ScreenFade");
	register_message(get_user_msgid("RoundTime"), "message__RoundTime");
	register_message(get_user_msgid("TextMsg"), "message__TextMsg");
	register_message(get_user_msgid("SendAudio"), "message__SendAudio");

	set_msg_block(get_user_msgid("Radar"), BLOCK_SET);

	register_clcmd("drop", "ClientCommand__Drop");
	UTIL_RegisterClientCommandAll("manage", "ClientCommand__Manage");
	UTIL_RegisterClientCommandAll("configurar", "ClientCommand__Manage");
	UTIL_RegisterClientCommandAll("guns", "ClientCommand__Weapons");
	UTIL_RegisterClientCommandAll("armas", "ClientCommand__Weapons");

	g_iSyncHudDamage = CreateHudSyncObj();

	register_dictionary("re_dm.txt");
}

public OnConfigsExecuted()
{
	server_cmd("exec dm_game.cfg");
	server_cmd("sv_restart 1");
}

public plugin_end()
{
	if(g_aSpawns != Invalid_Array) ArrayDestroy(g_aSpawns);
	if(g_aPrimaryWeapons != Invalid_Array) ArrayDestroy(g_aPrimaryWeapons);
	if(g_aSecondaryWeapons != Invalid_Array) ArrayDestroy(g_aSecondaryWeapons);
}

/* ===========================================================================
* 				[ Zone Events ]
* ============================================================================ */

loadSpawns()
{
	ArrayClear(g_aSpawns);

	new szMap[64], szFileName[PLATFORM_MAX_PATH];
	get_localinfo("amxx_datadir", szFileName, PLATFORM_MAX_PATH-1);
	get_mapname(szMap, charsmax(szMap)); mb_strtolower(szMap);
	add(szFileName, PLATFORM_MAX_PATH-1, fmt("/re_dm/%s.dat", szMap));

	new JSON:jSpawnsFile = json_parse(szFileName, true, false);
	if(jSpawnsFile != Invalid_JSON)
	{
		new JSON:jSchema = json_parse("{^"random_spawn^":false,^"spawns^":[{^"team^":0,^"origin^":^"^",^"angles^":^"^"}]}", false, false);

		if(json_validate(jSchema, jSpawnsFile))
		{
			g_bAllowRandomSpawns = json_object_get_bool(jSpawnsFile, "random_spawn");

			new JSON:jArraySpawns = json_object_get_value(jSpawnsFile, "spawns");
			for(new i = 0, aSpawn[ArraySpawns_e], szBuffer[21], szParse[3][7],
				JSON:jArrayValue, iCount = json_array_get_count(jArraySpawns); i < iCount; ++i)
			{
				jArrayValue = json_array_get_value(jArraySpawns, i);

				aSpawn[SpawnTeam] = TeamName:json_object_get_number(jArrayValue, "team");

				json_object_get_string(jArrayValue, "origin", szBuffer, charsmax(szBuffer));
				parse(szBuffer, szParse[0], charsmax(szParse[]), szParse[1], charsmax(szParse[]), szParse[2], charsmax(szParse[]));

				aSpawn[SpawnOrigin][0] = str_to_float(szParse[0]);
				aSpawn[SpawnOrigin][1] = str_to_float(szParse[1]);
				aSpawn[SpawnOrigin][2] = str_to_float(szParse[2]);

				json_object_get_string(jArrayValue, "angles", szBuffer, charsmax(szBuffer));
				parse(szBuffer, szParse[0], charsmax(szParse[]), szParse[1], charsmax(szParse[]), szParse[2], charsmax(szParse[]));

				aSpawn[SpawnAngles][0] = str_to_float(szParse[0]);
				aSpawn[SpawnAngles][1] = str_to_float(szParse[1]);
				aSpawn[SpawnAngles][2] = str_to_float(szParse[2]);

				ArrayPushArray(g_aSpawns, aSpawn);

				json_free(jArrayValue);
			}

			json_free(jArraySpawns);
		}

		json_free(jSchema);
		json_free(jSpawnsFile);
	}

	if(ArraySize(g_aSpawns) < 1)
	{
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
	}

	new iCount = ArraySize(g_aSpawns);
	server_print("[ReDM] %L", LANG_SERVER, "SERVER_INFO_SPAWNS_LOADED", iCount);
	return iCount;
}

public client_putinserver(id)
{
	SetPlayerBit(g_bConnected, id);
	ClearPlayerBit(g_bAlive, id);
	g_iPrimaryWeapons[id] = random(2);
	g_iSecondaryWeapons[id] = random(2);
	g_iDontShowTheMenuAgain[id] = 0;
	g_iBuyItem[id] = 0;

	arrayset(g_iWeaponData[id], 0, sizeof(g_iWeaponData[]));
}

public client_disconnected(id)
{
	ClearPlayerBit(g_bConnected, id);
	ClearPlayerBit(g_bAlive, id);
}

public OnRH_SV_StartSound(const recipients, const entity, const channel, const sample[], const volume, Float:attenuation, const fFlags, const pitch)
{
	if(g_iCSDM_BlockSpawnSounds)
	{
		if(equal(sample, "items/gunpickup2.wav") || equal(sample, "items/ammopickup2.wav"))
			return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}

public OnCBasePlayer_Spawn_Post(const this)
{
	if(!is_user_alive(this))
		return;
	
	SetPlayerBit(g_bAlive, this);

	g_iBuyItem[this] = 0;

	if(g_iCSDM_FreeForAll && GetUserTeam(this) != TEAM_TERRORIST)
		rg_set_user_team(this, TEAM_TERRORIST);

	randomSpawn(this);

	rg_internal_cmd(this, "weapon_knife");
	ShowMenuWeapons(this);

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
			ShowSyncHudMsg(pevAttacker, g_iSyncHudDamage, "%L", LANG_PLAYER, "HUD_INFO_ONLYHEAD");

			return HC_SUPERCEDE;
		}
	}

	return HC_CONTINUE;
}

public OnCBasePlayer_Killed(const this, pevAttacker, iGib)
{
	ClearPlayerBit(g_bAlive, this);

	arrayset(g_iWeaponData[this], 0, sizeof(g_iWeaponData[]));
	
	new WeaponIdType:iWeapon = UTIL_GetCurrentWeapon(this);
	if(iWeapon == WEAPON_FAMAS || iWeapon == WEAPON_USP || iWeapon == WEAPON_GLOCK18 || iWeapon == WEAPON_M4A1)
	{
		new pActiveItem = get_member(this, m_pActiveItem);
		if(!is_nullent(pActiveItem))
		{
			switch(iWeapon)
			{
				case WEAPON_FAMAS: g_iWeaponData[this][WeaponDataFAMAS] = UTIL_GetWeaponBurst(pActiveItem);
				case WEAPON_USP: g_iWeaponData[this][WeaponDataUSP] = UTIL_GetWeaponSilen(pActiveItem);
				case WEAPON_GLOCK18: g_iWeaponData[this][WeaponDataGLOCK] = UTIL_GetWeaponBurst(pActiveItem);
				case WEAPON_M4A1: g_iWeaponData[this][WeaponDataM4A1] = UTIL_GetWeaponSilen(pActiveItem);
			}
		}
	}
	
	if(IsConnected(pevAttacker) && (UTIL_GetCurrentWeapon(pevAttacker) == WEAPON_AWP || UTIL_GetCurrentWeapon(pevAttacker) == WEAPON_SCOUT) && get_member(this, m_bHeadshotKilled))
		SetHookChainArg(3, ATYPE_INTEGER, 2);
		
	return HC_CONTINUE;
}

public OnCBasePlayer_Killed_Post(const this, pevAttacker, iGib)
{
	if(pevAttacker == this || !IsConnected(pevAttacker))
		return;

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

	if(g_iCSDM_KillDingSound)
		client_cmd(pevAttacker, "spk ^"%s^"", g_szSound_KillDing);
	
	if(IsAlive(pevAttacker))
	{
		if(g_iCSDM_ScreenFadeOnKill)
		{
			message_begin(MSG_ONE, g_iMsgScreenFade, _, pevAttacker);
			write_short((1<<12));
			write_short(0);
			write_short(0x0000);
			write_byte(200);
			write_byte(200);
			write_byte(200);
			write_byte(50);
			message_end();
		}

		if(g_iCSDM_RefillArmorOnKill)
			cs_set_user_armor(pevAttacker, 100, CS_ARMOR_VESTHELM);

		if(g_iCSDM_InstantReloadWeaponsOnKill)
			rg_instant_reload_weapons(pevAttacker);
	}
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
	return g_iCSDM_BlockKillCommand ? FMRES_SUPERCEDE : FMRES_IGNORED;
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

ShowMenuWeapons(const id, menuId = 0)
{
	if(!IsAlive(id))
		return;

	if(g_iDontShowTheMenuAgain[id])
	{
		GiveWeapons(id, BUY_SECONDARY_ITEM);
		GiveWeapons(id, BUY_PRIMARY_ITEM);

		return;
	}

	new iMenuId;

	if(menuId == BUY_PRIMARY_ITEM)
	{
		iMenuId = menu_create(fmt(
			"\y%s%s\d |\w %L\R\y", PLUGIN_NAME, g_iCSDM_FreeForAll ? " + FFA" : "", LANG_PLAYER, "MENU_TITLE_PRIMARY"), "menu__PrimaryWeapons");

		for(new i = 0, aWeapon[WeaponStruct_e], iMaxLoop = ArraySize(g_aPrimaryWeapons); i < iMaxLoop; ++i)
		{
			ArrayGetArray(g_aPrimaryWeapons, i, aWeapon);
			menu_additem(iMenuId, aWeapon[WeaponName]);
		}
	}
	else if(menuId == BUY_SECONDARY_ITEM)
	{
		iMenuId = menu_create(fmt(
			"\y%s%s\d |\w %L\R\y", PLUGIN_NAME, g_iCSDM_FreeForAll ? " + FFA" : "", LANG_PLAYER, "MENU_TITLE_SECONDARY"), "menu__SecondaryWeapons");

		for(new i = 0, aWeapon[WeaponStruct_e], iMaxLoop = ArraySize(g_aSecondaryWeapons); i < iMaxLoop; ++i)
		{
			ArrayGetArray(g_aSecondaryWeapons, i, aWeapon);
			menu_additem(iMenuId, aWeapon[WeaponName]);
		}
	}
	else
	{
		iMenuId = menu_create(fmt(
			"\y%s%s\d |\w %L", PLUGIN_NAME, g_iCSDM_FreeForAll ? " + FFA" : "", LANG_PLAYER, "MENU_TITLE_EQUIPMENT"),
		"menu__Equip");

		menu_additem(iMenuId, fmt("%L", LANG_PLAYER, "MENU_NEW_WEAPONS"));
		menu_additem(iMenuId, fmt("%L", LANG_PLAYER, "MENU_PREV_SELECTION"));
		menu_additem(iMenuId, fmt("%L", LANG_PLAYER, "MENU_PREV_DONT_SHOW_AGAIN"));

		menu_addblank(iMenuId);

		if(ArraySize(g_aPrimaryWeapons))
		{
			new aWeapon[WeaponStruct_e];
			ArrayGetArray(g_aPrimaryWeapons, g_iPrimaryWeapons[id], aWeapon);
			menu_addtext(iMenuId, fmt("%L\r:\y %s", LANG_PLAYER, "MENU_INFO_PRIMARY", aWeapon[WeaponName]));
		}

		if(ArraySize(g_aSecondaryWeapons))
		{
			new aWeapon[WeaponStruct_e];
			ArrayGetArray(g_aSecondaryWeapons, g_iSecondaryWeapons[id], aWeapon);
			menu_addtext(iMenuId, fmt("%L\r:\y %s", LANG_PLAYER, "MENU_INFO_SECONDARY", aWeapon[WeaponName]));
		}

		menu_setprop(iMenuId, MPROP_EXIT, MEXIT_NEVER);
	}

	menu_setprop(iMenuId, MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "MENU_OPT_NEXT"));
	menu_setprop(iMenuId, MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "MENU_OPT_BACK"));
	menu_setprop(iMenuId, MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "MENU_OPT_EXIT"));

	menu_display(id, iMenuId);
}

public menu__Equip(const id, const menuid, const itemid)
{
	menu_destroy(menuid);

	if(!IsAlive(id))
		return PLUGIN_HANDLED;

	switch(itemid)
	{
		case 0:
		{
			ArraySize(g_aSecondaryWeapons)
				? ShowMenuWeapons(id, BUY_SECONDARY_ITEM)
				: ShowMenuWeapons(id, BUY_PRIMARY_ITEM);
		}

		case 1:
		{
			GiveWeapons(id, BUY_SECONDARY_ITEM);
			GiveWeapons(id, BUY_PRIMARY_ITEM);
		}

		case 2:
		{
			g_iDontShowTheMenuAgain[id] = 1;

			GiveWeapons(id, BUY_SECONDARY_ITEM);
			GiveWeapons(id, BUY_PRIMARY_ITEM);

			client_print_color(id, print_team_default, "%s %L", g_szGlobalPrefix, LANG_PLAYER, "CHAT_TYPE_GUNS");
		}
	}

	return PLUGIN_HANDLED;
}

public menu__PrimaryWeapons(const id, const menuid, const itemid)
{
	menu_destroy(menuid);

	if(!IsAlive(id) || itemid == MENU_EXIT)
		return PLUGIN_HANDLED;

	g_iPrimaryWeapons[id] = itemid;
	GiveWeapons(id, BUY_PRIMARY_ITEM);

	return PLUGIN_HANDLED;
}

public menu__SecondaryWeapons(const id, const menuid, const itemid)
{
	menu_destroy(menuid);

	if(!IsAlive(id) || itemid == MENU_EXIT)
		return PLUGIN_HANDLED;

	g_iSecondaryWeapons[id] = itemid;
	GiveWeapons(id, BUY_SECONDARY_ITEM);
	
	if(ArraySize(g_aPrimaryWeapons))
		ShowMenuWeapons(id, BUY_PRIMARY_ITEM);

	return PLUGIN_HANDLED;
}

GiveWeapons(const id, const bWeaponType)
{
	if(!IsAlive(id))
		return;

	if(bWeaponType == BUY_PRIMARY_ITEM)
	{
		if((g_iBuyItem[id] & BUY_PRIMARY_ITEM) || (ArraySize(g_aPrimaryWeapons) < 1))
			return;

		new aPrimaryWeapon[WeaponStruct_e];
		ArrayGetArray(g_aPrimaryWeapons, g_iPrimaryWeapons[id], aPrimaryWeapon);
		
		new WeaponIdType:iWid = aPrimaryWeapon[WeaponId];
		new iWeaponEnt = rg_give_item(id, aPrimaryWeapon[WeaponEnt]);

		if((iWid == WEAPON_M4A1 || iWid == WEAPON_FAMAS) && !is_nullent(iWeaponEnt))
		{
			switch(iWid)
			{
				case WEAPON_M4A1:
				{
					cs_set_weapon_silen(iWeaponEnt, g_iWeaponData[id][WeaponDataM4A1], 0);

					if(g_iWeaponData[id][WeaponDataM4A1])
						UTIL_SetAnimation(id, 5);
				}
				case WEAPON_FAMAS: cs_set_weapon_burst(iWeaponEnt, g_iWeaponData[id][WeaponDataFAMAS]);
			}
		}

		rg_internal_cmd(id, aPrimaryWeapon[WeaponEnt]);
		g_iBuyItem[id] |= BUY_PRIMARY_ITEM;

		client_cmd(id, "spk items/gunpickup2.wav");
	}
	else if(bWeaponType == BUY_SECONDARY_ITEM)
	{
		if((g_iBuyItem[id] & BUY_SECONDARY_ITEM) || (ArraySize(g_aSecondaryWeapons) < 1))
			return;

		new aSecondaryWeapon[WeaponStruct_e];
		ArrayGetArray(g_aSecondaryWeapons, g_iSecondaryWeapons[id], aSecondaryWeapon);

		new WeaponIdType:iWid = aSecondaryWeapon[WeaponId];
		new iWeaponEnt = rg_give_item(id, aSecondaryWeapon[WeaponEnt]);

		if((iWid == WEAPON_USP || iWid == WEAPON_GLOCK18) && !is_nullent(iWeaponEnt))
		{
			switch(iWid)
			{
				case CSW_USP: cs_set_weapon_silen(iWeaponEnt, g_iWeaponData[id][WeaponDataUSP], 0);
				case CSW_GLOCK18: cs_set_weapon_burst(iWeaponEnt, g_iWeaponData[id][WeaponDataGLOCK]);
			}
		}

		rg_internal_cmd(id, aSecondaryWeapon[WeaponEnt]);
		g_iBuyItem[id] |= BUY_SECONDARY_ITEM;

		client_cmd(id, "spk items/gunpickup2.wav");
	}
}

ShowMenu_Management(const id)
{
	new iSpawnsCount = ArraySize(g_aSpawns);
	new iCt = 0, iT = 0;

	for(new i = 0, aSpawn[ArraySpawns_e]; i < iSpawnsCount; i++)
	{
		ArrayGetArray(g_aSpawns, i, aSpawn);

		if(aSpawn[SpawnTeam] == TEAM_CT)
			++iCt;
		else if(aSpawn[SpawnTeam] == TEAM_TERRORIST)
			++iT;
	}

	new iMenuId = menu_create(fmt("\y%s : %L^n\dCT: [ %d ] | T: [ %d ] | Total: [ %d ]", 
		PLUGIN_NAME, LANG_PLAYER, "MENU_TITLE_MANAGEMENT", iCt, iT, iSpawnsCount), "menu_Management");

	menu_additem(iMenuId, fmt("%L %L^n", LANG_PLAYER, "MENU_SPAWN_TYPE", id, g_bAllowRandomSpawns ? "MENU_SPAWN_TYPE_RANDOM" : "MENU_SPAWN_TYPE_TEAM"));
	
	menu_additem(iMenuId, fmt("%L", LANG_PLAYER, "MENU_SPAWN_CREATE_CT"));
	menu_additem(iMenuId, fmt("%L^n", LANG_PLAYER, "MENU_SPAWN_CREATE_TT"));

	menu_additem(iMenuId, fmt("%L^n", LANG_PLAYER, "MENU_SPAWN_SWITCH"));
	
	menu_additem(iMenuId, fmt("%L", LANG_PLAYER, "MENU_SPAWN_DELETE_AIM"));
	menu_additem(iMenuId, fmt("%L^n", LANG_PLAYER, "MENU_SPAWN_DELETE_ALL"));
	
	menu_additem(iMenuId, fmt("%L^n", LANG_PLAYER, "MENU_SPAWN_SAVE_ALL"));
	
	menu_additem(iMenuId, fmt("%L", LANG_PLAYER, "MENU_OPT_EXIT"));
	
	menu_setprop(iMenuId, MPROP_EXIT, MEXIT_NEVER);
	menu_setprop(iMenuId, MPROP_PERPAGE, 0);
	
	menu_display(id, iMenuId);
}

public menu_Management(const id, const menuid, const itemid)
{
	menu_destroy(menuid);

	if(!IsConnected(id) || itemid == MENU_EXIT || itemid > 6)
	{
		HideCustomSpawns();
		return PLUGIN_HANDLED;
	}

	switch(itemid)
	{
		case 0:
		{
			#emit LOAD.pri g_bAllowRandomSpawns
			#emit NOT
			#emit STOR.pri g_bAllowRandomSpawns
		}
		case 1, 2:
		{
			new aSpawn[ArraySpawns_e];

			get_entvar(id, var_origin, aSpawn[SpawnOrigin]);
			get_entvar(id, var_v_angle, aSpawn[SpawnAngles]);

			aSpawn[SpawnTeam] = (itemid == 1) ? TEAM_CT : TEAM_TERRORIST;

			ArrayPushArray(g_aSpawns, aSpawn);
		}
		case 3:
		{
			new iEnt = FindCustomSpawn(id);
			
			if(iEnt > 0)
			{
				new iItem = get_entvar(iEnt, var_iuser1);

				new aSpawn[ArraySpawns_e];
				ArrayGetArray(g_aSpawns, iItem, aSpawn);

				(aSpawn[SpawnTeam] == TEAM_TERRORIST)
					? (aSpawn[SpawnTeam] = TEAM_CT)
					: (aSpawn[SpawnTeam] = TEAM_TERRORIST);

				ArraySetArray(g_aSpawns, iItem, aSpawn);
			}
		}
		case 4:
		{
			new iEnt = FindCustomSpawn(id);
			
			if(iEnt > 0)
			{
				new iItem = get_entvar(iEnt, var_iuser1);
				
				set_entvar(iEnt, var_modelindex, 0);
				set_entvar(iEnt, var_flags, FL_KILLME);
				
				ArrayDeleteItem(g_aSpawns, iItem);
			}
		}
		case 5: ArrayClear(g_aSpawns);
		case 6: SaveMapData(id);
	}
	
	HideCustomSpawns();
	ShowCustomSpawns();
	
	ShowMenu_Management(id);
	return PLUGIN_HANDLED;
}

/* ===========================================================================
* 				[ Client Commands ]
* ============================================================================ */

public ClientCommand__Drop(const id)
{
	return g_iCSDM_BlockDrop ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public ClientCommand__Manage(const id)
{
	if(!IsConnected(id) || ~get_user_flags(id) & ADMIN_IMMUNITY)
		return PLUGIN_HANDLED;

	ShowCustomSpawns();
	
	ShowMenu_Management(id);
	return PLUGIN_HANDLED;
}

public ClientCommand__Weapons(const id)
{
	if(!IsConnected(id))
		return PLUGIN_HANDLED;

	if((~g_iBuyItem[id] & BUY_SECONDARY_ITEM) && ArraySize(g_aSecondaryWeapons))
	{
		ShowMenuWeapons(id, BUY_SECONDARY_ITEM);
		return PLUGIN_HANDLED;
	}
	else if((~g_iBuyItem[id] & BUY_PRIMARY_ITEM) && ArraySize(g_aPrimaryWeapons))
	{
		ShowMenuWeapons(id, BUY_PRIMARY_ITEM);
		return PLUGIN_HANDLED;
	}

	g_iDontShowTheMenuAgain[id] = 0;
	client_print_color(id, print_team_default, "%s %L", g_szGlobalPrefix, LANG_PLAYER, "CHAT_INFO_NEXT_REGEN");

	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Show Spawns While Editing ]
* ================================================================================= */

CreateCustomSpawn(const i, const TeamName:iTeam, const Float:vecOrigin[3], const Float:vecAngles[3])
{
	new iEnt = rg_create_entity(g_szInfoTargetClass);
	
	if(!is_valid_ent(iEnt))
		return 0;
	
	set_entvar(iEnt, var_classname, g_szCustomSpawnClass);
	
	entity_set_model(iEnt, g_szCustomSpawnModels[_:iTeam]);
	entity_set_size(iEnt, Float:{-16.0, -16.0, -36.0}, Float:{16.0, 16.0, 36.0});
	
	entity_set_origin(iEnt, vecOrigin);
	set_entvar(iEnt, var_angles, vecAngles);
	
	set_entvar(iEnt, var_solid, SOLID_TRIGGER);
	set_entvar(iEnt, var_movetype, MOVETYPE_FLY);
	
	set_entvar(iEnt, var_sequence, 1);
	set_entvar(iEnt, var_weaponanim, 1);
	
	set_entvar(iEnt, var_animtime, get_gametime());
	set_entvar(iEnt, var_framerate, 1.0);
	set_entvar(iEnt, var_frame, 0.0);
	
	set_entvar(iEnt, var_controller, 125, 0);
	set_entvar(iEnt, var_controller, 125, 1);
	set_entvar(iEnt, var_controller, 125, 2);
	set_entvar(iEnt, var_controller, 125, 3);

	set_entvar(iEnt, var_iuser1, i);
	
	return iEnt;
}

FindCustomSpawn(const id)
{
	new Float:vecOrigin[3];
	new Float:vecEnd[3];
	new Float:vecStart[3];
	new Float:vecViewOfs[3];
	new Float:vecAngles[3];

	get_entvar(id, var_origin, vecOrigin);
	get_entvar(id, var_view_ofs, vecViewOfs);
	get_entvar(id, var_v_angle, vecAngles);

	xs_vec_add(vecOrigin, vecViewOfs, vecStart);

	angle_vector(vecAngles, ANGLEVECTOR_FORWARD, vecAngles);

	xs_vec_mul_scalar(vecAngles, 2048.0, vecAngles);
	xs_vec_add(vecStart, vecAngles, vecEnd);

	new iEnt = 0;
	while((iEnt = rg_find_ent_by_class(iEnt, g_szCustomSpawnClass)) > 0)
	{
		engfunc(EngFunc_TraceModel, vecStart, vecEnd, HULL_POINT, iEnt, 0);
		
		if(get_tr2(0, TR_pHit) == iEnt)
			return iEnt;
	}

	return 0;
}

ShowCustomSpawns()
{
	if(g_bShowingSpawns)
		return;
	
	g_bShowingSpawns = true;

	for(new i = 0, Float:vecOrigin[3], Float:vecAngles[3],
		aSpawn[ArraySpawns_e], iSpawnsCount = ArraySize(g_aSpawns); i < iSpawnsCount; i++)
	{
		ArrayGetArray(g_aSpawns, i, aSpawn);
		
		xs_vec_copy(aSpawn[SpawnOrigin], vecOrigin);
		vecOrigin[2] += 10.0; // Prevent stuck spawn
		vecAngles[1] = aSpawn[SpawnAngles][1];
		
		CreateCustomSpawn(i, aSpawn[SpawnTeam], vecOrigin, vecAngles);
	}
}

HideCustomSpawns()
{
	if(!g_bShowingSpawns)
		return;
	
	g_bShowingSpawns = false;
	
	new iEnt = 0;
	while((iEnt = rg_find_ent_by_class(iEnt, g_szCustomSpawnClass)) > 0)
	{
		set_entvar(iEnt, var_modelindex, 0);
		set_entvar(iEnt, var_flags, FL_KILLME);
	}
}

SaveMapData(const id)
{
	new szDir[PLATFORM_MAX_PATH];
	get_localinfo("amxx_datadir", szDir, PLATFORM_MAX_PATH-1);
	add(szDir, PLATFORM_MAX_PATH-1, "/re_dm");

	if(!dir_exists(szDir))
		mkdir(szDir);

	new szMap[64], szFileName[PLATFORM_MAX_PATH];
	get_mapname(szMap, charsmax(szMap)); mb_strtolower(szMap);
	formatex(szFileName, PLATFORM_MAX_PATH-1, "%s/%s.dat", szDir, szMap);

	new JSON:jRootValue = json_init_object();

	json_object_set_bool(jRootValue, "random_spawn", g_bAllowRandomSpawns);

	new JSON:jArray = json_init_array();
	new JSON:jObjectSpawn;
	new Array:aObjectTemp = ArrayCreate(1, 1); // Save all json objects ids

	for(new i = 0, aSpawn[ArraySpawns_e], iCount = ArraySize(g_aSpawns); i < iCount; ++i)
	{
		ArrayGetArray(g_aSpawns, i, aSpawn);

		jObjectSpawn = json_init_object();
		ArrayPushCell(aObjectTemp, JSON:jObjectSpawn); // Push json object id

		json_object_set_number(jObjectSpawn, "id", i+1);
		json_object_set_number(jObjectSpawn, "team", _:aSpawn[SpawnTeam]);

		json_object_set_string(jObjectSpawn, "origin", 
			fmt("%d %d %d", floatround(aSpawn[SpawnOrigin][0]), floatround(aSpawn[SpawnOrigin][1]), floatround(aSpawn[SpawnOrigin][2])));

		json_object_set_string(jObjectSpawn, "angles", 
			fmt("%d %d %d", floatround(aSpawn[SpawnAngles][0]), floatround(aSpawn[SpawnAngles][1]), floatround(aSpawn[SpawnAngles][2])));

		json_array_append_value(jArray, jObjectSpawn);
	}

	json_object_set_value(jRootValue, "spawns", jArray);
	
	if(json_serial_to_file(jRootValue, szFileName, true))
		client_print_color(id, print_team_default, "%s %L", g_szGlobalPrefix, LANG_PLAYER, "CHAT_SAVED_OK", szFileName);
	else
		client_print_color(id, print_team_default, "%s %L", g_szGlobalPrefix, LANG_PLAYER, "CHAT_SAVED_ERROR", szFileName);

	// Free all objects
	for(new i = 0, iCount = ArraySize(aObjectTemp); i < iCount; ++i)
	{
		jObjectSpawn = JSON:ArrayGetCell(aObjectTemp, i);
		json_free(jObjectSpawn); // Free json object id
	}

	ArrayDestroy(aObjectTemp);
	json_free(jArray);
	json_free(jRootValue);
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
		if(!IsAlive(i) || i == id || (!g_iCSDM_FreeForAll && iTeam == GetUserTeam(i)))
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
	if(IsAlive(id) && IsUserStuck(id))
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

DropMedKit(const id)
{
	new iEnt = rg_create_entity("info_target");
	
	if(!is_nullent(iEnt))
	{
		new Float:vecVelocity[3];
		new Float:vecOrigin[3];
		
		set_entvar(iEnt, var_classname, g_szMedKitClass);
		entity_set_model(iEnt, g_szModel_MedicKit);
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
		
		client_cmd(id, "spk ^"%s^"", g_szSound_MedicKit);
		
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