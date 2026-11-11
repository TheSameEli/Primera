/datum/unit_test/spacepod_life_support
	abstract_type = /datum/unit_test/spacepod_life_support

/datum/unit_test/spacepod_life_support/proc/make_pod()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	return allocate(/obj/vehicle/sealed/spacepod/civilian, origin)

/datum/unit_test/spacepod_life_support/proc/fill_cabin(obj/vehicle/sealed/spacepod/pod, oxygen_kpa, co2_kpa)
	var/datum/gas_mixture/cabin = pod.cabin_air
	qdel(cabin.remove_ratio(1))
	cabin.temperature = T20C
	var/moles_per_kpa = cabin.volume / (R_IDEAL_GAS_EQUATION * T20C)
	cabin.set_gas(/datum/gas/oxygen, oxygen_kpa * moles_per_kpa)
	cabin.set_gas(/datum/gas/carbon_dioxide, co2_kpa * moles_per_kpa)
	cabin.set_gas(/datum/gas/nitrogen, max(0, ONE_ATMOSPHERE - oxygen_kpa - co2_kpa) * moles_per_kpa)

/datum/unit_test/spacepod_life_support/proc/total_gas(obj/vehicle/sealed/spacepod/pod, datum/gas_mixture/exterior)
	var/datum/gas_mixture/reserve = pod.internal_tank?.return_air()
	return (pod.cabin_air?.total_moles() || 0) + (reserve?.total_moles() || 0) + (exterior?.total_moles() || 0)

/// Count full-mixture sums without replacing their native calculation.
/datum/gas_mixture/spacepod_life_support_counter
	var/total_moles_calls = 0

/datum/gas_mixture/spacepod_life_support_counter/total_moles()
	total_moles_calls++
	return ..()

/// Healthy oxygen needs no composition scan; low oxygen still compares both actual mixtures.
/datum/unit_test/spacepod_life_support/oxygen_short_circuit/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = make_pod()
	var/datum/gas_mixture/spacepod_life_support_counter/cabin = allocate(__IMPLIED_TYPE__, pod.cabin_air.volume)
	cabin.copy_from(pod.cabin_air)
	QDEL_NULL(pod.cabin_air)
	pod.cabin_air = cabin
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	var/datum/gas_mixture/spacepod_life_support_counter/reserve = allocate(__IMPLIED_TYPE__, tank_air.volume)
	reserve.copy_from(tank_air)
	TEST_ASSERT(!pod.needs_cabin_air_exchange(reserve), "Healthy cabin oxygen incorrectly requested fresh-air exchange.")
	TEST_ASSERT_EQUAL(cabin.total_moles_calls, 0, "Healthy cabin oxygen unnecessarily summed the cabin mixture.")
	TEST_ASSERT_EQUAL(reserve.total_moles_calls, 0, "Healthy cabin oxygen unnecessarily summed the reserve mixture.")
	fill_cabin(pod, 2, 0)
	TEST_ASSERT(pod.needs_cabin_air_exchange(reserve), "Low cabin oxygen did not request exchange from the real richer reserve mixture.")
	TEST_ASSERT_EQUAL(cabin.total_moles_calls, 1, "Low-oxygen exchange did not sum the cabin mixture exactly once.")
	TEST_ASSERT_EQUAL(reserve.total_moles_calls, 1, "Low-oxygen exchange did not sum the reserve mixture exactly once.")
	reserve.copy_from(cabin)
	TEST_ASSERT(!pod.needs_cabin_air_exchange(reserve), "Low oxygen requested exchange from an equally oxygen-poor reserve mixture.")
	TEST_ASSERT_EQUAL(cabin.total_moles_calls, 2, "Comparing an unsuitable reserve skipped or repeated the real cabin sum.")
	TEST_ASSERT_EQUAL(reserve.total_moles_calls, 2, "Comparing an unsuitable reserve skipped or repeated the real reserve sum.")

/// A full-pressure CO2 cabin recovers in the real process path without deleting exhaust or creating fresh air.
/datum/unit_test/spacepod_life_support/recovery/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = make_pod()
	fill_cabin(pod, 0, ONE_ATMOSPHERE)
	var/turf/location = get_turf(pod)
	var/datum/gas_mixture/exterior = location.return_air()
	var/datum/gas_mixture/reserve = pod.internal_tank.return_air()
	var/cabin_co2_before = pod.cabin_air.moles[/datum/gas/carbon_dioxide]
	var/exterior_co2_before = exterior.moles[/datum/gas/carbon_dioxide] || 0
	var/reserve_before = reserve.total_moles()
	var/gas_before = total_gas(pod, exterior)
	var/charge_before = pod.battery.charge
	pod.process(2)
	TEST_ASSERT(pod.cabin_air.moles[/datum/gas/carbon_dioxide] < cabin_co2_before, "Real pod processing did not clean CO2 from a full-pressure cabin.")
	TEST_ASSERT(pod.cabin_air.moles[/datum/gas/oxygen] > 0, "Cleaning the full-pressure cabin did not allow real reserve oxygen to enter in the same process step.")
	TEST_ASSERT(reserve.total_moles() < reserve_before, "Cabin recovery did not consume the finite reserve canister.")
	TEST_ASSERT(abs(pod.cabin_air.return_pressure() - ONE_ATMOSPHERE) < 0.1, "Life support did not restore the native cabin pressure target.")
	TEST_ASSERT(exterior.moles[/datum/gas/carbon_dioxide] > exterior_co2_before, "Scrubbed CO2 was deleted instead of transferred to the actual exterior turf.")
	var/co2_after = (pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) + (exterior.moles[/datum/gas/carbon_dioxide] || 0)
	TEST_ASSERT(abs(co2_after - cabin_co2_before - exterior_co2_before) <= MAXIMUM_ERROR_GAS_REMOVAL, "CO2 was generated or lost during cleaning and air exchange.")
	TEST_ASSERT(abs(total_gas(pod, exterior) - gas_before) <= MAXIMUM_ERROR_GAS_REMOVAL, "Life support created or destroyed more gas than native transfer quantization permits.")
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_before - SPACEPOD_LIFE_SUPPORT_POWER * 2, "An active two-second life-support interval consumed the wrong energy.")

/// Compare steady scrub-only and exchange-only operation without crossing activation or supply thresholds.
/datum/unit_test/spacepod_life_support/timesteps/Run()
	for(var/mode in list("scrub", "exchange"))
		var/obj/vehicle/sealed/spacepod/civilian/pod = make_pod()
		fill_cabin(pod, mode == "exchange" ? 2 : 0, mode == "scrub" ? ONE_ATMOSPHERE : 0)
		var/datum/gas_mixture/reserve = pod.internal_tank.return_air()
		if(mode == "scrub")
			qdel(reserve.remove_ratio(1))
		var/turf/location = get_turf(pod)
		var/datum/gas_mixture/exterior = location.return_air()
		var/datum/gas_mixture/cabin_start = allocate(/datum/gas_mixture, pod.cabin_air.volume)
		var/datum/gas_mixture/reserve_start = allocate(/datum/gas_mixture, reserve.volume)
		var/datum/gas_mixture/exterior_start = allocate(/datum/gas_mixture, exterior.volume)
		cabin_start.copy_from(pod.cabin_air)
		reserve_start.copy_from(reserve)
		exterior_start.copy_from(exterior)
		var/charge_before = pod.battery.charge
		pod.process(4)
		var/datum/gas_mixture/whole_cabin = allocate(/datum/gas_mixture, pod.cabin_air.volume)
		var/datum/gas_mixture/whole_reserve = allocate(/datum/gas_mixture, reserve.volume)
		var/datum/gas_mixture/whole_exterior = allocate(/datum/gas_mixture, exterior.volume)
		whole_cabin.copy_from(pod.cabin_air)
		whole_reserve.copy_from(reserve)
		whole_exterior.copy_from(exterior)
		var/whole_charge = pod.battery.charge
		pod.cabin_air.copy_from(cabin_start)
		reserve.copy_from(reserve_start)
		exterior.copy_from(exterior_start)
		pod.battery.give(charge_before - pod.battery.charge)
		for(var/step in 1 to 4)
			pod.process(1)
		var/tolerance = 8 * MOLAR_ACCURACY
		for(var/gas in list(/datum/gas/oxygen, /datum/gas/nitrogen, /datum/gas/carbon_dioxide))
			TEST_ASSERT(abs((pod.cabin_air.moles[gas] || 0) - (whole_cabin.moles[gas] || 0)) <= tolerance, "[mode] cabin gas depends on splitting four seconds into one-second intervals.")
			TEST_ASSERT(abs((reserve.moles[gas] || 0) - (whole_reserve.moles[gas] || 0)) <= tolerance, "[mode] reserve usage depends on processing interval size.")
			TEST_ASSERT(abs((exterior.moles[gas] || 0) - (whole_exterior.moles[gas] || 0)) <= tolerance, "[mode] exterior exhaust depends on processing interval size.")
		TEST_ASSERT_EQUAL(pod.battery.charge, whole_charge, "[mode] energy cost depends on processing interval size under steady activation.")
		if(mode == "scrub")
			TEST_ASSERT(abs((cabin_start.moles[/datum/gas/carbon_dioxide] - pod.cabin_air.moles[/datum/gas/carbon_dioxide]) - SPACEPOD_CO2_FILTER_RATE * 4) <= tolerance, "Scrub-only operation did not respect its real per-second molar flow.")
		else
			TEST_ASSERT(pod.cabin_air.moles[/datum/gas/oxygen] > cabin_start.moles[/datum/gas/oxygen], "The exchange-only timestep fixture never exchanged oxygen.")
			TEST_ASSERT(pod.needs_cabin_air_exchange(reserve), "The exchange-only fixture crossed its oxygen activation threshold.")
		qdel(pod)

/// Guard failures leave the active helper inert; passive pressure regulation is a separate donor behavior.
/datum/unit_test/spacepod_life_support/guards/Run()
	for(var/blocked in list("no_cell", "empty_cell", "insufficient_cell", "emp", "outside_air", "meltdown", "missing_cabin", "zero_volume", "zero_temperature", "nullspace", "missing_exterior", "zero_dt", "negative_dt"))
		var/obj/vehicle/sealed/spacepod/civilian/pod = make_pod()
		fill_cabin(pod, 0, ONE_ATMOSPHERE)
		var/dt = 2
		var/turf/open/temporarily_airless_turf
		var/datum/gas_mixture/saved_exterior_air
		switch(blocked)
			if("no_cell")
				var/obj/item/stock_parts/power_store/cell/cell = pod.battery
				allocated += cell
				cell.forceMove(run_loc_floor_bottom_left)
			if("empty_cell")
				pod.battery.use(pod.battery.charge)
			if("insufficient_cell")
				pod.battery.use(pod.battery.charge - SPACEPOD_LIFE_SUPPORT_POWER)
			if("emp")
				pod.emp_act(EMP_LIGHT)
				TEST_ASSERT(!COOLDOWN_FINISHED(pod, cooldown_emp), "The real EMP did not disable the life-support fixture.")
			if("outside_air")
				pod.use_internal_tank = FALSE
			if("meltdown")
				pod.melting_down = TRUE
			if("missing_cabin")
				QDEL_NULL(pod.cabin_air)
			if("zero_volume")
				pod.cabin_air.volume = 0
			if("zero_temperature")
				pod.cabin_air.temperature = 0
			if("nullspace")
				pod.moveToNullspace()
			if("missing_exterior")
				temporarily_airless_turf = get_turf(pod)
				saved_exterior_air = temporarily_airless_turf.air
				TEST_ASSERT_NOTNULL(saved_exterior_air, "The missing-exterior fixture has no original open-turf air to restore.")
				temporarily_airless_turf.air = null
			if("zero_dt")
				dt = 0
			if("negative_dt")
				dt = -1
		var/turf/location = get_turf(pod)
		var/datum/gas_mixture/exterior = saved_exterior_air || location?.return_air()
		var/datum/gas_mixture/reserve = pod.internal_tank.return_air()
		var/cabin_before = pod.cabin_air ? json_encode(pod.cabin_air.moles) : null
		var/exterior_before = exterior ? json_encode(exterior.moles) : null
		var/reserve_before = json_encode(reserve.moles)
		var/charge_before = pod.battery?.charge
		pod.process_life_support(dt)
		if(temporarily_airless_turf)
			temporarily_airless_turf.air = saved_exterior_air
		TEST_ASSERT_EQUAL(pod.cabin_air ? json_encode(pod.cabin_air.moles) : null, cabin_before, "The active helper changed cabin gas despite [blocked].")
		TEST_ASSERT_EQUAL(exterior ? json_encode(exterior.moles) : null, exterior_before, "The active helper vented gas despite [blocked].")
		TEST_ASSERT_EQUAL(json_encode(reserve.moles), reserve_before, "The active helper consumed reserve gas despite [blocked].")
		TEST_ASSERT_EQUAL(pod.battery?.charge, charge_before, "The active helper consumed charge despite [blocked].")
		qdel(pod)

/// Empty, tiny and missing sources cannot create oxygen or purge the cabin without actual replacement gas.
/datum/unit_test/spacepod_life_support/finite_reserve/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = make_pod()
	fill_cabin(pod, 2, 0)
	var/datum/gas_mixture/reserve = pod.internal_tank.return_air()
	var/turf/location = get_turf(pod)
	var/datum/gas_mixture/exterior = location.return_air()
	qdel(reserve.remove_ratio(1))
	var/cabin_before = json_encode(pod.cabin_air.moles)
	var/exterior_before = json_encode(exterior.moles)
	var/charge_before = pod.battery.charge
	pod.process(2)
	TEST_ASSERT_EQUAL(json_encode(pod.cabin_air.moles), cabin_before, "An empty reserve caused an unproductive purge or manufactured cabin air.")
	TEST_ASSERT_EQUAL(json_encode(exterior.moles), exterior_before, "An empty reserve vented cabin gas without a replacement supply.")
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_before, "An unproductive empty-reserve interval consumed active life-support power.")
	reserve.set_gas(/datum/gas/oxygen, 0.05 * O2STANDARD)
	reserve.set_gas(/datum/gas/nitrogen, 0.05 * N2STANDARD)
	var/oxygen_budget = (pod.cabin_air.moles[/datum/gas/oxygen] || 0) + reserve.moles[/datum/gas/oxygen]
	var/gas_before = total_gas(pod, exterior)
	for(var/step in 1 to 8)
		pod.process(2)
	TEST_ASSERT(reserve.total_moles() <= MAXIMUM_ERROR_GAS_REMOVAL, "The deliberately tiny reserve was not exhausted by real air exchange.")
	TEST_ASSERT(pod.cabin_air.moles[/datum/gas/oxygen] <= oxygen_budget + MAXIMUM_ERROR_GAS_REMOVAL, "Life support generated oxygen beyond its actual cabin and reserve budget.")
	TEST_ASSERT(abs(total_gas(pod, exterior) - gas_before) <= MAXIMUM_ERROR_GAS_REMOVAL, "Tiny-source exchange lost or generated gas.")
	for(var/missing in list("gas", "tank"))
		fill_cabin(pod, 0, ONE_ATMOSPHERE)
		if(missing == "gas")
			QDEL_NULL(pod.internal_tank.air_contents)
		else
			qdel(pod.internal_tank)
		var/co2_before = pod.cabin_air.moles[/datum/gas/carbon_dioxide]
		gas_before = total_gas(pod, exterior)
		pod.process(2)
		TEST_ASSERT(pod.cabin_air.moles[/datum/gas/carbon_dioxide] < co2_before, "Powered CO2 filtering stopped only because the reserve [missing] was missing.")
		TEST_ASSERT_EQUAL(pod.cabin_air.moles[/datum/gas/oxygen] || 0, 0, "A missing reserve [missing] created cabin oxygen.")
		TEST_ASSERT(abs(total_gas(pod, exterior) - gas_before) <= MAXIMUM_ERROR_GAS_REMOVAL, "Filtering with a missing reserve [missing] lost or generated gas.")

/// Forty-eight native breaths per person model healthy eight-second breathing intervals without wall-clock sleeps.
/datum/unit_test/spacepod_vacuum/life_support_breathing/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve actual vacuum for the two-person life-support test.")
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	for(var/mob/living/carbon/human/person as anything in list(pilot, passenger))
		TEST_ASSERT_NULL(person.internal, "A breathing subject has personal internals.")
		TEST_ASSERT_NULL(person.wear_mask, "A breathing subject has a breathing mask.")
		TEST_ASSERT_NULL(person.wear_suit, "A breathing subject has a protective suit.")
		TEST_ASSERT(!HAS_TRAIT(person, TRAIT_NOBREATH) && !HAS_TRAIT(person, TRAIT_GODMODE) && !HAS_TRAIT(person, TRAIT_NO_BREATHLESS_DAMAGE), "A breathing subject is immune to native suffocation.")
		TEST_ASSERT(pod.mob_try_enter(person), "A real human could not board the two-person cabin.")
	var/datum/gas_mixture/reserve = pod.internal_tank.return_air()
	var/reserve_oxygen_before = reserve.moles[/datum/gas/oxygen]
	var/reserve_nitrogen_before = reserve.moles[/datum/gas/nitrogen]
	var/charge_before = pod.battery.charge
	for(var/breath in 1 to 48)
		for(var/mob/living/carbon/human/person as anything in list(pilot, passenger))
			person.breathe(SSMOBS_DT)
			TEST_ASSERT(!person.failed_last_breath && !person.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "A human failed native breathing in life-support interval [breath].")
			TEST_ASSERT_EQUAL(person.get_oxy_loss(), 0, "A human accumulated native oxygen damage in interval [breath].")
		var/exhaled_co2 = pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0
		TEST_ASSERT(exhaled_co2 > 0, "Real human breathing did not put CO2 into the cabin before filtering.")
		for(var/step in 1 to 4)
			pod.process(2)
		TEST_ASSERT((pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) < exhaled_co2, "Life support did not remove the two humans' real exhaled CO2.")
		var/list/data = pod.get_status_data()
		var/co2_kpa = (pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) * R_IDEAL_GAS_EQUATION * pod.cabin_air.temperature / pod.cabin_air.volume
		TEST_ASSERT(data["cabin_oxygen_kpa"] >= 16, "The cabin oxygen pressure fell below 16 kPa during sustained two-person breathing.")
		TEST_ASSERT(co2_kpa <= 10, "The cabin CO2 pressure exceeded 10 kPa during sustained two-person breathing.")
	TEST_ASSERT(reserve.moles[/datum/gas/oxygen] < reserve_oxygen_before, "Sustained breathing did not consume oxygen from the finite reserve.")
	TEST_ASSERT(reserve.moles[/datum/gas/nitrogen] < reserve_nitrogen_before, "The standard-air reserve did not supply its real nitrogen component.")
	TEST_ASSERT(pod.battery.charge < charge_before, "Sustained filtering and air exchange consumed no battery energy.")
