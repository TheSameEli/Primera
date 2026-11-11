/// Live measurements for the cabin monitor; rounding belongs to the display.
/obj/vehicle/sealed/spacepod/proc/get_status_data()
	var/list/data = list(
		"battery_present" = !QDELETED(battery),
		"charge_percent" = null,
		"integrity_percent" = max_integrity > 0 ? clamp(100 * get_integrity() / max_integrity, 0, 100) : 0,
		"cabin_oxygen_kpa" = null,
		"cabin_oxygen_liters" = null,
		"cabin_pressure_kpa" = null,
		"active_oxygen_kpa" = null,
		"tank_pressure_kpa" = null,
		"using_internal_air" = !!use_internal_tank,
	)
	if(data["battery_present"] && battery.maxcharge > 0)
		data["charge_percent"] = clamp(100 * battery.charge / battery.maxcharge, 0, 100)
	if(!QDELETED(cabin_air))
		var/oxygen_moles = cabin_air.moles[/datum/gas/oxygen]
		// Standard litres describe oxygen quantity at 20 C and one atmosphere, not the current gas volume.
		data["cabin_oxygen_liters"] = oxygen_moles * R_IDEAL_GAS_EQUATION * T20C / ONE_ATMOSPHERE
		if(cabin_air.volume > 0)
			data["cabin_oxygen_kpa"] = oxygen_moles * R_IDEAL_GAS_EQUATION * cabin_air.temperature / cabin_air.volume
			data["cabin_pressure_kpa"] = cabin_air.return_pressure()
	var/datum/gas_mixture/active_air = return_air()
	if(!QDELETED(active_air) && active_air.volume > 0)
		data["active_oxygen_kpa"] = active_air.moles[/datum/gas/oxygen] * R_IDEAL_GAS_EQUATION * active_air.temperature / active_air.volume
	var/datum/gas_mixture/tank_air = internal_tank?.return_air()
	if(!QDELETED(tank_air) && tank_air.volume > 0)
		data["tank_pressure_kpa"] = tank_air.return_pressure()
	return data
