#if defined _reapi_zb_included
	#endinput
#endif
#define _reapi_zb_included

native ZB_RegisterZombieClass(const szName[], const szInfo[], const szPlayerModel[], const szHandModel[], Float:fHealth, Float:fSpeed, Float:fGravity, Float:fKnockback)
native ZB_RegisterHumanClass(const szName[], const szInfo[], const szPlayerModel[], Float:fHealth, Float:fSpeed, Float:fGravity) //fSpeed = 0.0 -- default weapon speed

native ZB_GetUserZombie(id)
native ZB_GetUserBossZombie(id)
native ZB_GetUserHuman(id)
native ZB_GetUserLeader(id)

native ZB_GetUserZombieClass(id)
native ZB_GetUserZombieClassNext(id)

native ZB_GetUserHumanClass(id)
native ZB_GetUserHumanClassNext(id)

native ZB_SetUserZombieClass(id)
native ZB_SetUserHumanClass(id)

native ZB_InfectUser(id, atk, boss, firstzombie)
native ZB_CureUser(id, atk, leader, strip)

native ZB_IsRoundStarted()

native ZB_SetUserMaxSpeed(id, Float:fSpeed)
native ZB_ResetUserMaxSpeed(id)

forward ZB_UserInfectPre(id, atk, boss, firstzombie)
forward ZB_UserCurePre(id, atk, leader, strip)

forward ZB_UserInfectPost(id, atk, boss, firstzombie)
forward ZB_UserCurePost(id, atk, leader, strip)

forward ZB_UserSpawnPost(id, zombie)
forward ZB_RoundStarted(zombiecount)