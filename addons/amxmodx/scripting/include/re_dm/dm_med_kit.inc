#if defined _dm_med_kit_included_
	#endinput
#endif
#define _dm_med_kit_included_

bool:CanDropMedKit(const iId)
{
	new Float:vecOrigin[3];
	new Float:vecEndOrigin[3];
	new Float:flFraction;
	
	get_entvar(iId, var_origin, vecOrigin);
	UTIL_GetDropOrigin(iId, vecEndOrigin, 20);
	
	engfunc(EngFunc_TraceLine, vecOrigin, vecEndOrigin, IGNORE_MONSTERS, iId, 0);
	
	get_tr2(0, TR_flFraction, flFraction);
	
	return bool:(flFraction == 1.0);
}

DropMedKit(const iId)
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
		
		velocity_by_aim(iId, 300, vecVelocity);
		UTIL_GetDropOrigin(iId, vecOrigin);
		set_entvar(iEnt, var_origin, vecOrigin);
		set_entvar(iEnt, var_velocity, vecVelocity);
		
		set_entvar(iEnt, var_renderamt, 255.0);
		set_entvar(iEnt, var_takedamage, DAMAGE_NO);

		SetTouch(iEnt, "OnTouch_MedicKit");
		SetThink(iEnt, "OnThink_MedicKit");

		set_entvar(iEnt, var_nextthink, get_gametime() + g_flCSDM_ItemStaytime);
	}
}

public OnTouch_MedicKit(const medickit, const iId)
{
	if(is_nullent(medickit) || !IsAlive(iId))
		return;

	new Float:flHealth = Float:get_entvar(iId, var_health);

	if(flHealth < 100.0)
	{
		set_entvar(iId, var_health, floatmin((flHealth + float(g_iCSDM_MedicKitHealth)), 100.0));
		
		client_cmd(iId, "spk ^"%s^"", g_szSound_MedicKit);
		
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