#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <ze_core> 

#pragma semicolon 1

#define PLUGIN "Janus 1 + Custom Crosshair Final"
#define VERSION "1.3"
#define AUTHOR "m4m3ts & Dev"

#define CSW_JANUS1 CSW_FIVESEVEN
#define weapon_janus1 "weapon_fiveseven"
#define model_lama "models/w_fiveseven.mdl"
#define RAHASIA 41546

#define AMMO 15
#define RELOAD_TIME 3.0
#define TIME_STAB 1.5
#define ATTACK_TIME 3.0
#define SHOOT_TIME 0.5
#define SHOOT_B_TIME 0.4
#define DAMAGE 300.0
#define NAMACLASSNYA "janus1"

const OFFSET_LINUX_WEAPONS = 4;
const m_flNextAttack = 83;

new const v_model[] = "models/ozzy_extras/v_janus1.mdl";
new const p_model[] = "models/p_janus1.mdl";
new const w_model[] = "models/w_janus1.mdl";
new const GRENADE_MODEL[] = "models/grenade.mdl";
new const GRENADE_EXPLOSION[] = "sprites/fexplo.spr";

new cvar_dmg_janus1, cvar_ammo_janus1;

new const weapon_sound[7][] = 
{
    "weapons/janus1-1.wav",
    "weapons/janus1-2.wav",
    "weapons/janus1_exp.wav",
    "weapons/janus1_draw.wav",
    "weapons/janus1_change1.wav",
    "weapons/janus1_change2.wav",
    "weapons/m79_draw.wav"
};

new const WeaponResource[5][] = 
{
    "sprites/weapon_janus1.txt",
    "sprites/640hud7_2.spr",
    "sprites/640hud12_2.spr",
    "sprites/640hud100_2.spr",
    "sprites/scope_vip_grenade.spr"
};

enum
{
    ANIM_IDLE = 0,
    ANIM_DRAW_NORMAL,
    ANIM_SHOOT_NORMAL,
    ANIM_SHOOT_ABIS,
    ANIM_SHOOT_SIGNAL,
    ANIM_CHANGE_1,
    ANIM_IDLE_B,
    ANIM_DRAW_B,
    ANIM_SHOOT_B,
    ANIM_SHOOT_B2,
    ANIM_CHANGE_2,
    ANIM_SIGNAL,
    ANIM_DRAW_SIGNAL,
    ANIM_SHOOT2_SIGNAL
};

new sExplo;
new g_had_janus1[33], g_janus_ammo[33], shoot_mode[33], hit_janus1[33], hit_on[33];
new bool:g_givingJanus[33]; // true enquanto get_janus1() está entregando a arma, evita falso positivo de "comprou fiveseven"
new bool:g_bCrosshairHidden[33]; // estado REAL, ja confirmado, da flag HIDEHUD_CROSSHAIR no client
new sTrail, g_MaxPlayers, item_janus1;

new g_msgHideWeapon, g_msgWeaponList, g_msgSetFOV, g_msgCurWeapon;

const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_cvar("janus1_version", "m4m3ts", FCVAR_SERVER|FCVAR_SPONLY);
    register_forward(FM_CmdStart, "fw_CmdStart");
    register_forward(FM_SetModel, "fw_SetModel");
    register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1);
    register_message(get_user_msgid("DeathMsg"), "message_DeathMsg");
    register_think(NAMACLASSNYA, "fw_Think");
    register_touch(NAMACLASSNYA, "*", "fw_touch");
    RegisterHam(Ham_Spawn, "player", "Player_Spawn", 1);
    RegisterHam(Ham_Killed, "player", "fw_PlayerKilled");
    RegisterHam(Ham_Item_AddToPlayer, weapon_janus1, "fw_AddToPlayer_Pre");
    RegisterHam(Ham_Item_AddToPlayer, weapon_janus1, "fw_AddToPlayer_Post", 1);
    RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus1, "fw_janusidleanim", 1);
    register_event("CurWeapon", "Event_CurWeapon", "be", "1=1");
    
    g_MaxPlayers = get_maxplayers();
    register_clcmd("weapon_janus1", "hook_weapon");
    
    item_janus1 = ze_item_register("Janus-1", 10, 1);
    cvar_dmg_janus1 = register_cvar("ze_janus1_dmg", "300.0");
    cvar_ammo_janus1 = register_cvar("ze_janus1_ammo", "250");

    g_msgHideWeapon = get_user_msgid("HideWeapon");
    g_msgWeaponList = get_user_msgid("WeaponList");
    g_msgSetFOV     = get_user_msgid("SetFOV");
    g_msgCurWeapon  = get_user_msgid("CurWeapon");

    // Hookamos a mensagem para interceptar e bloquear quando o CS tentar resetar a arma para FiveSeven
    register_message(g_msgWeaponList, "message_WeaponList");
}

public client_disconnected(id)
{
    g_had_janus1[id] = 0;
    g_janus_ammo[id] = 0;
    g_bCrosshairHidden[id] = false;
}

public plugin_precache()
{
    precache_model(v_model);
    precache_model(p_model);
    precache_model(w_model);
    precache_model(GRENADE_MODEL);
    sExplo = precache_model(GRENADE_EXPLOSION);
    
    for(new i = 0; i < sizeof(weapon_sound); i++) 
        precache_sound(weapon_sound[i]);
    
    precache_generic(WeaponResource[0]);
    for(new i = 1; i < sizeof(WeaponResource); i++)
        precache_model(WeaponResource[i]);
    
    sTrail = precache_model("sprites/laserbeam.spr");
}

public ze_select_item_pre(id, itemid, bool:ignorecost, bool:inmenu)
{
    if(itemid != item_janus1)
        return ZE_ITEM_AVAILABLE;

    if(ze_is_user_zombie(id))
        return ZE_ITEM_DONT_SHOW;

    return ZE_ITEM_AVAILABLE;
}

public ze_select_item_post(id, itemid, bool:ignorecost)
{
    if(itemid != item_janus1)
        return;

    if(!is_user_alive(id) || ze_is_user_zombie(id))
        return;

    get_janus1(id);
}

public ze_user_humanized(id)
{
    remove_janus(id);
}

public ze_user_infected(iVictim, iInfector)
{
    remove_janus(iVictim);
}

public Player_Spawn(id)
{
    static ent;
    ent = fm_get_user_weapon_entity(id, CSW_JANUS1);

    if (pev_valid(ent) && pev(ent, pev_impulse) == RAHASIA)
    {
        g_had_janus1[id] = 1;

        if (g_janus_ammo[id] <= 0)
            g_janus_ammo[id] = get_pcvar_num(cvar_ammo_janus1);

        if (!shoot_mode[id])
            shoot_mode[id] = 1;

        hit_janus1[id] = 0;
        hit_on[id] = 0;

        if (get_user_weapon(id) == CSW_JANUS1)
        {
            set_pev(id, pev_viewmodel2, v_model);
            set_pev(id, pev_weaponmodel2, p_model);
            Apply_Janus_Crosshair(id);
        }
        return;
    }
    remove_janus(id);
}

public fw_PlayerKilled(id)
{
    remove_janus(id);
}

public hook_weapon(id)
{
    engclient_cmd(id, weapon_janus1);
    return;
}

public get_janus1(id)
{
    if(!is_user_alive(id))
        return;
    drop_weapons(id, 1);
    g_had_janus1[id] = 1;
    g_janus_ammo[id] = get_pcvar_num(cvar_ammo_janus1);
    shoot_mode[id] = 1;
    hit_janus1[id] = 0;
    hit_on[id] = 0;

    g_givingJanus[id] = true;
    give_item(id, weapon_janus1);
    g_givingJanus[id] = false;
    if(get_user_weapon(id) == CSW_JANUS1 && g_had_janus1[id]) 
    {
        Apply_Janus_Crosshair(id);
    }

    static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_janus1, id);
    if(pev_valid(weapon_ent))
    {
        cs_set_weapon_ammo(weapon_ent, 1);
        set_pev(weapon_ent, pev_impulse, RAHASIA);
    }
}

public remove_janus(id)
{
    if (g_had_janus1[id] && is_user_connected(id))
    {
        Reset_Janus_Crosshair(id);
    }
    g_had_janus1[id] = 0;
    g_janus_ammo[id] = 0;
}
    
public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
    if(!is_user_alive(id) || !is_user_connected(id))
        return FMRES_IGNORED;    
    if(get_user_weapon(id) == CSW_JANUS1 && g_had_janus1[id])
        set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001); 

    // Rede de seguranca: roda todo frame e garante que HIDEHUD_CROSSHAIR
    // sempre reflete a realidade (Janus1 ativa ou nao), mesmo se algum
    // ponto de troca de arma/respawn/round-restart passar batido. So manda
    // mensagem quando o estado muda (via set_janus_crosshair_hidden), entao
    // nao pesa. As trocas "normais" (equipar/desequipar) ja setam a flag
    // na hora certa direto em Apply_Janus_Crosshair/Reset_Janus_Crosshair;
    // isso aqui so cobre os casos que escapam disso.
    set_janus_crosshair_hidden(id, bool:(g_had_janus1[id] && get_user_weapon(id) == CSW_JANUS1));
    
    return FMRES_HANDLED;
}

// Unico ponto que manda a mensagem HideWeapon para a flag HIDEHUD_CROSSHAIR.
// So envia quando o estado realmente muda - evita spam e mantem
// Apply_Janus_Crosshair/Reset_Janus_Crosshair e a auto-correcao em
// fw_UpdateClientData_Post sempre em sincronia sem duplicar mensagens.
stock set_janus_crosshair_hidden(id, bool:hide)
{
    if (hide == g_bCrosshairHidden[id])
        return;

    g_bCrosshairHidden[id] = hide;

    message_begin(MSG_ONE, g_msgHideWeapon, .player = id);
    write_byte(hide ? (1<<6) : 0);
    message_end();
}

public message_DeathMsg(msg_id, msg_dest, id)
{
    static szTruncatedWeapon[33], iAttacker, iVictim;
        
    get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon));
        
    iAttacker = get_msg_arg_int(1);
    iVictim = get_msg_arg_int(2);
        
    if(!is_user_connected(iAttacker) || iAttacker == iVictim) return PLUGIN_CONTINUE;
        
    if(get_user_weapon(iAttacker) == CSW_JANUS1)
    {
        if(g_had_janus1[iAttacker])
            set_msg_arg_string(4, "grenade");
    }
                
    return PLUGIN_CONTINUE;
}

// Bloqueia e substitui qualquer tentativa do motor do jogo de forçar a interface padrão da FiveSeven
public message_WeaponList(msg_id, msg_dest, id)
{
    if(!is_user_connected(id))
        return PLUGIN_CONTINUE;

    static weapon_name[32];
    get_msg_arg_string(1, weapon_name, charsmax(weapon_name));

    // Correção: Só intercepta e transforma em Janus se o jogador REALMENTE possuir a Janus ativa
    if(equal(weapon_name, "weapon_fiveseven"))
    {
        if(g_had_janus1[id] && get_user_weapon(id) == CSW_JANUS1)
        {
            set_msg_arg_string(1, "weapon_janus1");
            set_msg_arg_int(8, ARG_BYTE, CSW_JANUS1);
            return PLUGIN_HANDLED;
        }
    }
    return PLUGIN_CONTINUE;
}

public Event_CurWeapon(id)
{
    if(!is_user_alive(id))
        return;
        
    new current_weapon = get_user_weapon(id);
        
    if(current_weapon == CSW_JANUS1 && g_had_janus1[id])
    {
        set_pev(id, pev_viewmodel2, v_model);
        set_pev(id, pev_weaponmodel2, p_model);
        if(shoot_mode[id] == 1) set_weapon_anim(id, ANIM_DRAW_NORMAL);
        if(shoot_mode[id] == 2) set_weapon_anim(id, ANIM_DRAW_SIGNAL);
        if(shoot_mode[id] == 3) set_weapon_anim(id, ANIM_DRAW_B);
        
        Apply_Janus_Crosshair(id);
    }
    else if (g_had_janus1[id])
    {
        Reset_Janus_Crosshair(id);
    }
}

public fw_CmdStart(id, uc_handle, seed)
{
    if(!is_user_alive(id) || !is_user_connected(id))
        return;
    if(get_user_weapon(id) != CSW_JANUS1 || !g_had_janus1[id])
        return;
    
    static ent; ent = fm_get_user_weapon_entity(id, CSW_JANUS1);
    if(!pev_valid(ent))
        return;
    if(get_pdata_float(ent, 46, OFFSET_LINUX_WEAPONS) > 0.0 || get_pdata_float(ent, 47, OFFSET_LINUX_WEAPONS) > 0.0) 
        return;
    
    static CurButton;
    CurButton = get_uc(uc_handle, UC_Buttons);
    
    if(CurButton & IN_ATTACK)
    {
        CurButton &= ~IN_ATTACK;
        set_uc(uc_handle, UC_Buttons, CurButton);
            
        // Modo normal: nunca esvazia o pente, sempre atira e reabastece na hora (igual thunderbolt_shoothandle)
        if(shoot_mode[id] == 1 && get_pdata_float(id, 83, 5) <= 0.0)
        {
            set_weapon_anim(id, ANIM_SHOOT_NORMAL);
            Firejanus1(id);
            peluru_hud(id);
            emit_sound(id, CHAN_WEAPON, weapon_sound[0], 1.0, ATTN_NORM, 0, PITCH_NORM);
            set_weapons_timeidle(id, CSW_JANUS1, ATTACK_TIME);
            set_player_nextattackx(id, ATTACK_TIME);
        }
        if(shoot_mode[id] == 3 && get_pdata_float(id, 83, 5) <= 0.0)
        {
            set_weapon_anim(id, ANIM_SHOOT_B2);
            Firejanus1(id);
            emit_sound(id, CHAN_WEAPON, weapon_sound[1], 1.0, ATTN_NORM, 0, PITCH_NORM);
            set_weapons_timeidle(id, CSW_JANUS1, SHOOT_B_TIME);
            set_player_nextattackx(id, SHOOT_B_TIME);
        }
    }
    else if(CurButton & IN_ATTACK2)
    {
        if(shoot_mode[id] == 2)
        {
            set_weapon_anim(id, ANIM_CHANGE_1);
            shoot_mode[id] = 3;
            peluru_hud(id);
            set_task(8.5, "back_normal", id);
            set_task(8.5, "back_normal2", id);
            set_weapons_timeidle(id, CSW_JANUS1, TIME_STAB);
            set_player_nextattackx(id, TIME_STAB);
        }
    }
}

public back_normal(id)
{
    if(get_user_weapon(id) != CSW_JANUS1 || !g_had_janus1[id])
        return;
        
    set_weapon_anim(id, ANIM_CHANGE_2);
    emit_sound(id, CHAN_WEAPON, weapon_sound[5], 1.0, ATTN_NORM, 0, PITCH_NORM);
    set_weapons_timeidle(id, CSW_JANUS1, TIME_STAB);
    set_player_nextattackx(id, TIME_STAB);
    peluru_hud(id);
}

public back_normal2(id)
{
    shoot_mode[id] = 1;
    hit_janus1[id] = 0;
}

public ready_transform(id)
{
    shoot_mode[id] = 2;
    set_weapons_timeidle(id, CSW_JANUS1, TIME_STAB);
    set_player_nextattackx(id, TIME_STAB);
}

public fw_janusidleanim(Weapon)
{
    new id = get_pdata_cbase(Weapon, 41, 4);

    if(!is_user_alive(id) || ze_is_user_zombie(id) || !g_had_janus1[id] || get_user_weapon(id) != CSW_JANUS1)
        return HAM_IGNORED;

    if(shoot_mode[id] == 1) 
        return HAM_SUPERCEDE;
    
    if(shoot_mode[id] == 3 && get_pdata_float(Weapon, 48, 4) <= 0.25)
    {
        set_weapon_anim(id, ANIM_IDLE_B);
        set_pdata_float(Weapon, 48, 20.0, 4);
        return HAM_SUPERCEDE;
    }
    
    if(shoot_mode[id] == 2 && get_pdata_float(Weapon, 48, 4) <= 0.25) 
    {
        set_weapon_anim(id, ANIM_SIGNAL);
        set_pdata_float(Weapon, 48, 20.0, 4);
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public Firejanus1(id)
{
    new Float:Origin[3], Float:Angles[3];
    new Float:Velocity[3], Float:TargetOrigin[3];

    get_weapon_attachment(id, Origin, 24.0);
    pev(id, pev_v_angle, Angles);

    new ent = create_entity("info_target");

    if(!pev_valid(ent))
        return PLUGIN_CONTINUE;

    set_pev(ent, pev_classname, NAMACLASSNYA);
    set_pev(ent, pev_solid, SOLID_BBOX);
    set_pev(ent, pev_movetype, MOVETYPE_PUSHSTEP);

    set_pev(ent, pev_mins, Float:{ -0.1, -0.1, -0.1 });
    set_pev(ent, pev_maxs, Float:{ 0.1, 0.1, 0.1 });

    entity_set_model(ent, GRENADE_MODEL);

    set_pev(ent, pev_origin, Origin);
    set_pev(ent, pev_angles, Angles);
    set_pev(ent, pev_owner, id);

    fm_get_aim_origin(id, TargetOrigin);
    get_speed_vector(Origin, TargetOrigin, 1350.0, Velocity);

    set_pev(ent, pev_velocity, Velocity);

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BEAMFOLLOW);
    write_short(ent);
    write_short(sTrail);
    write_byte(10);
    write_byte(3);
    write_byte(255);
    write_byte(255);
    write_byte(255);
    write_byte(50);
    message_end();

    return PLUGIN_CONTINUE;
}

public fw_touch(ptr, ptd)
{
    if (pev_valid(ptr))
    {
            new Float:originF[3];
            pev(ptr, pev_origin, originF);
            engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0);
            write_byte(TE_WORLDDECAL);
            engfunc(EngFunc_WriteCoord, originF[0]);
            engfunc(EngFunc_WriteCoord, originF[1]);
            engfunc(EngFunc_WriteCoord, originF[2]);
            write_byte(engfunc(EngFunc_DecalIndex,"{scorch3"));
            message_end();

            message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
            write_byte(TE_EXPLOSION); 
            engfunc(EngFunc_WriteCoord, originF[0]); 
            engfunc(EngFunc_WriteCoord, originF[1]);
            engfunc(EngFunc_WriteCoord, originF[2]+30.0);
            write_short(sExplo); 
            write_byte(35); 
            write_byte(35); 
            write_byte(0); 
            message_end();
            emit_sound(ptr, CHAN_WEAPON, weapon_sound[2], 1.0, ATTN_NORM, 0, PITCH_NORM);
            
            Damage_janus1(ptr, ptd);
            
            engfunc(EngFunc_RemoveEntity, ptr);
    }
}

public Damage_janus1(ptr, ptd)
{
    static Owner; Owner = pev(ptr, pev_owner);
    static Attacker;
    if(!is_user_alive(Owner)) 
    {
        Attacker = 0;
        return;
    } else Attacker = Owner;
        
    for(new i = 0; i < g_MaxPlayers; i++)
    {
        if(!is_user_alive(i))
            continue;
        if(entity_range(i, ptr) > 200.0)
            continue;
        if(!ze_is_user_zombie(i))
            continue;
            
        ExecuteHamB(Ham_TakeDamage, i, 0, Attacker, get_pcvar_float(cvar_dmg_janus1), DMG_BULLET);
        hit_on[Attacker] = 1;
    }
    
    if(hit_on[Attacker] && hit_janus1[Attacker] < 11)
    {
        hit_janus1[Attacker] ++;
        hit_on[Attacker] = 0;
    }
    
    if(hit_janus1[Attacker] == 10 && shoot_mode[Attacker] == 1) set_task(0.5, "ready_transform", Attacker);
}

public fw_SetModel(entity, model[])
{
    if(!pev_valid(entity))
        return FMRES_IGNORED;
    
    static Classname[64];
    pev(entity, pev_classname, Classname, sizeof(Classname));
    
    if(!equal(Classname, "weaponbox"))
        return FMRES_IGNORED;
    
    static id;
    id = pev(entity, pev_owner);
    
    if(equal(model, model_lama))
	{
		static weapon;
		// No momento em que a engine chama SetModel na weaponbox, a arma já foi
		// empacotada dentro dela (pev_owner da arma passa a ser a própria caixa,
		// não mais o jogador) — por isso buscamos pelo dono = entity (a box).
		weapon = fm_find_ent_by_owner(-1, weapon_janus1, entity);
		if(!pev_valid(weapon))
			weapon = fm_get_user_weapon_entity(id, CSW_JANUS1); // fallback de segurança

		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(g_had_janus1[id])
		{
			set_pev(weapon, pev_impulse, RAHASIA);
			set_pev(weapon, pev_iuser4, g_janus_ammo[id]);
			engfunc(EngFunc_SetModel, entity, w_model); // força o model w_ do Janus na weaponbox
			
			remove_janus(id); // dropou no chão -> remove o estado do Janus só de quem dropou
			
			return FMRES_SUPERCEDE;
		}
	}
    return FMRES_IGNORED;
}

public fw_AddToPlayer_Pre(ent, id)
{
    if(pev(ent, pev_impulse) != RAHASIA && g_had_janus1[id] && !g_givingJanus[id])
    {
        // Comprou/recebeu uma FiveSeven de verdade -> remove o Janus JÁ, antes do jogo
        // processar a entrega e mandar o WeaponList (senão o ícone da Janus fica preso no HUD)
        remove_janus(id);
    }
    return HAM_IGNORED;
}

public fw_AddToPlayer_Post(ent, id)
{
    if(pev(ent, pev_impulse) == RAHASIA)
    {
        g_had_janus1[id] = 1;
        g_janus_ammo[id] = pev(ent, pev_iuser4);
        if(!shoot_mode[id]) shoot_mode[id] = 1; // garante um modo de tiro válido pra quem pegou do chão
        hit_janus1[id] = 0;
        hit_on[id] = 0;

        // Pegou a arma do chão -> garante que ela já apareça "carregada" no HUD
        // (senão só corrige quando o jogador troca pra ela e passa pelo peluru_hud)
        cs_set_weapon_ammo(ent, 1);
        cs_set_user_bpammo(id, CSW_FIVESEVEN, 0);
    }

    if (get_user_weapon(id) == CSW_JANUS1 && g_had_janus1[id])
    {
        Apply_Janus_Crosshair(id);
    }
}

public peluru_hud(id)
{
    if(!is_user_alive(id))
        return;
    
    static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_janus1, id);
    if(pev_valid(weapon_ent)) cs_set_weapon_ammo(weapon_ent, 1);    
    
    cs_set_user_bpammo(id, CSW_FIVESEVEN, 0);
    
    // Refaz o toggle de FOV para forçar o redesenho da mira customizada a cada tiro (senão ela some)
    message_begin(MSG_ONE, g_msgSetFOV, .player = id);
    write_byte(89);
    message_end();
    
    // Casado em paridade idêntica com o funcionamento estrutural do seu menu de miras (Canal técnico 2)
    message_begin(MSG_ONE, g_msgCurWeapon, .player = id);
    write_byte(1);
    write_byte(CSW_JANUS1); 
    write_byte(g_janus_ammo[id]);
    message_end();
    
    message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id);
    write_byte(1);
    write_byte(g_janus_ammo[id]);
    message_end();

    message_begin(MSG_ONE, g_msgSetFOV, .player = id);
    write_byte(90);
    message_end();
}

Apply_Janus_Crosshair(const id)
{
    // Força o arquivo weapon_janus1.txt mapeando o slot correto no canal 2
    message_begin(MSG_ONE, g_msgWeaponList, .player = id); {
        write_string("weapon_janus1"); 
        write_byte(1);   
        write_byte(100); 
        write_byte(-1);  
        write_byte(-1);  
        write_byte(1);   
        write_byte(6);   
        write_byte(CSW_JANUS1);   
        write_byte(0);   
    }
    message_end();

    // Precisa ser sincrono e ANTES do peluru_hud() abaixo: o truque de
    // redesenho (toggle de FOV) so mostra a mira customizada corretamente
    // se a flag ja estiver setada nesse exato momento - se depender so da
    // auto-correcao de fw_UpdateClientData_Post (que roda num ponto
    // diferente do frame), o redesenho acontece cedo demais e a mira só
    // aparece depois, no primeiro tiro.
    set_janus_crosshair_hidden(id, true);

    peluru_hud(id);
}

Reset_Janus_Crosshair(const id)
{
    if(!is_user_connected(id))
        return;

    // RESTAURAÇÃO: Envia a WeaponList original da FiveSeven para limpar o txt customizado
    message_begin(MSG_ONE, g_msgWeaponList, .player = id); {
        write_string("weapon_fiveseven"); // Nome original que o CS espera
        write_byte(1);                    // Primary Ammo Type
        write_byte(100);                  // Max Primary Ammo
        write_byte(-1);                   // Secondary Ammo Type
        write_byte(-1);                   // Max Secondary Ammo
        write_byte(1);                    // Slot (Pistols)
        write_byte(6);                    // Position na lista
        write_byte(CSW_FIVESEVEN);        // ID correto do item
        write_byte(0);                    // Flags
    }
    message_end();

    // Sincrono, igual no Apply_Janus_Crosshair - garante que o crosshair
    // padrao volta na hora, sem esperar o proximo frame de UpdateClientData.
    set_janus_crosshair_hidden(id, false);

    // CORREÇÃO: só forçamos CurWeapon/AmmoX quando a arma que está de fato na mão
    // do jogador é a FiveSeven/Janus. Sem esse check, ao trocar pra QUALQUER outra
    // arma (AK47, faca, granada...) essas duas mensagens sobrescreviam o HUD da arma
    // recém-equipada com o clip/reserva fantasma guardado da Janus (1/100 na primeira
    // troca, 1/0 nas seguintes, pois cs_set_user_bpammo(FIVESEVEN,0) já tinha zerado
    // a reserva armazenada).
    if(get_user_weapon(id) != CSW_FIVESEVEN)
        return;

    static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_janus1, id);
    if(pev_valid(weapon_ent))
    {
        new iClip = cs_get_weapon_ammo(weapon_ent);
        new iBpAmmo = cs_get_user_bpammo(id, CSW_FIVESEVEN);

        message_begin(MSG_ONE, g_msgCurWeapon, .player = id);
        write_byte(1);
        write_byte(CSW_FIVESEVEN);
        write_byte(iClip);
        message_end();

        message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id);
        write_byte(1);
        write_byte(iBpAmmo);
        message_end();
    }
}

stock set_weapon_anim(id, anim)
{
    if(!is_user_alive(id))
        return;
    
    set_pev(id, pev_weaponanim, anim);
    
    message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id);
    write_byte(anim);
    write_byte(pev(id, pev_body));
    message_end();
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
    new Float:vfEnd[3], viEnd[3];
    get_user_origin(id, viEnd, 3);  
    IVecFVec(viEnd, vfEnd); 
    
    new Float:fOrigin[3], Float:fAngle[3];
    
    pev(id, pev_origin, fOrigin); 
    pev(id, pev_view_ofs, fAngle);
    
    xs_vec_add(fOrigin, fAngle, fOrigin); 
    
    new Float:fAttack[3];
    
    xs_vec_sub(vfEnd, fOrigin, fAttack);
    xs_vec_sub(vfEnd, fOrigin, fAttack); 
    
    new Float:fRate;
    
    fRate = fDis / vector_length(fAttack);
    xs_vec_mul_scalar(fAttack, fRate, fAttack);
    
    xs_vec_add(fOrigin, fAttack, output);
}

stock drop_weapons(id, dropwhat)
{
    static weapons[32], num, i, weaponid;
    num = 0;
    get_user_weapons(id, weapons, num);
     
    for (i = 0; i < num; i++)
    {
        weaponid = weapons[i];
          
        if (dropwhat == 1 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM))
        {
            static wname[32];
            get_weaponname(weaponid, wname, sizeof wname - 1);
            engclient_cmd(id, "drop", wname);
        }
    }
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
    if(!is_user_alive(id))
        return;
        
    static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId);
    if(!pev_valid(entwpn)) 
        return;
        
    set_pdata_float(entwpn, 46, TimeIdle, OFFSET_LINUX_WEAPONS);
    set_pdata_float(entwpn, 47, TimeIdle, OFFSET_LINUX_WEAPONS);
    set_pdata_float(entwpn, 48, TimeIdle + 0.5, OFFSET_LINUX_WEAPONS);
}

stock set_player_nextattackx(id, Float:nexttime)
{
    if(!is_user_alive(id))
        return;
        
    set_pdata_float(id, m_flNextAttack, nexttime, 5);
}

stock get_speed_vector(const Float:origin1[3], const Float:origin2[3], Float:speed, Float:new_velocity[3])
{
    new_velocity[0] = origin2[0] - origin1[0];
    new_velocity[1] = origin2[1] - origin1[1];
    new_velocity[2] = origin2[2] - origin1[2];

    new Float:num = floatsqroot(
        speed * speed /
        (
            new_velocity[0] * new_velocity[0] +
            new_velocity[1] * new_velocity[1] +
            new_velocity[2] * new_velocity[2]
        )
    );

    new_velocity[0] *= num;
    new_velocity[1] *= num;
    new_velocity[2] *= num;

    return 1;
}
