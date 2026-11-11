/// Service the reserve from outside, through an open and unlocked maintenance hatch.
/obj/vehicle/sealed/spacepod/proc/can_service_internal_tank(mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && isliving(user) && isturf(loc) && isturf(user.loc) && !user.combat_mode && !user.incapacitated && !HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) && Adjacent(user) && hatch_open && unlocked && !melting_down

/obj/vehicle/sealed/spacepod/proc/install_internal_tank(mob/living/user, obj/machinery/portable_atmospherics/canister/tank)
	if(!can_service_internal_tank(user) || !istype(tank) || QDELETED(tank) || !isturf(tank.loc) || !user.Adjacent(tank))
		return FALSE
	if(internal_tank)
		balloon_alert(user, "сначала извлеките баллон!")
		return FALSE
	// forceMove does not run the portable machinery's Move()/disconnect() hook.
	if(tank.anchored || tank.connected_port)
		balloon_alert(user, "сначала отсоедините баллон!")
		return FALSE
	if(tank.valve_open)
		balloon_alert(user, "закройте вентиль баллона!")
		return FALSE
	if((tank.machine_stat & BROKEN) || QDELETED(tank.return_air()))
		balloon_alert(user, "баллон неисправен!")
		return FALSE
	// Close stale canister windows before hiding it in the hull; its valve must stay shut.
	SStgui.close_uis(tank)
	tank.forceMove(src)
	if(QDELETED(src) || QDELETED(tank) || tank.loc != src)
		return FALSE
	internal_tank = tank
	RegisterSignal(tank, COMSIG_QDELETING, PROC_REF(clear_internal_tank))
	add_fingerprint(user)
	tank.add_fingerprint(user)
	playsound(src, 'sound/effects/compressed_air/tank_insert_clunky.ogg', 50, TRUE)
	balloon_alert(user, "баллон установлен")
	return TRUE

/obj/vehicle/sealed/spacepod/proc/remove_internal_tank(mob/living/user)
	if(!can_service_internal_tank(user) || QDELETED(internal_tank) || internal_tank.loc != src)
		return FALSE
	var/turf/destination = get_turf(user)
	if(!destination || (destination in locs) || destination.is_blocked_turf(ignore_atoms = list(user)))
		balloon_alert(user, "нет места для баллона!")
		return FALSE
	var/obj/machinery/portable_atmospherics/canister/tank = internal_tank
	tank.forceMove(destination)
	if(QDELETED(tank) || tank.loc != destination)
		return FALSE
	add_fingerprint(user)
	tank.add_fingerprint(user)
	playsound(src, 'sound/effects/compressed_air/tank_remove_thunk.ogg', 50, TRUE)
	balloon_alert(user, "баллон извлечён")
	return TRUE

/// The pod owns only its installed canister, never a removed or deleted one.
/obj/vehicle/sealed/spacepod/proc/clear_internal_tank(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	if(source == internal_tank)
		internal_tank = null

/obj/vehicle/sealed/spacepod/examine(mob/user)
	. = ..()
	if(hatch_open)
		. += span_notice("Пустой рукой можно извлечь батарею, воздушный баллон или модуль. Для установки баллона с закрытым вентилем перетащите его на челнок.")
	if(!internal_tank)
		. += span_warning("Резервный воздушный баллон не установлен.")
