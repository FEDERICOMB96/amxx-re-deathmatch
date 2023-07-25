#if defined _dm_weapons_included_
	#endinput
#endif
#define _dm_weapons_included_

WeaponsInit() {
	ArrayClear(g_aPrimaryWeapons);
	ArrayClear(g_aSecondaryWeapons);

	new szFileName[PLATFORM_MAX_PATH];
	new iLen = get_configsdir(szFileName, charsmax(szFileName));
	formatex(szFileName[iLen], charsmax(szFileName) - iLen, "/%s/%s", DM_CONFIG_FOLDER, DM_WEAPONS_FILENAME);

	if(!file_exists(szFileName))
		return;
	
	new JSON:jWeapons = json_parse(szFileName, true);

	if(jWeapons == Invalid_JSON)
		log_to_file(LOG_FILENAME, "[DM] %L [%s]", LANG_SERVER, "INVALID_JSON_FILE", szFileName);
	else
	{
		if(json_is_object(jWeapons))
		{
			new aWeaponData[WeaponStruct];

			if(json_object_has_value(jWeapons, "primary", JSONObject))
			{
				new JSON:jPrimaryWeapons = json_object_get_value(jWeapons, "primary");

				for(new i = 0, iMaxLoop = json_object_get_count(jPrimaryWeapons); i < iMaxLoop; ++i)
				{
					json_object_get_name(jPrimaryWeapons, i, aWeaponData[WeaponEnt], charsmax(aWeaponData[WeaponEnt]));
					
					// Invalid weapon ent name
					if((aWeaponData[WeaponId] = UTIL_GetWeaponNameId(aWeaponData[WeaponEnt])) == WEAPON_NONE)
					{
						log_to_file(LOG_FILENAME, "[DM] %L [%s]", LANG_SERVER, "INVALID_WEAPON_ENT", aWeaponData[WeaponEnt]);
						continue;
					}
					
					// Weapon is not primary
					if((1 << _:aWeaponData[WeaponId]) & ~PRIMARY_WEAPONS_BIT_SUM)
					{
						log_to_file(LOG_FILENAME, "[DM] %L [%s]", LANG_SERVER, "INVALID_PRIMARY_WEAPON", aWeaponData[WeaponEnt]);
						continue;
					}

					json_object_get_string(jWeapons, fmt("primary.%s", aWeaponData[WeaponEnt]), aWeaponData[WeaponName], charsmax(aWeaponData[WeaponName]), true);
					
					ArrayPushArray(g_aPrimaryWeapons, aWeaponData);
				}

				json_free(jPrimaryWeapons);
			}

			if(json_object_has_value(jWeapons, "secondary", JSONObject))
			{
				new JSON:jSecondaryWeapons = json_object_get_value(jWeapons, "secondary");

				for(new i = 0, iMaxLoop = json_object_get_count(jSecondaryWeapons); i < iMaxLoop; ++i)
				{
					json_object_get_name(jSecondaryWeapons, i, aWeaponData[WeaponEnt], charsmax(aWeaponData[WeaponEnt]));
					
					// Invalid weapon ent name
					if((aWeaponData[WeaponId] = UTIL_GetWeaponNameId(aWeaponData[WeaponEnt])) == WEAPON_NONE)
					{
						log_to_file(LOG_FILENAME, "[DM] %L [%s]", LANG_SERVER, "INVALID_WEAPON_ENT", aWeaponData[WeaponEnt]);
						continue;
					}
					
					// Weapon is not secondary
					if((1 << _:aWeaponData[WeaponId]) & ~SECONDARY_WEAPONS_BIT_SUM)
					{
						log_to_file(LOG_FILENAME, "[DM] %L [%s]", LANG_SERVER, "INVALID_SECONDARY_WEAPON", aWeaponData[WeaponEnt]);
						continue;
					}

					json_object_get_string(jWeapons, fmt("secondary.%s", aWeaponData[WeaponEnt]), aWeaponData[WeaponName], charsmax(aWeaponData[WeaponName]), true);
					
					ArrayPushArray(g_aSecondaryWeapons, aWeaponData);
				}

				json_free(jSecondaryWeapons);
			}
		}
		
		json_free(jWeapons);
	}

	// Plugin can't work without weapons
	if((ArraySize(g_aPrimaryWeapons) < 1) && (ArraySize(g_aSecondaryWeapons) < 1))
	{
		log_to_file(LOG_FILENAME, "[DM] %L", LANG_SERVER, "NO_WEAPONS_LOADED");
		set_fail_state("[DM] %L", LANG_SERVER, "NO_WEAPONS_LOADED");
	}
}