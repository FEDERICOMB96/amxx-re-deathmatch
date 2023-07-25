#if defined _dm_global_included_
	#endinput
#endif
#define _dm_global_included_

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT) | (1<<CSW_XM1014) | (1<<CSW_MAC10) | (1<<CSW_AUG) | (1<<CSW_UMP45) | (1<<CSW_SG550) | (1<<CSW_GALIL) | (1<<CSW_FAMAS) | (1<<CSW_AWP) | (1<<CSW_MP5NAVY) | (1<<CSW_M249) | (1<<CSW_M3) | (1<<CSW_M4A1) | (1<<CSW_TMP) | (1<<CSW_G3SG1) | (1<<CSW_SG552) | (1<<CSW_AK47) | (1<<CSW_P90);
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228) | (1<<CSW_ELITE) | (1<<CSW_FIVESEVEN) | (1<<CSW_USP) | (1<<CSW_GLOCK18) | (1<<CSW_DEAGLE);

/* ===========================================================================
*                 [ WEAPONS ]
* ============================================================================ */

enum _:WeaponStruct
{
	WeaponIdType:WeaponId,
	WeaponEnt[32],
	WeaponName[32],
};

enum _:WeaponData
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

new g_iWeaponData[MAX_USERS][WeaponData];