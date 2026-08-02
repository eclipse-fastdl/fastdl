#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>

// Macroses.
#define fIsClient(%1) (1<=(%1)<=MaxClients)
#define fIsCustomWeapon(%1) (is_entity(%1) && get_entvar(%1,var_impulse) == WEAPON_UID)

// Weapon Animtions.
enum (+=1) {
    ANIM_IDLE = 0,
    ANIM_RELOAD,
    ANIM_DEPLOY,
    ANIM_SHOOT1,
    ANIM_SHOOT2,
    ANIM_SHOOT3
}

// Zombie Escape: Item Info
stock const ZE_ITEM_NAME[] = "Ray Gun Mark II .$"
const ZE_ITEM_COST = 30
const ZE_ITEM_LIMIT = 1

// Animation Time.
const Float:ANIM_TIME_IDLE = 6.70
const Float:ANIM_TIME_RELOAD = 2.5
const Float:ANIM_TIME_DEPLOY = 1.03
const Float:ANIM_TIME_SHOOT = 1.03

// - Weapon Info:
new const WEAPON_NAME[] = "weapon_plasmagun6_lz"
new const WEAPON_REFERENCE[] = "weapon_deagle"
const WEAPON_ID = CSW_DEAGLE
new const WEAPON_ANIMEXT[] = "onehanded"
const WEAPON_UID = 21142725
const WEAPON_MAXCLIP = 21
const WEAPON_DEFAULTAMMO = 161
const Float:WEAPON_FIRERATE = 0.10 // 0.13

// - PlasmaBall Info:
new const PLASMABALL_NAME[] = "plasma_ball"
new const PLASMABALL_REFERENCE[] = "env_sprite"
new const PLASMABALL_MODEL[] = "sprites/CSO/ef_plasmaball_green.spr"
const PLASMABALL_SPEED = 1500
const Float:PLASMABALL_DAMAGE = 44.0
const Float:PLASMABALL_RADIUS = 60.0
const PLASMABALL_DMGTYPE = DMG_BURN|DMG_NERVEGAS
const PLASMABALL_LIMIT_WARN = 100

// Weapon Models.
new g_v_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/v_plasmagun.mdl"
new g_p_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/p_plasmagun_6.mdl"
new g_w_szWeaponModel[MAX_RESOURCE_PATH_LENGTH] = "models/CSO/w_plasmagun_6.mdl"

// Weapon Fire sound.
new const g_szWeaponFireSnd[] = "weapons/CSO/plasmagun-1.wav"

// Weapon Sounds.
new const g_szWeaponSounds[][] = {
    "sound/weapons/CSO/plasmagun_clipin1.wav",
    "sound/weapons/CSO/plasmagun_clipin2.wav",
    "sound/weapons/CSO/plasmagun_clipout.wav",
    "sound/weapons/CSO/plasmagun_draw.wav",
    "sound/weapons/CSO/plasmagun_exp.wav",
    "sound/weapons/CSO/plasmagun_idle.wav"
}

// Weapon list.
new const g_szWeaponListTxt[][] = {
    "sprites/weapon_plasmagun6_lz.txt",
    "sprites/640hudc2.spr"
}

// Plasmaball Explosion sound.
new const g_szPlasmaBallSound[] = "weapons/CSO/plasmagun_exp.wav"

// Variables.
new g_iItemID, g_iExploSpr, g_iMsgWeaponList, Float:g_flSlowdown

public plugin_precache() {
    g_flSlowdown = 0.40
    
    if (!ini_read_float(ZE_ET_FILENAME, ZE_ITEM_NAME, "KB_SLOWDOWN", g_flSlowdown))
        ini_write_float(ZE_ET_FILENAME, ZE_ITEM_NAME, "KB_SLOWDOWN", g_flSlowdown)
        
    if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel, charsmax(g_v_szWeaponModel)))
        ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "VIEW_MODEL", g_v_szWeaponModel)
        
    if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel, charsmax(g_p_szWeaponModel)))
        ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WEAPON_MODEL", g_p_szWeaponModel)
        
    if (!ini_read_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel, charsmax(g_w_szWeaponModel)))
        ini_write_string(ZE_ET_FILENAME, ZE_ITEM_NAME, "WORLD_MODEL", g_w_szWeaponModel)
        
    new const szPlasmaBallExploSpr[] = "sprites/CSO/ef_plasmaexp_green.spr"
    
    // Preload Models.
    precache_model(PLASMABALL_MODEL)
    precache_model(g_v_szWeaponModel)
    precache_model(g_p_szWeaponModel)
    precache_model(g_w_szWeaponModel)
    g_iExploSpr = precache_model(szPlasmaBallExploSpr)
    
    // Preload Sounds.
    precache_sound(g_szWeaponFireSnd)
    precache_sound(g_szPlasmaBallSound)
    
    new i
    for (i = 0; i < sizeof(g_szWeaponListTxt); i++)
        precache_generic(g_szWeaponListTxt[i])
        
    for (i = 0; i < sizeof(g_szWeaponSounds); i++)
        precache_generic(g_szWeaponSounds[i])
}

public plugin_init() {
    // Load Plug-In.
    register_plugin("[ZE] Extra Item: Plasma Gun (CHAMIRA)", "1.2", "z0h1r-LK")
    
    // Hook Chains.
    RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload, "fw_Weapon_DefaultReload_Pre")
    
    // Hams.
    RegisterHam(Ham_Spawn, WEAPON_REFERENCE, "fw_Weapon_Spawn_Post", 1)
    RegisterHam(Ham_Item_Holster, WEAPON_REFERENCE, "fw_Weapon_Holster_Post", 1)
    RegisterHam(Ham_Item_AddToPlayer, WEAPON_REFERENCE, "fw_Weapon_AddToPlayer_Post", 1)
    RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_REFERENCE, "fw_Weapon_Idle_Pre")
    RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_Weapon_PrimaryAttack")
    RegisterHam(Ham_Touch, PLASMABALL_REFERENCE, "fw_PlasmaBall_Touch_Post", 1)
    
    // FakeMeta.
    register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
    
    // Command.
    register_clcmd(WEAPON_NAME, "cmd_ChoosePlasmaGun")
    
    // New Item.
    g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
    
    // Set Values.
    g_iMsgWeaponList = get_user_msgid("WeaponList")
}

public cmd_ChoosePlasmaGun(const id) {
    engclient_cmd(id, WEAPON_REFERENCE)
    return PLUGIN_HANDLED
}

public ze_select_item_pre(id, iItem, bool:bIgnoreCost, bool:bInMenu) {
    if (iItem != g_iItemID) 
        return ZE_ITEM_AVAILABLE
        
    if (ze_is_user_zombie(id)) 
        return ZE_ITEM_DONT_SHOW
        
    return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost) {
    // This is not our Item.
    if (iItem != g_iItemID) 
        return
        
    GivePlayerWeapon(id)
}

public GivePlayerWeapon(const id) {
    new iItem
    if ((iItem = rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)) == NULLENT) 
        return
        
    set_member(iItem, m_Weapon_iClip, WEAPON_MAXCLIP)
    set_member(iItem, m_Weapon_iDefaultAmmo, WEAPON_DEFAULTAMMO)
    set_member(iItem, m_Weapon_bHasSecondaryAttack, false)
    
    rg_set_iteminfo(iItem, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
    rg_set_iteminfo(iItem, ItemInfo_iMaxAmmo1, WEAPON_DEFAULTAMMO)
    
    if (iItem == get_member(id, m_pActiveItem)) {
        rg_weapon_deploy(iItem, g_v_szWeaponModel, g_p_szWeaponModel, ANIM_DEPLOY, WEAPON_ANIMEXT)
    }
    
    WeaponList(id, 1)
}

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle) {
    if (!is_user_alive(id)) 
        return FMRES_IGNORED
        
    if (fIsCustomWeapon(get_member(id, m_pActiveItem))) {
        set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
        return FMRES_HANDLED
    }
    
    return FMRES_IGNORED
}

public fw_Weapon_AddToPlayer_Post(const iItem, const iPlayer) {
    if (fIsCustomWeapon(iItem)) 
        WeaponList(iPlayer, 1)
    else 
        WeaponList(iPlayer)
}

public fw_Weapon_Spawn_Post(const iItem) {
    if (!fIsCustomWeapon(iItem)) 
        return
        
    rg_set_iteminfo(iItem, ItemInfo_iMaxClip, WEAPON_MAXCLIP)
    rg_set_iteminfo(iItem, ItemInfo_iMaxAmmo1, WEAPON_DEFAULTAMMO)
}

public fw_Weapon_Holster_Post(const iItem) {
    if (!fIsCustomWeapon(iItem)) 
        return
        
    emit_sound(get_member(iItem, m_pPlayer), CHAN_ITEM, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public fw_Weapon_Idle_Pre(const iItem) {
    if (!fIsCustomWeapon(iItem)) 
        return HAM_IGNORED
        
    if (get_member(iItem, m_Weapon_flTimeWeaponIdle) > 0.0) 
        return HAM_SUPERCEDE
        
    rg_weapon_send_animation(iItem, ANIM_IDLE)
    set_member(iItem, m_Weapon_flTimeWeaponIdle, ANIM_TIME_IDLE)
    return HAM_SUPERCEDE
}

public fw_WeaponBox_SetModel_Pre(const iEnt, const szModel[])
{
	if (is_nullent(iEnt))
		return

	if (fIsCustomWeapon(get_member(iEnt, m_WeaponBox_rgpPlayerItems, 1)))
		SetHookChainArg(2, ATYPE_STRING, g_w_szWeaponModel)
}

// Hook called when activate primary attack in AK47 weapon.
public fw_Weapon_PrimaryAttack(const iItem) {
    if (!fIsCustomWeapon(iItem)) 
        return HAM_IGNORED
        
    static iClipSize; 
    iClipSize = get_member(iItem, m_Weapon_iClip)
    
    if (!iClipSize) {
        ExecuteHam(Ham_Weapon_PlayEmptySound, iItem)
        set_member(iItem, m_Weapon_flNextPrimaryAttack, 0.2)
        return HAM_SUPERCEDE
    }
    
    static iAttacker; 
    iAttacker = get_member(iItem, m_pPlayer)
    
    static Float:vStart[3], Float:vAngle[3], Float:vSpeed[3]
    ExecuteHamB(Ham_Player_GetGunPosition, iAttacker, vStart)
    
    get_entvar(iAttacker, var_v_angle, vAngle)
    angle_vector(vAngle, ANGLEVECTOR_FORWARD, vAngle)
    xs_vec_mul_scalar(vAngle, 32.0, vAngle)
    xs_vec_add(vStart, vAngle, vStart)
    
    velocity_by_aim(iAttacker, PLASMABALL_SPEED, vSpeed)
    create_PlasmaBall(vStart, vSpeed, iAttacker)
    
    rg_set_animation(iAttacker, PLAYER_ATTACK1)
    rg_weapon_send_animation(iAttacker, random_num(ANIM_SHOOT1, ANIM_SHOOT3))
    emit_sound(iAttacker, CHAN_WEAPON, g_szWeaponFireSnd, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
    
    // -1 plasma ball.
    set_member(iItem, m_Weapon_iClip, (get_member(iItem, m_Weapon_iClip) - 1))
    
    get_entvar(iAttacker, var_velocity, vSpeed)
    static iFlags; 
    iFlags = get_entvar(iAttacker, var_flags)
    
    // Credit: S3xty & ReHLDS Team.
    if (xs_vec_len(vSpeed) > 0) 
        rg_weapon_kickback(iItem, 1.5, 0.45, 0.225, 0.05, 6.5, 2.5, 1)
    else if (!(iFlags & FL_ONGROUND)) 
        rg_weapon_kickback(iItem, 2.0, 1.0, 0.5, 0.35, 9.0, 6.0, 3)
    else if (iFlags & FL_DUCKING) 
        rg_weapon_kickback(iItem, 0.9, 0.35, 0.15, 0.025, 5.5, 1.5, 9)
    else 
        rg_weapon_kickback(iItem, 1.0, 0.375, 0.175, 0.0375, 5.75, 1.75, 8)
        
    set_member(iItem, m_Weapon_flTimeWeaponIdle, ANIM_TIME_SHOOT)
    set_member(iItem, m_Weapon_flNextPrimaryAttack, WEAPON_FIRERATE)
    return HAM_SUPERCEDE
}

public fw_Weapon_DefaultDeploy_Pre(const iItem, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal) {
    if (!fIsCustomWeapon(iItem)) 
        return
        
    if (g_v_szWeaponModel[0]) 
        SetHookChainArg(2, ATYPE_STRING, g_v_szWeaponModel)
        
    if (g_p_szWeaponModel[0]) 
        SetHookChainArg(3, ATYPE_STRING, g_p_szWeaponModel)
        
    SetHookChainArg(4, ATYPE_INTEGER, ANIM_DEPLOY)
    SetHookChainArg(5, ATYPE_STRING, WEAPON_ANIMEXT)
}

public fw_Weapon_DefaultReload_Pre(const iItem, iClipSize, iAnim, Float:fDelay) {
    if (!fIsCustomWeapon(iItem)) 
        return
        
    SetHookChainArg(2, ATYPE_INTEGER, WEAPON_MAXCLIP)
    SetHookChainArg(3, ATYPE_INTEGER, ANIM_RELOAD)
    SetHookChainArg(4, ATYPE_FLOAT, ANIM_TIME_RELOAD)
}

public create_PlasmaBall(const Float:vOrigin[3], const Float:vSpeed[3], const iAttacker) {
    if (global_get(glb_maxEntities) - engfunc(EngFunc_NumberOfEntities) <= PLASMABALL_LIMIT_WARN) 
        return
        
    static iEnt;
    if (!(iEnt = rg_create_entity(PLASMABALL_REFERENCE))) 
        return
        
    set_entvar(iEnt, var_model, PLASMABALL_MODEL)
    set_entvar(iEnt, var_scale, 0.2)
    set_entvar(iEnt, var_origin, vOrigin)
    set_entvar(iEnt, var_framerate, 10.0)
    set_entvar(iEnt, var_renderamt, 200.0)
    set_entvar(iEnt, var_rendermode, kRenderTransAdd)
    set_entvar(iEnt, var_spawnflags, SF_SPRITE_STARTON)
    
    dllfunc(DLLFunc_Spawn, iEnt)
    
    set_entvar(iEnt, var_classname, PLASMABALL_NAME)
    set_entvar(iEnt, var_solid, SOLID_TRIGGER)
    set_entvar(iEnt, var_movetype, MOVETYPE_FLYMISSILE)
    set_entvar(iEnt, var_owner, iAttacker)
    
    static const Float:vMins[3] = {-2.0, -2.0, -2.0}
    static const Float:vMaxs[3] = {2.0, 2.0, 2.0}
    engfunc(EngFunc_SetSize, iEnt, vMins, vMaxs)
    
    set_entvar(iEnt, var_velocity, vSpeed)
}

public fw_PlasmaBall_Touch_Post(const iEnt, const iOther) {
    if (!FClassnameIs(iEnt, PLASMABALL_NAME)) 
        return
        
    static Float:vOrigin[3]
    get_entvar(iEnt, var_origin, vOrigin)
    
    // Explosion.
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, vOrigin)
    write_byte(TE_EXPLOSION)            // TE id.
    write_coord_f(vOrigin[0])           // Position X.
    write_coord_f(vOrigin[1])           // Position Y.
    write_coord_f(vOrigin[2])           // Position Z.
    write_short(g_iExploSpr)            // Sprite Index.
    write_byte(5)                       // Scale.
    write_byte(random_num(8, 16))       // Framerate.
    write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND) // Flags.
    message_end()
    
    static Float:vSpeed[3], iVictim, iAttacker
    iAttacker = get_entvar(iEnt, var_owner)
    iVictim = NULLENT
    
    while ((iVictim = engfunc(EngFunc_FindEntityInSphere, iVictim, vOrigin, PLASMABALL_RADIUS))) {
        if (is_nullent(iVictim)) 
            continue
            
        if (fIsClient(iVictim)) {
            if (is_user_alive(iVictim) && ze_is_user_zombie(iVictim)) {
                get_entvar(iVictim, var_velocity, vSpeed)
                xs_vec_mul_scalar(vSpeed, g_flSlowdown, vSpeed)
                set_entvar(iVictim, var_velocity, vSpeed)
                
                // Damage victim.
                ExecuteHam(Ham_TakeDamage, iVictim, iEnt, iAttacker, PLASMABALL_DAMAGE, PLASMABALL_DMGTYPE)
            }
        } else {
            // Damage entity.
            if (get_entvar(iVictim, var_health) > 0.0 && get_entvar(iVictim, var_takedamage) != DAMAGE_NO) {
                ExecuteHamB(Ham_TakeDamage, iVictim, iEnt, iAttacker, PLASMABALL_DAMAGE, DMG_GENERIC)
            }
        }
    }
    
    emit_sound(iEnt, CHAN_WEAPON, g_szPlasmaBallSound, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
    rg_remove_entity(iEnt) // Free edict.
}

WeaponList(const id, const iMode = 0) {
    message_begin(MSG_ONE, g_iMsgWeaponList, .player = id)
    write_string(iMode ? WEAPON_NAME : WEAPON_REFERENCE)
    write_byte(8)
    write_byte(35)
    write_byte(-1)
    write_byte(-1)
    write_byte(1)
    write_byte(1)
    write_byte(WEAPON_ID)
    write_byte(0)
    message_end()
}
