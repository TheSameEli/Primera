/// Ordinary reserve air contains nitrogen, so CO2 removal alone cannot maintain cabin oxygen.
/obj/vehicle/sealed/spacepod/proc/needs_cabin_air_exchange(datum/gas_mixture/tank_air)
	if(QDELETED(cabin_air) || cabin_air.volume <= 0 || cabin_air.temperature <= 0 || QDELETED(tank_air) || tank_air.volume <= 0 || tank_air.temperature <= 0)
		return FALSE
	var/cabin_oxygen = cabin_air.moles[/datum/gas/oxygen]
	var/oxygen_pressure = cabin_oxygen * R_IDEAL_GAS_EQUATION * cabin_air.temperature / cabin_air.volume
	if(oxygen_pressure >= SPACEPOD_CABIN_OXYGEN_TARGET)
		return FALSE
	var/cabin_moles = cabin_air.total_moles()
	var/tank_moles = tank_air.total_moles()
	if(cabin_moles <= 0 || tank_moles <= 0)
		return FALSE
	return tank_air.moles[/datum/gas/oxygen] / tank_moles > cabin_oxygen / cabin_moles

/obj/vehicle/sealed/spacepod/proc/process_life_support(seconds_per_tick)
	if(seconds_per_tick <= 0 || !isturf(loc) || !use_internal_tank || melting_down || !COOLDOWN_FINISHED(src, cooldown_emp) || QDELETED(cabin_air) || cabin_air.volume <= 0 || cabin_air.temperature <= 0)
		return
	var/turf/location = loc
	var/datum/gas_mixture/exterior_air = location.return_air()
	if(QDELETED(exterior_air) || exterior_air == cabin_air)
		return
	var/datum/gas_mixture/tank_air = internal_tank?.return_air()
	if(cabin_air.moles[/datum/gas/carbon_dioxide] <= 0 && !needs_cabin_air_exchange(tank_air))
		return
	if(!battery?.use(SPACEPOD_LIFE_SUPPORT_POWER * seconds_per_tick))
		return
	// Rigged cells can destroy their owner during use().
	if(QDELETED(src) || QDELETED(cabin_air))
		return
	var/datum/gas_mixture/exhaust = cabin_air.remove_specific(/datum/gas/carbon_dioxide, SPACEPOD_CO2_FILTER_RATE * seconds_per_tick)
	if(exhaust)
		location.assume_air(exhaust)
		qdel(exhaust)
	tank_air = internal_tank?.return_air()
	if(!needs_cabin_air_exchange(tank_air))
		return
	var/cabin_moles = cabin_air.total_moles()
	var/datum/gas_mixture/fresh_air = tank_air.remove(cabin_moles * SPACEPOD_CABIN_AIR_FLOW_RATE * seconds_per_tick / cabin_air.volume)
	if(!fresh_air)
		return
	var/fresh_moles = fresh_air.total_moles()
	if(fresh_moles > 0)
		// Obtain real replacement gas before venting any cabin atmosphere.
		var/replacement_moles = min(fresh_moles, cabin_moles * (1 - NUM_E ** (-fresh_moles / cabin_moles)))
		exhaust = cabin_air.remove(replacement_moles)
		if(exhaust)
			location.assume_air(exhaust)
			qdel(exhaust)
		// During continuous mixing, part of the incoming air also reaches the exhaust.
		// Account for that flow so reserve use and final composition both scale with time.
		exhaust = fresh_air.remove(fresh_moles - replacement_moles)
		if(exhaust)
			location.assume_air(exhaust)
			qdel(exhaust)
		cabin_air.merge(fresh_air)
	qdel(fresh_air)
