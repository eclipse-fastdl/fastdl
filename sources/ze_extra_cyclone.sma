#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <engine>
#include <reapi>
#include <xs>
#include <ze_core>

// Macroses.
#define IsWeaponCyclone(%1) (is_entity(%1) && get_entvar(%1,var_impulse)==WEAPON_UID)

// Defines.
#define EXTRA_ITEM 1  // 1 = Enabled | 0 = Disabled.

// Zombie Escape: Item Info.
#if EXTRA_ITEM == 1
stock const ZE_ITEM_NAME[] = "Cyclone"
stock const ZE_ITEM_COST = 50
stock const ZE_ITEM_LIMIT = 0
#endif

// - Weapon Info:
new const WEAPON_NAME[] = "weapon_cyclone_lz"
new const WEAPON_REFERENCE[] = "weapon_deagle"
new const WEAPON_ANIMEXT[] = "onehanded"
const WEAPON_ID = CSW_DEAGLE
const WEAPON_UID = 50953125
const WEAPON_MAXCLIP = 50
const WEAPON_DEFAULTAMMO = 100
const Float:WEAPON_DAMAGE = 6.0
const Float:WEAPON_FIRERATE = 0.08
const Float:WEAPON_RANGE = 4096.0

new const MZZFLASH_NAME[] = "mzz_cyclone"
new const MZZFLASH_REFERENCE[] = "info_target"
const Float:MZZFLASH_SCALE = 0.1
const Float:MZZFLASH_THINK = 0.1

// Model Animations.
enum (+=1)
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_SHOOT_END,
	ANIM_RELOAD,
	ANIM_DRAW
}

enum _:eFireSounds
{
	SOUND_FIRE_BEGIN = 0,
	SOUND_FIRE_LOOP
}

enum _:ePlayerWeaponData
{
	bool:CYCLONE_LOOPFIRE = 0,
	Float:CYCLONE_ANIMTIME,
	Float:CYCLONE_SHOOTEND,
	Float:CYCLONE_NEXTSOUND,
	Float:CYCLONE_NEXTATTACK
}

// Anim Time
const Float:ANIM_TIME_IDLE = 3.37
const Float:ANIM_TIME_SHOOT = 0.43
const Float:ANIM_TIME_SHOOT_END = 0.53
const Float:ANIM_TIME_RELOAD = 2.23
const Float:ANIM_TIME_DRAW = 1.33

// Weapon Models.
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_sfpistol.mdl"
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/ozzy_extras/v_sfpistol.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_sfpistol.mdl"

// Weapon shoot Sound.
new const g_szFireSound[eFireSounds][] =
{
	"weapons/sfpistol_shoot5.wav",
	"weapons/sfpistol_shoot1.wav"
}

new const g_szMzzFlashSprite[] = "sprites/ef_cyclone_muzz.spr"

new const g_szWeaponListRsc[][] =
{
	"sprites/weapon_cyclone_lz.txt",
	"sprites/640hudx0.spr"
}

// Variables.
new g_iBeamSpr,
	g_iPosition,
	g_iExploSpr,
	g_iWeaponList

#if EXTRA_ITEM == 1
new g_iItemID
#endif

// Array.
new g_CycloneData[MAX_PLAYERS+1][ePlayerWeaponData]

public plugin_precache()
{
#if EXTRA_ITEM == 1
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel)
	if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
		ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel)
#endif

	new const szBeamSprite[] = "sprites/laserbeam.spr"
	new const szExploSprite[] = "sprites/ef_smoke_poison.spr"

	// Pre-load Models.
	precache_model(g_p_szWeaponModel)
	precache_model(g_v_szWeaponModel)
	precache_model(g_w_szWeaponModel)
	precache_model(g_szMzzFlashSprite)
	g_iBeamSpr = precache_model(szBeamSprite)
	g_iExploSpr = precache_model(szExploSprite)

	new const szWeaponSounds[][] =
	{
		"sound/weapons/sfpistol_clipin.wav",
		"sound/weapons/sfpistol_clipout.wav",
		"sound/weapons/sfpistol_draw.wav",
		"sound/weapons/sfpistol_idle.wav",
		"sound/weapons/sfpistol_shoot_end.wav",
		"sound/weapons/sfpistol_shoot_start.wav",
		"sound/weapons/sfpistol_shoot1.wav",
		"sound/weapons/sfpistol_shoot5.wav"
	}

	new i

	// Pre-load Sounds.
	for (i = 0; i < sizeof(g_szFireSound); i++)
		precache_sound(g_szFireSound[i])

	// Pre-load More.
	for (i = 0; i < sizeof(g_szWeaponListRsc); i++)
		precache_generic(g_szWeaponListRsc[i])
	for (i = 0; i < sizeof(szWeaponSounds); i++)
		precache_generic(szWeaponSounds[i])
}

public plugin_init()
{
	// Load Plug-In.
	register_plugin("[ZE] Extra Item: Cyclone", "1.2", "z0h1r-LK")

	// Hook Chains
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")
	RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")

	// Hams.
	RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_WeaponIdle_Pre")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack_Pre")
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)
	RegisterHam(Ham_RemovePlayerItem, WEAPON_REFERENCE, "fw_Weapon_RemovePlayerItem_Post", 1)

	// FakeMeta.
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	// Engine.
	register_think(MZZFLASH_NAME, "fw_MuzzFlash_Think")

#if EXTRA_ITEM == 1
	// New Item.
	g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
#endif

	// Commands.
	register_clcmd(WEAPON_NAME, "cmd_SelectWeapon")

	// Initial Values.
	g_iWeaponList = get_user_msgid("WeaponList")
	g_iPosition = rg_get_global_iteminfo(WEAPON_ID, ItemInfo_iPosition)
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
	if (is_user_hltv(id))
		return;

	arrayset(g_CycloneData[id], 0, sizeof(g_CycloneData))
}

#if EXTRA_ITEM == 1
public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu)
{
	if (iItem != g_iItemID)
		return ZE_ITEM_AVAILABLE

	// Don't show item in Zombies Items.
	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost)
{
	if (iItem != g_iItemID)
		return

	give_Cyclone(id)
}
#endif

public cmd_SelectWeapon(const id)
{
	engclient_cmd(id, WEAPON_REFERENCE)
	return PLUGIN_HANDLED;
}

public give_Cyclone(const id)
{
	new iWpnEnt
	if ((iWpnEnt = rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)) != NULLENT)
	{
		log_error(AMX_ERR_NATIVE, "[ZE] Invalid Weapon ID (-1)")
		return
	}

	rg_set_user_bpammo(id, WeaponIdType:WEAPON_ID, WEAPON_DEFAULTAMMO)

	// Some weapon data will be set from fw_Weapon_Spawn_Pre().
	if (iWpnEnt == get_member(id, m_pActiveItem))
		rg_weapon_deploy(iWpnEnt, g_v_szWeaponModel, g_p_szWeaponModel, ANIM_DRAW, WEAPON_ANIMEXT)
}

public client_cmdStart(id)
{
	if (!is_user_alive(id))
		return

	if (!IsWeaponCyclone(get_member(id, m_pActiveItem)))
		return

	static Float:flHlTime; flHlTime = get_gametime()
	if (g_CycloneData[id][CYCLONE_ANIMTIME] > flHlTime)
		return

	if (~get_usercmd(usercmd_buttons) & IN_ATTACK && g_CycloneData[id][CYCLONE_LOOPFIRE])
	{
		g_CycloneData[id][CYCLONE_LOOPFIRE] = false
		g_CycloneData[id][CYCLONE_SHOOTEND] = flHlTime + ANIM_TIME_SHOOT_END

		emit_sound(id, CHAN_WEAPON, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		rg_weapon_send_animation(id, ANIM_SHOOT_END)
	}

	g_CycloneData[id][CYCLONE_NEXTATTACK] = flHlTime + WEAPON_FIRERATE
}

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED

	if (IsWeaponCyclone(get_member(id, m_pActiveItem)))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}

	return FMRES_IGNORED
}

public pfn_playbackevent() <FireBullets: Enabled>
	return PLUGIN_HANDLED
public pfn_playbackevent() <FireBullets: Disabled>
	return PLUGIN_CONTINUE
public pfn_playbackevent() < >
	return PLUGIN_CONTINUE

public fw_Weapon_DefaultDeploy_Pre(const iWpnEnt, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return

	if (g_v_szWeaponModel[0])
		SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)

	if (g_p_szWeaponModel[0])
		SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)

	SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
	SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)
}

public fw_Weapon_DefaultReload_Pre(const iWpnEnt, iClipSize, iAnim, Float:flDelay)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return

	SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
	SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
	SetHookChainArg(4, ATYPE_FLOAT, ANIM_TIME_RELOAD)
}

public fw_WeaponBox_SetModel_Pre(const iEnt, const szModel[])
{
	if (is_nullent(iEnt))
		return

	if (IsWeaponCyclone(get_member(iEnt, m_WeaponBox_rgpPlayerItems, PISTOL_SLOT)))
	{
		if (g_w_szWeaponModel[0])
		{
			SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
		}
	}
}

public fw_Weapon_Spawn_Post(const iWpnEnt)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return

	set_member(iWpnEnt, m_Weapon_iDefaultAmmo, WEAPON_DEFAULTAMMO)
	set_member(iWpnEnt, m_Weapon_flBaseDamage, WEAPON_DAMAGE)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
	rg_set_iteminfo(iWpnEnt, ItemInfo_iMaxAmmo1, WEAPON_DEFAULTAMMO)
}

public fw_Weapon_WeaponIdle_Pre(const iWpnEnt)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return HAM_IGNORED

	if (get_member(iWpnEnt, m_Weapon_flTimeWeaponIdle) > 0.0)
		return HAM_SUPERCEDE

	rg_weapon_send_animation(iWpnEnt, ANIM_IDLE)
	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_IDLE)
	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack_Pre(const iWpnEnt)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return HAM_IGNORED

	static iClipSize; iClipSize = get_member(iWpnEnt, m_Weapon_iClip)
	if (iClipSize <= 0)
	{
		ExecuteHam(Ham_Weapon_PlayEmptySound, iWpnEnt)
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	static iAttacker; iAttacker = get_member(iWpnEnt, m_pPlayer)

	static Float:flHlTime; flHlTime = get_gametime()
	if (g_CycloneData[iAttacker][CYCLONE_SHOOTEND] > flHlTime)
	{
		emit_sound(iAttacker, CHAN_WEAPON, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, 0.2)
		return HAM_SUPERCEDE
	}

	static Float:vStart[3]
	ExecuteHam(Ham_Player_GetGunPosition, iAttacker, vStart)

	static Float:vTarget[3]
	get_entvar(iAttacker, var_v_angle, vTarget)
	angle_vector(vTarget, ANGLEVECTOR_FORWARD, vTarget)
	xs_vec_mul_scalar(vTarget, WEAPON_RANGE, vTarget)
	xs_vec_add(vTarget, vStart, vTarget)

	static hTrace; hTrace = create_tr2()
	engfunc(EngFunc_TraceLine, vStart, vTarget, DONT_IGNORE_MONSTERS, iAttacker, hTrace)
	get_tr2(hTrace, TR_vecEndPos, vTarget)
	static iHitEnt; iHitEnt = get_tr2(hTrace, TR_pHit)

	if (iHitEnt != NULLENT)
	{
		if (get_entvar(iHitEnt, var_takedamage) != DAMAGE_NO && get_entvar(iHitEnt, var_health) > 0.0)
		{
			static Float:vDirection[3] // This will affect Knockback!
			xs_vec_sub(vStart, vTarget, vDirection)
			xs_vec_normalize(vDirection, vDirection)

			rg_multidmg_clear()
			ExecuteHamB(Ham_TraceAttack, iHitEnt, iAttacker, get_member(iWpnEnt, m_Weapon_flBaseDamage), vDirection, hTrace, DMG_ENERGYBEAM)
			rg_multidmg_apply(iAttacker, iAttacker)
		}
	}

	free_tr2(hTrace) // Frees the handle.

	// Small Beam.
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT) // TE id.
	write_short(iAttacker | 0x1000) // Entity ID.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2]) // Position Z.
	write_short(g_iBeamSpr) // Sprite index.
	write_byte(0) // Frame.
	write_byte(0) // Frame rate.
	write_byte(2) // Duration.
	write_byte(10) // Width.
	write_byte(0) // Noise amplitude.
	write_byte(120) // Red.
	write_byte(238) // Green.
	write_byte(3) // Blue.
	write_byte(255) // Brightness.
	write_byte(-75) // Scroll Speed.
	message_end()

	// Wall Puff.
	message_begin_f(MSG_PVS, SVC_TEMPENTITY, vTarget)
	write_byte(TE_EXPLOSION) // TE id.
	write_coord_f(vTarget[0]) // Position X.
	write_coord_f(vTarget[1]) // Position Y.
	write_coord_f(vTarget[2] - 10.0) // Position Z.
	write_short(g_iExploSpr) // Sprite index.
	write_byte(2) // Scale.
	write_byte(80) // Frame rate.
	write_byte(TE_EXPLFLAG_NOPARTICLES|TE_EXPLFLAG_NODLIGHTS|TE_EXPLFLAG_NOSOUND) // Flags.
	message_end()

	// Play shoot sound.
	if (!g_CycloneData[iAttacker][CYCLONE_LOOPFIRE])
	{
		g_CycloneData[iAttacker][CYCLONE_LOOPFIRE] = true
		emit_sound(iAttacker, CHAN_WEAPON, g_szFireSound[SOUND_FIRE_BEGIN], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	else if (g_CycloneData[iAttacker][CYCLONE_NEXTSOUND] <= flHlTime)
	{
		g_CycloneData[iAttacker][CYCLONE_NEXTSOUND] = flHlTime + 4.0
		emit_sound(iAttacker, CHAN_WEAPON, g_szFireSound[SOUND_FIRE_LOOP], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}

	if (g_CycloneData[iAttacker][CYCLONE_ANIMTIME] <= flHlTime)
	{
		rg_weapon_send_animation(iAttacker, ANIM_SHOOT)
		g_CycloneData[iAttacker][CYCLONE_ANIMTIME] = flHlTime + ANIM_TIME_SHOOT
	}

	CreateMuzzleFlashSpr(iAttacker, 1)

	set_member(iWpnEnt, m_Weapon_iClip, iClipSize - 1)
	set_member(iWpnEnt, m_Weapon_flTimeWeaponIdle, ANIM_TIME_SHOOT)
	set_member(iWpnEnt, m_Weapon_flNextPrimaryAttack, WEAPON_FIRERATE)
	return HAM_SUPERCEDE
}

public CreateMuzzleFlashSpr(clientIndex, iAttachment)
{
	static iEnt
	if (!(iEnt = rg_create_entity(MZZFLASH_REFERENCE)))
		return;

	set_entvar(iEnt, var_classname, MZZFLASH_NAME)
	set_entvar(iEnt, var_movetype, MOVETYPE_FOLLOW)
	set_entvar(iEnt, var_aiment, clientIndex)
	set_entvar(iEnt, var_owner, clientIndex)
	set_entvar(iEnt, var_skin, clientIndex)
	set_entvar(iEnt, var_body, iAttachment)
	set_entvar(iEnt, var_scale, MZZFLASH_SCALE)

	entity_set_model(iEnt, g_szMzzFlashSprite)
	set_ent_rendering(iEnt, kRenderFxNone, 0, 0, 0, kRenderTransAdd, 255)

	set_entvar(iEnt, var_nextthink, get_gametime() + MZZFLASH_THINK)
}

public fw_MuzzFlash_Think(const iEnt)
{
	if (is_nullent(iEnt))
		return PLUGIN_CONTINUE;

	static Float:fFrame; fFrame = get_entvar(iEnt, var_frame)
	if (fFrame > get_ent_data_float(iEnt, "CSprite", "m_maxFrame"))
	{
		rg_remove_entity(iEnt)
		return PLUGIN_HANDLED;
	}

	fFrame++
	set_entvar(iEnt, var_frame, fFrame)
	set_entvar(iEnt, var_nextthink, get_gametime() + MZZFLASH_THINK)
	return PLUGIN_CONTINUE;
}

public fw_Weapon_AddToPlayer_Post(const iWpnEnt, const clientIndex)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return;

	WeaponList(clientIndex, 1)
}

public fw_Weapon_RemovePlayerItem_Post(const iWpnEnt, const clientIndex)
{
	if (!IsWeaponCyclone(iWpnEnt))
		return;

	WeaponList(clientIndex, 0)
}

WeaponList(const id, const iMode = 0)
{
	message_begin(MSG_ONE, g_iWeaponList, .player = id)
	write_string(iMode ? WEAPON_NAME : WEAPON_REFERENCE) // Weapon Name.
	write_byte(8) // Primary Ammo ID.
	write_byte(WEAPON_DEFAULTAMMO) // Primary Ammo Max Amount.
	write_byte(NULLENT) // Secondary Ammo ID.
	write_byte(NULLENT) // Secondary Ammo Max Amount.
	write_byte(1) // SlotID.
	write_byte(g_iPosition) // Number in slot.
	write_byte(WEAPON_ID) // Weapon ID.
	write_byte(0) // Flags
	message_end()
}
