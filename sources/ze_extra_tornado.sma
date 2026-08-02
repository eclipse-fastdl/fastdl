#include <amxmodx>
#include <ze_core>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <cstrike>

// Mofiying Plugin Info Will Violate CopyRight///
#define NAME "[ZE] Items: SF Tornado LaserGun"   /////
#define VERSION "1.1"					  /////
#define AUTHOR "ZinoZack47"				 /////
/////////////////////////////////////////////

#define WEAPONKEY_SFT 				283913147
#define CSW_SFT 					CSW_M4A1
#define weapon_sft 					"weapon_m4a1"

#define m_flNextAttack				83
#define m_flTimeWeaponIdle			48
#define m_flNextPrimaryAttack 		46
#define m_flNextSecondaryAttack		47
#define m_iClip						51
#define m_fInReload					54
#define m_fKnown					44
#define m_pActiveItem 				373

#define WEAPONOWNER_OFF 			41
#define WEAP_LINUX_XTRA_OFF			4
#define PLAYER_LINUX_XTRA_OFF		5

// Entity is the source of truth for "is this specific weapon_m4a1 a
// Tornado". Same pattern already used by the pev_impulse marker below;
// this macro just gives it a name for the extra defensive hooks.
#define IsSFTornadoEnt(%1) (pev_valid(%1) && pev(%1, pev_impulse) == WEAPONKEY_SFT)

enum (+= 47)
{
	SF_TASK_RESET = 7047,
	SF_TASK_BURN
}

enum
{
	IDLEA = 0,
	IDLEB,
	IDLEC,
	DRAWA,
	DRAWB,
	DRAWC,
	SHOOTA,
	SHOOTB,
	SHOOTC,
	SHOOTA_empty,
	SHOOTB_empty,
	SHOOTC_empty,
	SHOOT_ENDA,
	SHOOT_ENDB,
	SHOOT_ENDC,
	CHANGEA,
	CHANGEB,
	RELOADA,
	RELOADB,
	RELOADC
}

enum
{
	MODE_A = 0,
	MODE_B,
	MODE_C
}

new const SFTORNADO_V_MODEL[] = "models/ozzy_extras/v_sflaser.mdl"
new const SFTORNADO_P_MODEL[] = "models/p_sftornado.mdl"
new const SFTORNADO_W_MODEL[] = "models/w_sftornado.mdl"

new const SF_SOUNDS[][] =
{
	"weapons/sftornado-1_start.wav",
	"weapons/sftornado-1.wav",
	"weapons/sftornado-2.wav",
	"weapons/sftornado-3.wav",
	"weapons/sftornado_drawa.wav",
	"weapons/sftornado_drawc.wav",
	"weapons/sftornado_clipin.wav",
	"weapons/sftornado_clipout.wav",
	"weapons/sftornado_changeb.wav",
	"weapons/sftornado-shoot_end.wav"
}

new const SF_HUD[][] =
{
	"sprites/weapon_sftornado.txt",
	"sprites/640hud149.spr",
	"sprites/640hud17.spr" 
}

new g_beamSpr[3], g_elecSpr, g_gibsSpr, g_flameSpr
new g_current_mode[33], g_laser_counter[33], g_HitGroup[33]
new g_maxplayers, g_orig_event_sftornado, bool:g_primaryattack
new Float:cl_pushangle[33][3]
new g_has_sftornado[33], g_clip_ammo[33], g_sftornado_TmpClip[33], g_MsgWeaponList, g_MsgCurWeapon, g_BurnDur[33], Float:g_Delay[33][3], g_iItemID

const PRIMARY_WEAPONS_BIT_SUM =
(1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<
CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)

public plugin_init()
{
	register_plugin(NAME, VERSION, AUTHOR)
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")

	RegisterHam(Ham_Item_Deploy, weapon_sft, "fw_sftornado_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_sft, "fw_sftornado_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_sft, "fw_sftornado_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_sft, "fw_sftornado_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, weapon_sft, "fw_sftornado_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_sft, "fw_sftornado_Reload_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_sft, "fw_Item_AddToPlayer")
	RegisterHam(Ham_Item_Kill, weapon_sft, "fw_sftornado_ItemKill_Pre")
	RegisterHam(Ham_Spawn, weapon_sft, "fw_sftornado_Weapon_Spawn_Post", 1)
	RegisterHam(Ham_Spawn, "player", "fw_sftornado_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_sft, "fw_sftornado_WeaponIdle_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)

	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")

	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")

	g_iItemID = ze_item_register("SF Tornado LaserGun", 100, 1)

	register_clcmd("weapon_sftornado", "select_sft")
	g_maxplayers = get_maxplayers()
}

public plugin_precache()
{
	precache_model(SFTORNADO_V_MODEL)
	precache_model(SFTORNADO_P_MODEL)
	precache_model(SFTORNADO_W_MODEL)

	for(new i = 0; i < sizeof(SF_SOUNDS); i++)
		precache_sound(SF_SOUNDS[i])

	for(new i = 0; i < sizeof(SF_HUD); i++)
		precache_generic(SF_HUD[i])

	g_beamSpr[0] = precache_model("sprites/zbeam5.spr")
	g_beamSpr[1] = precache_model("sprites/zbeam3.spr")
	g_beamSpr[2] = precache_model("sprites/zbeam4.spr")

	g_flameSpr = precache_model("sprites/sf_laser_flame.spr")
	g_elecSpr = precache_model("sprites/sf_laser_ele.spr")
	g_gibsSpr = precache_model("sprites/sf_laser_break.spr")

	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public plugin_natives()
{
	register_native("give_weapon_sflaser", "native_give_weapon_sftornado", 1)
	register_native("remove_weapon_sftornado", "native_remove_weapon_sftornado", 1)
}

public Event_NewRound()
{
	for(new id = 0; id <= g_maxplayers; id++)
	{
		if(!g_has_sftornado[id])
			continue

		reset_sftornado_state(id, true, false)
	}
}

public client_disconnected(id)
{
	reset_sftornado_state(id, false)
}

public native_give_weapon_sftornado(id)
	give_sftornado(id)

public native_remove_weapon_sftornado(id)
	remove_sftornado(id)

public fw_PrecacheEvent_Post(type, const name[])
{
	new weapon[32], event_sft[64]
	
	copy(weapon, charsmax(weapon), weapon_sft)
	replace(weapon, charsmax(weapon), "weapon_", "")

	formatex(event_sft, charsmax(event_sft), "events/%s.sc", weapon)

	if (equal(event_sft, name))
	{
		g_orig_event_sftornado = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public select_sft(id)
{
	engclient_cmd(id, weapon_sft)
	return PLUGIN_HANDLED
}

public ze_user_infected(id, infector)
	remove_sftornado(id)

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED

	static classname[33], weapon[32], old_sft[64]
	pev(entity, pev_classname, classname, charsmax(classname))

	if(!equal(classname, "weaponbox"))
		return FMRES_IGNORED

	copy(weapon, charsmax(weapon), weapon_sft)
	replace(weapon, charsmax(weapon), "weapon_", "")

	formatex(old_sft, charsmax(old_sft), "models/w_%s.mdl", weapon)

	static owner
	owner = pev(entity, pev_owner)

	if(equal(model, old_sft))
	{
		static StoredWepID

		StoredWepID = fm_find_ent_by_owner(-1, weapon_sft, entity)

		if(!pev_valid(StoredWepID))
			return FMRES_IGNORED

		if(g_has_sftornado[owner])
		{
			set_pev(StoredWepID, pev_impulse, WEAPONKEY_SFT)

			remove_sftornado(owner)

			engfunc(EngFunc_SetModel, entity, SFTORNADO_W_MODEL)

			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public give_sftornado(id)
{
	drop_weapons(id, 1)
	
	g_has_sftornado[id] = true
	
	fm_give_item(id, weapon_sft)
	
	static wep
	wep = fm_get_user_weapon_entity(id, CSW_SFT)
	
	if(!pev_valid(wep))
		return

	set_pev(wep, pev_impulse, WEAPONKEY_SFT)
	cs_set_weapon_ammo(wep, 70)

	message_begin(MSG_ONE, g_MsgWeaponList, .player = id)
	write_string("weapon_sftornado")
	write_byte(4)
	write_byte(90)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(6)
	write_byte(CSW_SFT)
	write_byte(0)
	message_end()	
	
	message_begin(MSG_ONE, g_MsgCurWeapon, .player = id)
	write_byte(1)
	write_byte(CSW_SFT)
	write_byte(70)
	message_end()

	cs_set_user_bpammo(id, CSW_SFT, 255)
}

public remove_sftornado(id)
{
    if(!is_user_connected(id))
        return;

    message_begin(MSG_ONE, g_MsgWeaponList, .player = id)
    write_string("weapon_m4a1")
    write_byte(4)
    write_byte(90)
    write_byte(-1)
    write_byte(-1)
    write_byte(0)
    write_byte(6)
    write_byte(CSW_M4A1)
    write_byte(0)
    message_end();

    reset_sftornado_state(id, true);

    fm_strip_user_gun(id, CSW_SFT, weapon_sft);
}

public ze_select_item_pre(id, itemid)
{
	if (itemid != g_iItemID)
		return ZE_ITEM_AVAILABLE

	if (ze_is_user_zombie(id))
		return ZE_ITEM_DONT_SHOW

	return ZE_ITEM_AVAILABLE
}

public ze_select_item_post(id, itemid, bool:bIgnoreCost)
{
	if (itemid != g_iItemID)
		return

	give_sftornado(id)
}

public fw_Item_AddToPlayer(item, id)
{
	if(!pev_valid(item))
		return HAM_IGNORED

	if(g_has_sftornado[id] && cs_get_weapon_id(item) == CSW_SFT)
	{
		set_pev(item, pev_impulse, WEAPONKEY_SFT)
	}

	if(!pev_valid(item))
		return HAM_IGNORED

	switch(pev(item, pev_impulse))
	{
		case 0:
		{
			if(g_has_sftornado[id])
			{
				reset_sftornado_state(id, false)

				message_begin(MSG_ONE, g_MsgWeaponList, .player = id)
				write_string("weapon_m4a1")
				write_byte(4)
				write_byte(90)
				write_byte(-1)
				write_byte(-1)
				write_byte(0)
				write_byte(6)
				write_byte(CSW_SFT)
				write_byte(0)
				message_end()
			}
			
			return HAM_IGNORED
		}
		case WEAPONKEY_SFT:
		{
			g_has_sftornado[id] = true
			
			message_begin(MSG_ONE, g_MsgWeaponList, .player = id)
			write_string("weapon_sftornado")
			write_byte(4)
			write_byte(90)
			write_byte(-1)
			write_byte(-1)
			write_byte(0)
			write_byte(6)
			write_byte(CSW_SFT)
			write_byte(0)
			message_end()

			set_pev(item, pev_impulse, 0)
			
			return HAM_HANDLED
		}
	}

	return HAM_IGNORED
}

public fw_sftornado_ItemKill_Pre(sft_ent)
{
	if(IsSFTornadoEnt(sft_ent))
		set_pev(sft_ent, pev_impulse, 0)
}

public fw_sftornado_Weapon_Spawn_Post(weapon)
{
	if(pev_valid(weapon))
		set_pev(weapon, pev_impulse, 0)
}

public fw_sftornado_PlayerSpawn_Post(id)
{
	if(!is_user_alive(id))
		return HAM_IGNORED

	static ent
	ent = fm_get_user_weapon_entity(id, CSW_SFT)

	if(IsSFTornadoEnt(ent))
		g_has_sftornado[id] = true
	else if(get_user_weapon(id) == CSW_SFT)
		g_has_sftornado[id] = false

	return HAM_IGNORED
}

public fw_sftornado_Deploy_Post(weapon_ent)
{
	if(pev_valid(weapon_ent) != 2)
		return

	static id
	id = fm_cs_get_weapon_ent_owner(weapon_ent)
	
	if(get_pdata_cbase(id, m_pActiveItem) != weapon_ent)
		return

	if(!g_has_sftornado[id])
		return

	for(new i; i < 3; i++)
		g_Delay[id][i] = 0.0

	Stop_Sound(id)
	
	set_pev(id, pev_viewmodel2, SFTORNADO_V_MODEL)
	set_pev(id, pev_weaponmodel2, SFTORNADO_P_MODEL)

	switch(g_current_mode[id])
	{
		case MODE_A: fm_play_weapon_animation(id, DRAWA)
		case MODE_B: fm_play_weapon_animation(id, DRAWB)
		case MODE_C: fm_play_weapon_animation(id, DRAWC)
	}
}

public fw_sftornado_WeaponIdle_Post(sft)
{
	if(pev_valid(sft) != 2)
		return HAM_IGNORED

	new id = fm_cs_get_weapon_ent_owner(sft)
	
	if(get_pdata_cbase(id, m_pActiveItem) != sft)
		return HAM_IGNORED

	if (!g_has_sftornado[id])
		return HAM_IGNORED

	if(get_pdata_float(sft, m_flTimeWeaponIdle, WEAP_LINUX_XTRA_OFF) <= 0.1)
	{
		switch(g_current_mode[id])
		{
			case MODE_A: fm_play_weapon_animation(id, IDLEA)
			case MODE_B: fm_play_weapon_animation(id, IDLEB)
			case MODE_C: fm_play_weapon_animation(id, IDLEC)
		}

		set_pdata_float(sft, m_flTimeWeaponIdle, 10.0, WEAP_LINUX_XTRA_OFF)
		set_pdata_string(id, (492) * 4, "carbine", -1 , 20)
	}

	return HAM_IGNORED
}

public fw_UpdateClientData_Post(id, SendWeapons, CD_Handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED

	if(get_user_weapon(id) == CSW_SFT && g_has_sftornado[id])
		set_cd(CD_Handle, CD_flNextAttack, get_gametime() + 0.001)
	
	return FMRES_HANDLED
}

public fw_sftornado_PrimaryAttack(Weapon)
{
	static id
	id = get_pdata_cbase(Weapon, WEAPONOWNER_OFF, WEAP_LINUX_XTRA_OFF)

	if (id < 1 || id > 32)
		return

	if (!g_has_sftornado[id])
		return

	g_primaryattack = true
	pev(id, pev_punchangle, cl_pushangle[id])

	g_clip_ammo[id] = cs_get_weapon_ammo(Weapon)
}

public fw_sftornado_PrimaryAttack_Post(Weapon)
{
	if(!pev_valid(Weapon))
		return

	g_primaryattack = false
	
	static id
	id = get_pdata_cbase(Weapon, WEAPONOWNER_OFF, WEAP_LINUX_XTRA_OFF)

	if(!is_user_alive(id))
		return

	remove_task(id+SF_TASK_RESET)

	if(g_has_sftornado[id])
	{
		if(g_clip_ammo[id])
		{
			new Float:push[3]
			pev(id,pev_punchangle,push)
			xs_vec_sub(push,cl_pushangle[id],push)

			xs_vec_mul_scalar(push, 0.30, push)
			xs_vec_add(push,cl_pushangle[id],push)
			set_pev(id,pev_punchangle,push)

			switch(g_current_mode[id])
			{
				case MODE_A:
				{
					if(get_gametime() - g_Delay[id][0] > 5.0)
					{
						engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, SF_SOUNDS[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						g_Delay[id][0] = get_gametime()
					}

					if (pev(id, pev_weaponanim) != SHOOTA) fm_play_weapon_animation(id, SHOOTA)
				}
				case MODE_B:
				{
					if(get_gametime() - g_Delay[id][1] > 6.0)
					{
						engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, SF_SOUNDS[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						g_Delay[id][1] = get_gametime()
					}

					if (pev(id, pev_weaponanim) != SHOOTB) fm_play_weapon_animation(id, SHOOTB)
				}
				case MODE_C:
				{
					if(get_gametime() - g_Delay[id][2] > 6.0)
					{
						engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, SF_SOUNDS[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						g_Delay[id][2] = get_gametime()
					}

					if (pev(id, pev_weaponanim) != SHOOTC) fm_play_weapon_animation(id, SHOOTC)
				}
			}
		}
		else
		{
			Stop_Sound(id)

			switch(g_current_mode[id])
			{
				case MODE_A: fm_play_weapon_animation(id, SHOOTA_empty)
				case MODE_B: fm_play_weapon_animation(id, SHOOTB_empty)
				case MODE_C: fm_play_weapon_animation(id, SHOOTC_empty)
			}
		}
	}
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED

	if (get_user_weapon(id) != CSW_SFT || !g_has_sftornado[id])
		return FMRES_IGNORED

	static iButton
	iButton = get_uc(uc_handle, UC_Buttons)

	if(!(iButton & IN_ATTACK) && pev(id, pev_oldbuttons) & IN_ATTACK)
	{
		Stop_Sound(id)

		switch(g_current_mode[id])
		{
			case MODE_A:
			{
				fm_play_weapon_animation(id, SHOOT_ENDA)
				g_Delay[id][0] = 0.0
			}
			case MODE_B:
			{
				fm_play_weapon_animation(id, SHOOT_ENDB)
				g_Delay[id][1] = 0.0
			}
			case MODE_C:
			{
				fm_play_weapon_animation(id, SHOOT_ENDC)
				g_Delay[id][2] = 0.0
			}
		}

		if (g_current_mode[id] > MODE_A)
		{
			remove_task(id+SF_TASK_RESET)
			set_task(5.0, "reset_mode", id+SF_TASK_RESET)
		}

		fm_set_weapon_idle_time(id, weapon_sft, 0.5)
	}
	if(iButton & IN_ATTACK2)
	{
		iButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, iButton)
	}

	return FMRES_HANDLED
}

public reset_mode(id)
{
	id -= SF_TASK_RESET

	switch(g_current_mode[id])
	{
		case MODE_B:
		{
			fm_play_weapon_animation(id, CHANGEA)
			g_current_mode[id] = MODE_A
		}
		case MODE_C:
		{
			fm_play_weapon_animation(id, CHANGEB)
			g_current_mode[id] = MODE_B
			set_task(5.0, "reset_mode", id+SF_TASK_RESET)
		}
	}

	g_laser_counter[id] = 0

	fm_set_weapon_idle_time(id, weapon_sft, 1.5)
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (eventid != g_orig_event_sftornado || !g_primaryattack)
		return FMRES_IGNORED

	if (!(1 <= invoker <= g_maxplayers))
		return FMRES_IGNORED

	if(get_user_weapon(invoker) != CSW_SFT || !g_has_sftornado[invoker])
		return FMRES_IGNORED

	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	return FMRES_SUPERCEDE
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(iAttacker))
		return HAM_IGNORED

	new g_currentweapon = get_user_weapon(iAttacker)

	if(g_currentweapon != CSW_SFT)
		return HAM_IGNORED

	if(!g_has_sftornado[iAttacker])
		return HAM_IGNORED

	static Float:flEnd[3]
	get_tr2(ptr, TR_vecEndPos, flEnd)
	g_HitGroup[iAttacker] = get_tr2(ptr, TR_iHitgroup)

	switch (g_current_mode[iAttacker])
	{
		case MODE_A: Make_Laser(iAttacker, flEnd, g_beamSpr[0], 0, 166, 173, 200)
		case MODE_B:
		{
			Make_Laser(iAttacker, flEnd, g_beamSpr[1], 110, 195, 201, 230)
			Make_Elec(iAttacker, flEnd, 0, 255, 255, 200)
		}
		case MODE_C:
		{
			Make_Laser(iAttacker, flEnd, g_beamSpr[2], 202, 229, 232, 250)
			Make_Elec(iAttacker, flEnd, 202, 229, 232, 250)
		}
	}

	if(!is_user_alive(iEnt))
	{
		Make_Spark(flEnd)
		Make_Balls(iAttacker)
	}

	return HAM_IGNORED
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (victim != attacker && is_user_connected(attacker))
	{
		if(get_user_weapon(attacker) == CSW_SFT && g_has_sftornado[attacker])
		{
			switch (g_current_mode[attacker])
			{
				case MODE_A: damage = 50.0
				case MODE_B: damage = 50.0 * 2
				case MODE_C:
				{
					damage = 50.0 * 1.5

					if(random(5) == 1)
					{
						if(ze_is_user_zombie(victim))
							g_BurnDur[victim] += 1
						else
							g_BurnDur[victim] += 2

						if(!task_exists(victim+SF_TASK_BURN))
							set_task(0.2, "burning_flame", victim+SF_TASK_BURN, .flags = "b")
					}
				}
			}

			switch(g_HitGroup[attacker])
			{
				case HIT_HEAD: damage *= 1.5
				case HIT_LEFTARM .. HIT_RIGHTLEG: damage *= 0.7
			}

			SetHamParamFloat(4, damage)

			if(g_current_mode[attacker] < MODE_C)
			{
				g_laser_counter[attacker]++
				CheckMode(attacker)
			}
		}
	}
}

public burning_flame(task_id)
{
	new id = task_id - SF_TASK_BURN

	if(!is_user_connected(id) || !is_user_alive(id) || !ze_is_user_zombie(id))
	{
		remove_task(task_id)
		return
	}

	static origin[3], flags
	get_user_origin(id, origin)
	flags = pev(id, pev_flags)

	if(flags & FL_INWATER || g_BurnDur[id] < 1)
	{
		remove_task(task_id)
		return
	}

	if(flags & FL_ONGROUND && ze_is_user_zombie(id))
	{
		static Float:velocity[3]
		pev(id, pev_velocity, velocity)
		xs_vec_mul_scalar(velocity, 0.5, velocity)
		set_pev(id, pev_velocity, velocity)
	}

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_SPRITE)
	write_coord(origin[0]+random_num(-5, 5))
	write_coord(origin[1]+random_num(-5, 5))
	write_coord(origin[2]+random_num(-10, 10))
	write_short(g_flameSpr)
	write_byte(random_num(4, 6))
	write_byte(200)
	message_end()

	g_BurnDur[id]--
}

public CheckMode(id)
{
	if(g_laser_counter[id] < 20)
		return

	Stop_Sound(id)

	switch(g_current_mode[id])
	{
		case MODE_A:
		{
			Stop_Sound(id)
			g_current_mode[id] = MODE_B
		}
		case MODE_B:
		{
			Stop_Sound(id)
			g_current_mode[id] = MODE_C
		}
	}

	g_laser_counter[id] = 0
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static TruncatedWeapon[33], iAttacker, iVictim, weapon[32]
	
	copy(weapon, charsmax(weapon), weapon_sft)
	replace(weapon, charsmax(weapon), "weapon_", "")

	get_msg_arg_string(4, TruncatedWeapon, charsmax(TruncatedWeapon))

	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)

	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE

	if(equal(TruncatedWeapon, weapon) && get_user_weapon(iAttacker) == CSW_SFT && g_has_sftornado[iAttacker])
		set_msg_arg_string(4, "SF Tornado")

	return PLUGIN_CONTINUE
}

public fw_sftornado_ItemPostFrame(ent)
{
	static id
	id = fm_cs_get_weapon_ent_owner(ent)
	
	if(!is_user_alive(id))
		return HAM_IGNORED
	
	if(!g_has_sftornado[id])
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, m_flNextAttack, PLAYER_LINUX_XTRA_OFF)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_SFT)
	
	static iClip; iClip = get_pdata_int(ent, m_iClip, WEAP_LINUX_XTRA_OFF)
	static fInReload; fInReload = get_pdata_int(ent, m_fInReload, WEAP_LINUX_XTRA_OFF)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(70 - iClip, bpammo)

		set_pdata_int(ent, m_iClip, iClip + temp1, WEAP_LINUX_XTRA_OFF)
		cs_set_user_bpammo(id, CSW_SFT, bpammo - temp1)		
		
		set_pdata_int(ent, m_fInReload, 0, WEAP_LINUX_XTRA_OFF)
		
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public fw_sftornado_Reload(weapon_entity) 
{
	static id
	id = fm_cs_get_weapon_ent_owner(weapon_entity)

	if (!is_user_connected(id))
		return HAM_IGNORED

	if (!g_has_sftornado[id])
		return HAM_IGNORED

	static iClipExtra

	if(g_has_sftornado[id])
		iClipExtra = 70

	g_sftornado_TmpClip[id] = -1

	new iBpAmmo = cs_get_user_bpammo(id, CSW_SFT)
	new iClip = get_pdata_int(weapon_entity, m_iClip, WEAP_LINUX_XTRA_OFF)

	if (iBpAmmo <= 0)
		return HAM_SUPERCEDE

	if (iClip >= iClipExtra)
		return HAM_SUPERCEDE

	g_sftornado_TmpClip[id] = iClip

	return HAM_IGNORED
}

public fw_sftornado_Reload_Post(ent)
{
	static id
	id = fm_cs_get_weapon_ent_owner(ent)
	
	if (!is_user_connected(id))
		return HAM_IGNORED

	if (!g_has_sftornado[id])
		return HAM_IGNORED

	if (g_sftornado_TmpClip[id] == -1)
		return HAM_IGNORED

	set_pdata_int(ent, m_iClip, g_sftornado_TmpClip[id], WEAP_LINUX_XTRA_OFF)

	fm_set_weapon_idle_time(id, weapon_sft, 3.5)

	set_pdata_int(ent, m_fInReload, 1, WEAP_LINUX_XTRA_OFF) 
		
	switch (g_current_mode[id])
	{
		case MODE_A: fm_play_weapon_animation(id, RELOADA)
		case MODE_B: fm_play_weapon_animation(id, RELOADB)
		case MODE_C: fm_play_weapon_animation(id, RELOADC)
	}

	if(g_current_mode[id] > MODE_A)
	{
		remove_task(id+SF_TASK_RESET)
		set_task(5.0, "reset_mode", id+SF_TASK_RESET)
	}
	
	return HAM_HANDLED
}

stock Make_Elec(id, Float:flEnd[3], Red, Green, Blue, Brightness)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(id | 0x1000)
	engfunc(EngFunc_WriteCoord, flEnd[0])
	engfunc(EngFunc_WriteCoord, flEnd[1])
	engfunc(EngFunc_WriteCoord, flEnd[2])
	write_short(g_elecSpr)
	write_byte(10)
	write_byte(10)
	write_byte(1)
	write_byte(5)
	write_byte(10)
	write_byte(Red)
	write_byte(Green)
	write_byte(Blue)
	write_byte(Brightness)
	write_byte(5)
	message_end();
}

stock Make_Laser(id, Float:flEnd[3], Spr, Red, Green, Blue, Brightness)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(id | 0x1000)
	engfunc(EngFunc_WriteCoord, flEnd[0])
	engfunc(EngFunc_WriteCoord, flEnd[1])
	engfunc(EngFunc_WriteCoord, flEnd[2])
	write_short(Spr)
	write_byte(0)
	write_byte(0)
	write_byte(1)
	write_byte(12)
	write_byte(0)
	write_byte(Red)
	write_byte(Green)
	write_byte(Blue)
	write_byte(Brightness)
	write_byte(255)
	message_end();
}

stock Make_Balls(id)
{
	new origin[3]

	get_user_origin(id, origin, 3)

	message_begin(MSG_ALL, SVC_TEMPENTITY, {0,0,0}, id)
	write_byte(TE_SPRITETRAIL)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2]+5)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2]+80)
	write_short(g_gibsSpr)
	write_byte(!random (6) ? 1 : 0)
	write_byte(5)
	write_byte(4)
	write_byte(20)
	write_byte(10)
	message_end()
}

stock Make_Spark(Float:flEnd[3])
{
	message_begin(MSG_PAS, SVC_TEMPENTITY, flEnd)
	write_byte(TE_SPARKS)
	engfunc(EngFunc_WriteCoord, flEnd[0])
	engfunc(EngFunc_WriteCoord, flEnd[1] + random_num(2, 6))
	engfunc(EngFunc_WriteCoord, flEnd[2] + random_num(6, 10))
	message_end()
}

stock fm_cs_get_weapon_ent_owner(ent)
	return get_pdata_cbase(ent, WEAPONOWNER_OFF, WEAP_LINUX_XTRA_OFF)

stock fm_play_weapon_animation(const id, const Sequence)
{
	set_pev(id, pev_weaponanim, Sequence)

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = id)
	write_byte(Sequence)
	write_byte(pev(id, pev_body))
	message_end()
}

stock fm_set_weapon_idle_time(id, const class[], Float:IdleTime)
{
	static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, class, id)

	if(!pev_valid(weapon_ent))
		return

	set_pdata_float(weapon_ent, m_flNextPrimaryAttack, IdleTime, WEAP_LINUX_XTRA_OFF);
	set_pdata_float(weapon_ent, m_flNextSecondaryAttack, IdleTime, WEAP_LINUX_XTRA_OFF);
	set_pdata_float(weapon_ent, m_flTimeWeaponIdle, IdleTime + 0.50, WEAP_LINUX_XTRA_OFF);
}

stock fm_get_user_weapon_entity(id, wid = 0)
{
	new weap = wid, clip, ammo;
	if (!weap && !(weap = get_user_weapon(id, clip, ammo)))
		return 0;

	if(!pev_valid(weap))
		return 0

	new class[32];
	get_weaponname(weap, class, sizeof class - 1);

	return fm_find_ent_by_owner(-1, class, id);
}

stock fm_find_ent_by_owner(index, const classname[], owner, jghgtype = 0)
{
	new strtype[11] = "classname", ent = index;

	switch (jghgtype)
	{
		case 1: strtype = "target";
		case 2: strtype = "targetname";
	}

	while ((ent = engfunc(EngFunc_FindEntityByString, ent, strtype, classname)) && pev(ent, pev_owner) != owner) {}

	return ent;
}

stock fm_give_item(index, const item[])
{
	if (!equal(item, "weapon_", 7) && !equal(item, "ammo_", 5) && !equal(item, "item_", 5) && !equal(item, "tf_weapon_", 10))
		return 0;

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, item));
	if (!pev_valid(ent))
		return 0;

	new Float:origin[3];
	pev(index, pev_origin, origin);
	set_pev(ent, pev_origin, origin);
	set_pev(ent, pev_spawnflags, pev(ent, pev_spawnflags) | SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn, ent);

	new save = pev(ent, pev_solid);
	dllfunc(DLLFunc_Touch, ent, index);
	if (pev(ent, pev_solid) != save)
		return ent;

	engfunc(EngFunc_RemoveEntity, ent);

	return -1;
}

stock Stop_Sound(id)
	engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, "common/null.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)

stock bool:fm_strip_user_gun(index, wid = 0, const wname[] = "")
{
	new ent_class[32];
	
	if (!wid && wname[0])
		copy(ent_class, sizeof ent_class - 1, wname);
	
	else
	{
		new weapon = wid, clip, ammo;
		if (!weapon && !(weapon = get_user_weapon(index, clip, ammo)))
			return false;
		
		get_weaponname(weapon, ent_class, sizeof ent_class - 1);
	}

	new ent_weap = fm_find_ent_by_owner(-1, ent_class, index);
	if (!ent_weap)
		return false;

	engclient_cmd(index, "drop", ent_class);

	new ent_box = pev(ent_weap, pev_owner);
	if (!ent_box || ent_box == index)
		return false;

	dllfunc(DLLFunc_Think, ent_box);

	return true;
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)

	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]

		if (dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock reset_sftornado_state(id, bool:stop_sound = true, bool:clear_ownership = true)
{
	if(stop_sound)
		Stop_Sound(id)

	if(task_exists(id + SF_TASK_RESET))
		remove_task(id + SF_TASK_RESET)

	for(new i; i < 3; i++)
		g_Delay[id][i] = 0.0

	g_laser_counter[id] = 0
	g_current_mode[id] = MODE_A

	if(clear_ownership)
		g_has_sftornado[id] = false
}
