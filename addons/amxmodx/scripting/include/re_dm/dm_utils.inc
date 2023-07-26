#if defined _dm_utils_included_
	#endinput
#endif
#define _dm_utils_included_

UTIL_RegisterClientCommandAll(const sCommand[], sFunction[], iFlags = -1, const sInfo[] = "", FlagManager = -1, bool:bInfo_ml = false)
{
	register_clcmd(fmt("say %s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
	register_clcmd(fmt("say /%s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
	register_clcmd(fmt("say !%s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
	register_clcmd(fmt("say .%s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);

	register_clcmd(fmt("say_team %s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
	register_clcmd(fmt("say_team /%s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
	register_clcmd(fmt("say_team !%s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
	register_clcmd(fmt("say_team .%s", sCommand), sFunction, iFlags, sInfo, FlagManager, bInfo_ml);
}

UTIL_SetAnimation(const iId, const iAnimation)
{
	set_entvar(iId, var_weaponanim, iAnimation);
	
	message_begin(MSG_ONE, SVC_WEAPONANIM, _, iId);
	write_byte(iAnimation);
	write_byte(get_entvar(iId, var_body));
	message_end();
}

WeaponIdType:UTIL_GetCurrentWeapon(const iId)
{
	new pActiveItem = get_member(iId, m_pActiveItem);

	if(is_nullent(pActiveItem))
		return WEAPON_NONE;

	return WeaponIdType:get_member(pActiveItem, m_iId);
}

WeaponIdType:UTIL_GetWeaponNameId(const sWeapon[])
{
	for(new i = 1, sWeaponName[32]; i <= _:WEAPON_P90; ++i)
	{
		if(get_weaponname(i, sWeaponName, charsmax(sWeaponName)) && equal(sWeapon, sWeaponName))
			return WeaponIdType:i;
	}
	
	return WEAPON_NONE;
}

bool:UTIL_GetWeaponBurst(const pWeapon)
{
	switch(WeaponIdType:get_member(pWeapon, m_iId))
	{
		case WEAPON_GLOCK18: return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_GLOCK18_BURST_MODE);
		case WEAPON_FAMAS:   return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_FAMAS_BURST_MODE);
	}

	return false;
}

bool:UTIL_GetWeaponSilen(const pWeapon)
{
	switch(WeaponIdType:get_member(pWeapon, m_iId))
	{
		case WEAPON_M4A1: return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_M4A1_SILENCED);
		case WEAPON_USP:  return bool:(get_member(pWeapon, m_Weapon_iWeaponState) & WPNSTATE_USP_SILENCED);
	}

	return false;
}

UTIL_GetDropOrigin(const iId, Float:vecOrigin[3], iVelAdd = 0)
{
	new Float:vecAim[3];
	new Float:vecViewOfs[3];
	
	get_entvar(iId, var_view_ofs, vecViewOfs);
	get_entvar(iId, var_origin, vecOrigin);
	xs_vec_add(vecOrigin, vecViewOfs, vecOrigin);
	
	velocity_by_aim(iId, 50 + iVelAdd, vecAim);
	
	vecOrigin[0] += vecAim[0];
	vecOrigin[1] += vecAim[1];
}