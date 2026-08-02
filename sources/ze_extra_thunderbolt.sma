#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>
#include <ze_core>
#include <cstrike>

#define fIsClient(%1) (1 <= (%1) <= MaxClients)
#define fIsThunderbolt(%1) (bool:(is_entity(%1) && get_entvar(%1, var_impulse) == WEAPON_UID))

// ZE Config
new const ZE_ITEM_NAME[] = "Thunderbolt"
const ZE_ITEM_COST = 40
const ZE_ITEM_LIMIT = 1

// Weapon Settings
new const WEAPON_REFERENCE[] = "weapon_awp"
const WEAPON_ID = CSW_AWP
const WEAPON_UID = 4234234
const Float:WEAPON_DAMAGE = 600.0
const Float:RELOAD_TIME = 2.67

// Custom Animations
enum (+=1) {
    ANIM_IDLE = 0,
    ANIM_SHOOT,
    ANIM_DRAW
}

// Models & Sounds
new g_v_szModel[] = "models/ozzy_extras/v_thunder_ecl.mdl"
new g_p_szModel[] = "models/p_sfsniper.mdl"
new g_w_szModel[] = "models/w_sfsniper.mdl"

new const g_szWeaponSounds[][] = {
    "weapons/sfsniper-1.wav",     // 0: Shot
    "weapons/sfsniper_zoom.wav"   // 1: Zoom in
}

new g_iItemID, g_iBeamSpr, g_iEventAwp
new Float:g_vStartOrigin[3], Float:g_vEndOrigin[3]

// Cache por jogador
new bool:g_bHasThunderbolt[33]
new bool:g_bScoped[33]

public plugin_precache() {
    precache_model(g_v_szModel)
    precache_model(g_p_szModel)
    precache_model(g_w_szModel)
    precache_sound(g_szWeaponSounds[0])
    precache_sound(g_szWeaponSounds[1])
    g_iBeamSpr = precache_model("sprites/laserbeam.spr")

    register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[]) {
    if (equal("events/awp.sc", name)) {
        g_iEventAwp = get_orig_retval()
    }
}

public plugin_init() {
    register_plugin("[ZE] Thunderbolt Red Laser", "9.2", "Dias / Refactored")

    // ReAPI Hooks
    RegisterHookChain(RG_CWeaponBox_SetModel, "fw_WeaponBox_SetModel_Pre")
    RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "fw_Weapon_DefaultDeploy_Pre")

    // Ham Hooks
    RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_PrimaryAttack_Pre")
    RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_REFERENCE, "fw_PrimaryAttack_Post", 1)
    RegisterHam(Ham_Item_Holster, WEAPON_REFERENCE, "fw_Thunderbolt_Holster_Pre", 0)
    RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Pre")
    RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_Pre")

    // Engine / Fakemeta
    register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
    register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")

    // ZE Register
    g_iItemID = ze_item_register(ZE_ITEM_NAME, ZE_ITEM_COST, ZE_ITEM_LIMIT)
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2) {
    if (eventid == g_iEventAwp && fIsClient(invoker) && g_bHasThunderbolt[invoker]) {
        return FMRES_SUPERCEDE
    }
    return FMRES_IGNORED
}

public client_disconnected(id) {
    g_bHasThunderbolt[id] = false
    g_bScoped[id] = false
}

public ze_select_item_pre(id, itemid, bool:bIgnoreCost, bool:bInMenu) {
    if (itemid != g_iItemID)
        return ZE_ITEM_AVAILABLE

    if (ze_is_user_zombie(id))
        return ZE_ITEM_DONT_SHOW

    return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, iItem, bool:bIgnoreCost) {
    if (iItem == g_iItemID && is_user_alive(id) && !ze_is_user_zombie(id)) {
        new iWeapon = rg_give_custom_item(id, WEAPON_REFERENCE, GT_DROP_AND_REPLACE, WEAPON_UID)
        if (!is_nullent(iWeapon)) {
            set_member(iWeapon, m_Weapon_iClip, 10)
            rg_set_user_bpammo(id, WEAPON_ID, 30)
        }
    }
}

public fw_Weapon_DefaultDeploy_Pre(const iItem, const szViewModel[], const szWeaponModel[], iAnim, const szAnimExt[], skiplocal) {
    if (is_nullent(iItem))
        return

    new bool:bIsThunderbolt = fIsThunderbolt(iItem)

    new id = get_member(iItem, m_pPlayer)
    if (fIsClient(id)) {
        g_bHasThunderbolt[id] = bIsThunderbolt
        g_bScoped[id] = false
    }

    if (bIsThunderbolt) {
        SetHookChainArg(2, ATYPE_STRING, g_v_szModel)
        SetHookChainArg(3, ATYPE_STRING, g_p_szModel)
        SetHookChainArg(4, ATYPE_INTEGER, ANIM_DRAW)
    }
}

// Roda no PRE do Holster para garantir que o zoom seja cancelado ANTES da arma sumir da mão
public fw_Thunderbolt_Holster_Pre(const iItem) {
    if (is_nullent(iItem) || !fIsThunderbolt(iItem))
        return HAM_IGNORED

    new id = get_member(iItem, m_pPlayer)
    if (fIsClient(id) && is_user_alive(id)) {
        g_bScoped[id] = false
        cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
        set_entvar(id, var_fov, 90.0)
    }
    return HAM_IGNORED
}

public fw_WeaponBox_SetModel_Pre(const iEnt, const szModel[]) {
    if (!is_nullent(iEnt) && fIsThunderbolt(get_member(iEnt, m_WeaponBox_rgpPlayerItems, 1))) {
        SetHookChainArg(2, ATYPE_STRING, g_w_szModel)
    }
}

public fw_UpdateClientData_Post(const id, sendweapons, cd_handle) {
    if (!g_bHasThunderbolt[id] || !is_user_alive(id))
        return FMRES_IGNORED

    new iItem = get_member(id, m_pActiveItem)
    
    // Se a arma em mãos NÃO for a Thunderbolt, zera qualquer resíduo de zoom
    if (is_nullent(iItem) || !fIsThunderbolt(iItem)) {
        if (g_bScoped[id]) {
            g_bScoped[id] = false
            cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
            set_entvar(id, var_fov, 90.0)
        }
        return FMRES_IGNORED
    }

    new bool:bScoped = (get_member(id, m_iFOV) < 90)
    if (bScoped != g_bScoped[id]) {
        g_bScoped[id] = bScoped
        set_entvar(id, var_viewmodel, bScoped ? "" : g_v_szModel)

        if (bScoped) {
            rh_emit_sound2(id, 0, CHAN_ITEM, g_szWeaponSounds[1], VOL_NORM, ATTN_NORM)
        }
    }
    return FMRES_IGNORED
}

public fw_PrimaryAttack_Pre(const iItem) {
    if (!fIsThunderbolt(iItem))
        return

    rg_weapon_send_animation(iItem, ANIM_SHOOT)
}

public fw_PrimaryAttack_Post(const iItem) {
    if (!fIsThunderbolt(iItem))
        return

    new id = get_member(iItem, m_pPlayer)

    rh_emit_sound2(id, 0, CHAN_WEAPON, g_szWeaponSounds[0], VOL_NORM, ATTN_NORM)

    set_member(iItem, m_Weapon_iClip, 10)
    rg_set_user_bpammo(id, WEAPON_ID, 30)

    set_member(id, m_flNextAttack, RELOAD_TIME)
    set_member(iItem, m_Weapon_flNextPrimaryAttack, RELOAD_TIME)
    set_member(iItem, m_Weapon_flNextSecondaryAttack, RELOAD_TIME)
    set_member(iItem, m_Weapon_flTimeWeaponIdle, RELOAD_TIME + 0.5)

    Stock_Get_Position(id, 50.0, 10.0, -5.0, g_vStartOrigin)

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMPOINTS)
    write_coord_f(g_vStartOrigin[0])
    write_coord_f(g_vStartOrigin[1])
    write_coord_f(g_vStartOrigin[2])
    write_coord_f(g_vEndOrigin[0])
    write_coord_f(g_vEndOrigin[1])
    write_coord_f(g_vEndOrigin[2])
    write_short(g_iBeamSpr)
    write_byte(0)
    write_byte(0)
    write_byte(2)
    write_byte(15)
    write_byte(0)
    write_byte(255)
    write_byte(0)
    write_byte(0)
    write_byte(200)
    write_byte(0)
    message_end()
}

public fw_TraceAttack_Pre(iVictim, iAttacker, Float:flDamage, Float:vDir[3], tr, iDamageType) {
    if (!fIsClient(iAttacker) || !g_bHasThunderbolt[iAttacker] || !is_user_alive(iAttacker))
        return HAM_IGNORED

    new iItem = get_member(iAttacker, m_pActiveItem)
    if (!fIsThunderbolt(iItem))
        return HAM_IGNORED

    get_tr2(tr, TR_vecEndPos, g_vEndOrigin)
    SetHamParamFloat(3, WEAPON_DAMAGE)
    return HAM_HANDLED
}

stock Stock_Get_Position(id, Float:forw, Float:right, Float:up, Float:vStart[]) {
    new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]

    get_entvar(id, var_origin, vOrigin)
    get_entvar(id, var_view_ofs, vUp)
    xs_vec_add(vOrigin, vUp, vOrigin)
    get_entvar(id, var_v_angle, vAngle)

    angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward)
    angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
    angle_vector(vAngle, ANGLEVECTOR_UP, vUp)

    vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
    vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
    vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}
