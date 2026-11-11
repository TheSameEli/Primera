/// The HUD must follow the installed cell through real charging and inventory movement.
/datum/unit_test/spacepod_status_battery/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
	var/obj/item/stock_parts/power_store/cell/cell = pod.battery
	var/list/data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["battery_present"], TRUE, "The installed battery is missing from the status data.")
	TEST_ASSERT_EQUAL(data["charge_percent"], 100, "A new fully charged cell does not report 100 percent.")
	TEST_ASSERT(cell.use(cell.charge * 0.123456), "The real battery failed to supply the test's energy draw.")
	data = pod.get_status_data()
	TEST_ASSERT(abs(data["charge_percent"] - 87.6544) < 0.001, "The HUD charge does not follow the cell's real remaining charge.")
	TEST_ASSERT_NOTEQUAL(data["charge_percent"], round(data["charge_percent"], 0.1), "The backend prematurely rounded battery measurements for display.")
	TEST_ASSERT(cell.use(cell.charge), "The real battery could not be exhausted.")
	data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["battery_present"], TRUE, "An exhausted installed battery is reported as absent.")
	TEST_ASSERT_EQUAL(data["charge_percent"], 0, "An exhausted cell does not report zero charge.")
	cell.give(cell.maxcharge)
	data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["charge_percent"], 100, "Recharging the existing battery did not update the HUD data.")
	var/mob/living/carbon/human/consistent/technician = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(technician.put_in_active_hand(cell, forced = TRUE), "Native inventory movement could not remove the battery.")
	TEST_ASSERT_NULL(pod.battery, "Native battery removal left the installed battery reference behind.")
	data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["battery_present"], FALSE, "A removed battery is still reported as present.")
	TEST_ASSERT_NULL(data["charge_percent"], "A removed battery still exposes its previous charge.")
	pod.hatch_open = TRUE
	TEST_ASSERT(pod.item_interaction(technician, cell, list()) & ITEM_INTERACT_SUCCESS, "The technician could not reinstall the actual battery.")
	var/valid_capacity = cell.maxcharge
	for(var/invalid_capacity in list(0, -1))
		cell.maxcharge = invalid_capacity
		data = pod.get_status_data()
		TEST_ASSERT_EQUAL(data["battery_present"], TRUE, "An invalid-capacity cell was confused with a missing cell.")
		TEST_ASSERT_NULL(data["charge_percent"], "An invalid maximum charge produced a misleading percentage or division by zero.")
	cell.maxcharge = valid_capacity

/// Every hull variant uses its own native maximum, including real damage and repair.
/datum/unit_test/spacepod_status_integrity/Run()
	var/list/pod_maxima = list(/obj/vehicle/sealed/spacepod/civilian = 250, /obj/vehicle/sealed/spacepod/sec = 600)
	for(var/pod_type in pod_maxima)
		var/obj/vehicle/sealed/spacepod/pod = allocate(pod_type)
		var/expected_maximum = pod_maxima[pod_type]
		TEST_ASSERT_EQUAL(pod.max_integrity, expected_maximum, "The integrity fixture has an unexpected native maximum.")
		var/list/data = pod.get_status_data()
		TEST_ASSERT_EQUAL(data["integrity_percent"], 100, "A new hull does not report full integrity.")
		pod.take_damage(pod.max_integrity / 4, BRUTE, MELEE, sound_effect = FALSE)
		data = pod.get_status_data()
		TEST_ASSERT(abs(data["integrity_percent"] - 75) < 0.001, "The reported percentage used the wrong hull maximum or ignored native damage.")
		pod.repair_damage(pod.max_integrity)
		data = pod.get_status_data()
		TEST_ASSERT_EQUAL(data["integrity_percent"], 100, "Native repairs did not restore the reported integrity.")
		pod.take_damage(1, BRUTE, MELEE, sound_effect = FALSE)
		data = pod.get_status_data()
		TEST_ASSERT(abs(data["integrity_percent"] - 100 * (pod.max_integrity - 1) / pod.max_integrity) < 0.001, "The backend rounded away the real hull integrity.")
		pod.update_integrity(2 * pod.max_integrity)
		data = pod.get_status_data()
		TEST_ASSERT_EQUAL(data["integrity_percent"], 100, "An over-max integrity value escaped the HUD's percentage bounds.")
		pod.update_integrity(0)
		data = pod.get_status_data()
		TEST_ASSERT_EQUAL(data["integrity_percent"], 0, "A depleted hull does not report zero integrity.")
		pod.max_integrity = 0
		data = pod.get_status_data()
		TEST_ASSERT_EQUAL(data["integrity_percent"], 0, "A zero maximum hull integrity was not guarded.")
		pod.max_integrity = expected_maximum

/// Partial pressure and standard litres are different measurements of the same real oxygen.
/datum/unit_test/spacepod_status_cabin_measurements/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__)
	var/list/baseline = pod.get_status_data()
	TEST_ASSERT(abs(baseline["cabin_oxygen_kpa"] - 21.27825) < 0.01, "The initial cabin does not report approximately 21.3 kPa of oxygen.")
	TEST_ASSERT(abs(baseline["cabin_oxygen_liters"] - 42) < 0.05, "The 200 L cabin does not initially contain approximately 42 standard litres of oxygen.")
	TEST_ASSERT(abs(baseline["cabin_pressure_kpa"] - ONE_ATMOSPHERE) < 0.01, "Initial cabin total pressure is incorrect.")
	TEST_ASSERT_EQUAL(baseline["using_internal_air"], TRUE, "The initial internal-air mode is missing.")
	TEST_ASSERT_EQUAL(baseline["active_oxygen_kpa"], baseline["cabin_oxygen_kpa"], "Internal mode does not use the cabin's oxygen measurement.")
	pod.cabin_air.set_gas(/datum/gas/nitrogen, 2 * pod.cabin_air.moles[/datum/gas/nitrogen])
	var/list/data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["cabin_oxygen_kpa"], baseline["cabin_oxygen_kpa"], "Adding nitrogen changed the oxygen partial pressure despite unchanged oxygen, temperature and volume.")
	TEST_ASSERT(data["cabin_pressure_kpa"] > baseline["cabin_pressure_kpa"], "Adding nitrogen did not raise the reported total cabin pressure.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_liters"], baseline["cabin_oxygen_liters"], "Adding an inert gas changed the reported oxygen quantity.")
	pod.cabin_air.volume *= 2
	data = pod.get_status_data()
	TEST_ASSERT(abs(data["cabin_oxygen_kpa"] - baseline["cabin_oxygen_kpa"] / 2) < 0.001, "Oxygen partial pressure did not account for the actual cabin volume.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_liters"], baseline["cabin_oxygen_liters"], "Standard oxygen litres incorrectly depend on current cabin volume.")
	pod.cabin_air.temperature *= 2
	data = pod.get_status_data()
	TEST_ASSERT(abs(data["cabin_oxygen_kpa"] - baseline["cabin_oxygen_kpa"]) < 0.001, "Oxygen partial pressure did not account for the actual gas temperature.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_liters"], baseline["cabin_oxygen_liters"], "Standard oxygen litres incorrectly depend on current cabin temperature.")

/// Cabin oxygen must never be inferred from the reserve tank's pressure.
/datum/unit_test/spacepod_status_reserve_separation/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__)
	var/list/baseline = pod.get_status_data()
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	qdel(pod.cabin_air.remove_ratio(1))
	pod.cabin_air.set_gas(/datum/gas/carbon_dioxide, ONE_ATMOSPHERE * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	var/list/data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["tank_pressure_kpa"], baseline["tank_pressure_kpa"], "Replacing cabin air unexpectedly changed the full reserve tank.")
	TEST_ASSERT(data["tank_pressure_kpa"] > ONE_ATMOSPHERE, "The contamination fixture does not have a pressurized reserve tank.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_kpa"], 0, "A full tank concealed an oxygen-free CO2 cabin.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_liters"], 0, "An oxygen-free CO2 cabin falsely reports stored cabin oxygen.")
	TEST_ASSERT_EQUAL(data["active_oxygen_kpa"], 0, "The active oxygen measurement ignores cabin contamination in internal mode.")
	TEST_ASSERT(abs(data["cabin_pressure_kpa"] - ONE_ATMOSPHERE) < 0.01, "The CO2 cabin lost its full total pressure.")
	qdel(pod.cabin_air.remove_ratio(1))
	pod.cabin_air.set_gas(/datum/gas/oxygen, ONE_ATMOSPHERE * O2STANDARD * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	pod.cabin_air.set_gas(/datum/gas/nitrogen, ONE_ATMOSPHERE * N2STANDARD * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	qdel(tank_air.remove_ratio(1))
	data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["tank_pressure_kpa"], 0, "An exhausted reserve tank does not report zero pressure.")
	TEST_ASSERT(abs(data["cabin_oxygen_kpa"] - baseline["cabin_oxygen_kpa"]) < 0.01, "An empty reserve tank concealed the cabin's remaining oxygen.")
	TEST_ASSERT(abs(data["cabin_oxygen_liters"] - baseline["cabin_oxygen_liters"]) < 0.05, "Cabin oxygen quantity incorrectly follows reserve depletion.")

/// A real pilot's air-source toggle must expose vacuum without hiding the cabin's reserve.
/datum/unit_test/spacepod_status_external
	parent_type = /datum/unit_test/spacepod_vacuum

/datum/unit_test/spacepod_status_external/Run()
	TEST_ASSERT_NOTNULL(vacuum_block, "Could not reserve the real vacuum environment.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The status test's pilot could not board in vacuum.")
	var/list/baseline = pod.get_status_data()
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "The pilot could not select real exterior air.")
	TEST_ASSERT_EQUAL(pod.return_air(), vacuum_origin.return_air(), "The exterior status fixture is not using the native exterior atmosphere.")
	var/list/data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["using_internal_air"], FALSE, "The HUD still reports internal air after the real toggle.")
	TEST_ASSERT_EQUAL(data["active_oxygen_kpa"], 0, "Exterior vacuum falsely reports breathable oxygen from the stored cabin air.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_kpa"], baseline["cabin_oxygen_kpa"], "Selecting exterior air discarded the cabin's oxygen measurement.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_liters"], baseline["cabin_oxygen_liters"], "Selecting exterior air discarded the cabin's stored oxygen quantity.")
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "The pilot could not restore the cabin's air supply.")
	data = pod.get_status_data()
	TEST_ASSERT_EQUAL(data["using_internal_air"], TRUE, "The HUD did not restore internal-air mode.")
	TEST_ASSERT_EQUAL(data["active_oxygen_kpa"], data["cabin_oxygen_kpa"], "Restoring internal mode did not restore the actual cabin oxygen reading.")

/// Absent mixtures and invalid volumes remain unavailable; a real vacuum remains zero.
/datum/unit_test/spacepod_status_missing_sources/Run()
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__)
	var/list/baseline = pod.get_status_data()
	var/cabin_volume = pod.cabin_air.volume
	pod.cabin_air.volume = 0
	var/list/data = pod.get_status_data()
	TEST_ASSERT_NULL(data["cabin_oxygen_kpa"], "A zero-volume cabin produced an oxygen pressure reading.")
	TEST_ASSERT_NULL(data["cabin_pressure_kpa"], "A zero-volume cabin produced a total pressure reading.")
	TEST_ASSERT_NULL(data["active_oxygen_kpa"], "A zero-volume active mixture produced an oxygen pressure reading.")
	TEST_ASSERT_EQUAL(data["cabin_oxygen_liters"], baseline["cabin_oxygen_liters"], "A missing pressure denominator erased the independently measurable oxygen quantity.")
	pod.cabin_air.volume = cabin_volume
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	var/tank_volume = tank_air.volume
	tank_air.volume = 0
	data = pod.get_status_data()
	TEST_ASSERT_NULL(data["tank_pressure_kpa"], "A zero-volume reserve tank produced a pressure reading.")
	tank_air.volume = tank_volume
	QDEL_NULL(pod.internal_tank)
	QDEL_NULL(pod.cabin_air)
	pod.moveToNullspace()
	data = pod.get_status_data()
	for(var/measurement in list("cabin_oxygen_kpa", "cabin_oxygen_liters", "cabin_pressure_kpa", "active_oxygen_kpa", "tank_pressure_kpa"))
		TEST_ASSERT_NULL(data[measurement], "Missing gas source produced a stale [measurement] measurement.")

/// Replace only client audio delivery; warning selection and managed sound channels remain real.
/mob/living/carbon/human/consistent/spacepod_alert_listener
	var/list/alert_audio = list()
	var/list/stopped_channels = list()
	var/accept_audio = TRUE

/mob/living/carbon/human/consistent/spacepod_alert_listener/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff_exponent = SOUND_FALLOFF_EXPONENT, channel = 0, pressure_affected = TRUE, sound/sound_to_use, max_distance, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, distance_multiplier = 1, use_reverb = TRUE, wait = FALSE, datum/preference/numeric/volume/volume_preference = null, min_volume = 5)
	if(findtext("[soundin]", "modular_bandastation/spacepods/sound/alerts/") == 1)
		alert_audio += list(list("file" = soundin, "source" = turf_source, "channel" = channel, "volume" = vol, "vary" = vary, "pressure" = pressure_affected, "reverb" = use_reverb, "preference" = volume_preference))
	return accept_audio

/mob/living/carbon/human/consistent/spacepod_alert_listener/stop_sound_channel(chan)
	stopped_channels += chan

/datum/unit_test/spacepod_cabin_alerts
	parent_type = /datum/unit_test/spacepod_vacuum
	abstract_type = /datum/unit_test/spacepod_cabin_alerts
	var/obj/vehicle/sealed/spacepod/civilian/alert_pod
	var/mob/living/carbon/human/consistent/spacepod_alert_listener/alert_pilot

/datum/unit_test/spacepod_cabin_alerts/Destroy()
	alert_pod = null
	alert_pilot = null
	return ..()

/datum/unit_test/spacepod_cabin_alerts/proc/prepare_alert_cabin()
	if(!vacuum_origin)
		return FALSE
	alert_pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	STOP_PROCESSING(SSobj, alert_pod)
	alert_pod.enter_delay = 0
	alert_pod.max_passengers = 2
	alert_pod.max_occupants = 3
	alert_pilot = board_alert_listener()
	return !isnull(alert_pilot)

/datum/unit_test/spacepod_cabin_alerts/proc/board_alert_listener(connected = TRUE)
	var/mob/living/carbon/human/consistent/spacepod_alert_listener/listener = allocate(__IMPLIED_TYPE__, get_step(alert_pod, SOUTH))
	if(connected)
		listener.mock_client = allocate(/datum/client_interface)
	if(!alert_pod.mob_try_enter(listener))
		return
	return listener

/datum/unit_test/spacepod_cabin_alerts/proc/set_cabin_oxygen(pressure_kpa)
	var/datum/gas_mixture/air = alert_pod.cabin_air
	air.set_gas(/datum/gas/oxygen, pressure_kpa * air.volume / (R_IDEAL_GAS_EQUATION * air.temperature))

/datum/unit_test/spacepod_cabin_alerts/proc/set_reserve_oxygen(standard_litres)
	var/datum/gas_mixture/air = alert_pod.internal_tank.return_air()
	air.set_gas(/datum/gas/oxygen, standard_litres * ONE_ATMOSPHERE / (R_IDEAL_GAS_EQUATION * T20C))

/// Boundary crossings rearm only after recovery, and escalation respects the shared audio cooldown.
/datum/unit_test/spacepod_cabin_alerts/battery/Run()
	TEST_ASSERT(prepare_alert_cabin(), "Could not board the battery-warning fixture.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.21
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 0, "A healthy battery generated a warning.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.20
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "The low-battery crossing did not dispatch one warning.")
	var/list/first = alert_pilot.alert_audio[1]
	TEST_ASSERT_EQUAL(first["file"], 'modular_bandastation/spacepods/sound/alerts/battery_low.ogg', "Low charge selected the wrong voice message.")
	TEST_ASSERT_NULL(first["source"], "The cabin voice was made spatial instead of direct.")
	TEST_ASSERT_EQUAL(first["volume"], 55, "The cabin voice changed its intended volume.")
	TEST_ASSERT(!first["vary"] && !first["pressure"] && !first["reverb"], "The cabin voice is randomized, muted by vacuum, or reverberant.")
	TEST_ASSERT_EQUAL(first["preference"], /datum/preference/numeric/volume/sound_tts_volume_announcement, "Cabin voice bypassed the announcement-volume preference.")
	TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(first["channel"])], alert_pod, "Cabin voice did not reserve a managed sound channel.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.24
	alert_pod.process_cabin_alerts()
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.05
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "Escalation interrupted the active warning before its cooldown elapsed.")
	TEST_ASSERT(COOLDOWN_TIMELEFT(alert_pod, cabin_alert_cooldown) > 0, "Dispatch did not start the warning cooldown.")
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 2, "Critical battery charge did not escalate after the cooldown.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[2]["file"], 'modular_bandastation/spacepods/sound/alerts/battery_critical.ogg', "Critical charge selected the wrong voice message.")
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.09
	alert_pod.process_cabin_alerts()
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.05
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 2, "Unrecovered critical charge repeated its warning or replayed the lower warning.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.10
	alert_pod.process_cabin_alerts()
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.05
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 3, "Recovery to ten percent did not rearm the critical warning.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.24
	alert_pod.process_cabin_alerts()
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.20
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 3, "Charge below the recovery boundary rearmed the low warning.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.25
	alert_pod.process_cabin_alerts()
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.20
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 4, "Recovery to twenty-five percent did not rearm the low warning.")

/// Critical breathing, hull and battery warnings are ordered and suppress their weaker counterparts.
/datum/unit_test/spacepod_cabin_alerts/priority/Run()
	TEST_ASSERT(prepare_alert_cabin(), "Could not board the warning-priority fixture.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.05
	set_cabin_oxygen(15.5)
	alert_pod.update_integrity(alert_pod.max_integrity / 4)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "Simultaneous critical faults dispatched overlapping warnings.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[1]["file"], 'modular_bandastation/spacepods/sound/alerts/oxygen_critical.ogg', "Breathing danger did not take priority over hull and battery damage.")
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 2, "The second critical warning was lost.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[2]["file"], 'modular_bandastation/spacepods/sound/alerts/hull_critical.ogg', "Critical hull damage did not take priority over the critical battery.")
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 3, "The critical battery warning was lost.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[3]["file"], 'modular_bandastation/spacepods/sound/alerts/battery_critical.ogg', "The final critical warning selected the wrong voice.")
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 3, "Critical warnings were followed by redundant lower-severity messages.")

/// Selected breathable air and oxygen quantity in the reserve are independent warning sources.
/datum/unit_test/spacepod_cabin_alerts/air_sources/Run()
	TEST_ASSERT(prepare_alert_cabin(), "Could not board the air-warning fixture.")
	set_reserve_oxygen(0)
	var/list/status = alert_pod.get_status_data()
	TEST_ASSERT(status["tank_pressure_kpa"] > ONE_ATMOSPHERE, "The nitrogen-only reserve fixture is not pressurized.")
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "A pressurized nitrogen tank concealed its missing oxygen reserve.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[1]["file"], 'modular_bandastation/spacepods/sound/alerts/reserve_low.ogg', "Reserve depletion was confused with cabin oxygen starvation.")
	set_reserve_oxygen(500)
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	set_reserve_oxygen(0)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "An incompletely refilled reserve rearmed its warning.")
	set_reserve_oxygen(601)
	alert_pod.process_cabin_alerts()
	set_reserve_oxygen(399)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 2, "A recovered reserve did not warn on renewed oxygen depletion.")
	set_reserve_oxygen(1000)
	alert_pod.process_cabin_alerts()
	set_cabin_oxygen(17.5)
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 3, "Low cabin oxygen did not produce a warning.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[3]["file"], 'modular_bandastation/spacepods/sound/alerts/oxygen_low.ogg', "Low cabin oxygen selected the wrong message.")
	set_cabin_oxygen(18.5)
	alert_pod.process_cabin_alerts()
	set_cabin_oxygen(15.5)
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 4, "Cabin oxygen did not escalate to critical.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[4]["file"], 'modular_bandastation/spacepods/sound/alerts/oxygen_critical.ogg', "Critical cabin oxygen selected the wrong message.")
	set_cabin_oxygen(18.5)
	alert_pod.process_cabin_alerts()
	set_cabin_oxygen(17.5)
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 4, "Oxygen that had not fully recovered repeated its lower warning.")
	set_cabin_oxygen(20.5)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT(alert_pod.toggle_internal_tank(alert_pilot), "The pilot could not select exterior vacuum.")
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 5, "A full unused tank concealed the selected exterior vacuum.")
	TEST_ASSERT_EQUAL(alert_pilot.alert_audio[5]["file"], 'modular_bandastation/spacepods/sound/alerts/oxygen_critical.ogg', "Exterior vacuum did not select the critical breathing warning.")
	TEST_ASSERT(alert_pod.toggle_internal_tank(alert_pilot), "The pilot could not restore healthy cabin air.")
	alert_pod.process_cabin_alerts()
	var/valid_volume = alert_pod.cabin_air.volume
	alert_pod.cabin_air.volume = 0
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 6, "An invalid active mixture did not warn about unavailable breathable air.")
	alert_pod.cabin_air.volume = valid_volume
	alert_pod.process_cabin_alerts()
	QDEL_NULL(alert_pod.cabin_air)
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 7, "A missing cabin mixture concealed the fallback exterior vacuum.")

/// Only current connected occupants hear warnings, and every departure releases its owned channel.
/datum/unit_test/spacepod_cabin_alerts/audience/Run()
	TEST_ASSERT(prepare_alert_cabin(), "Could not board the warning-audience fixture.")
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.20
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "The initial pilot did not receive the warning.")
	var/channel = alert_pod.cabin_alert_channel
	var/mob/living/carbon/human/consistent/spacepod_alert_listener/passenger = board_alert_listener()
	var/mob/living/carbon/human/consistent/spacepod_alert_listener/npc = board_alert_listener(connected = FALSE)
	TEST_ASSERT_NOTNULL(passenger, "The new passenger could not board.")
	TEST_ASSERT_NOTNULL(npc, "The disconnected control occupant could not board.")
	var/mob/living/carbon/human/consistent/spacepod_alert_listener/outsider = allocate(__IMPLIED_TYPE__, get_step(alert_pod, SOUTH))
	outsider.mock_client = allocate(/datum/client_interface)
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(passenger.alert_audio), 1, "A newly boarded passenger missed the existing fault.")
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "A new passenger replayed an already-heard warning to the pilot.")
	TEST_ASSERT_EQUAL(length(npc.alert_audio), 0, "A clientless occupant received cabin audio.")
	TEST_ASSERT_EQUAL(length(outsider.alert_audio), 0, "Cabin voice leaked to an adjacent outsider.")
	TEST_ASSERT(alert_pod.mob_exit(passenger, silent = TRUE), "The warned passenger could not exit.")
	TEST_ASSERT(channel in passenger.stopped_channels, "Ejection did not stop that passenger's warning channel.")
	TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(channel)], alert_pod, "One passenger's departure freed the remaining pilot's warning channel.")
	alert_pilot.mock_client = null
	alert_pilot.Logout()
	TEST_ASSERT(channel in alert_pilot.stopped_channels, "Logout did not stop the former pilot's warning channel.")
	TEST_ASSERT_NULL(alert_pod.cabin_alert_channel, "The empty audience retained its warning channel.")
	TEST_ASSERT(SSsounds.using_channels[num2text(channel)] != alert_pod && !length(SSsounds.using_channels_by_datum[alert_pod]), "The empty audience leaked managed sound-channel ownership.")
	COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
	var/mob/living/carbon/human/consistent/spacepod_alert_listener/newcomer = board_alert_listener()
	TEST_ASSERT_NOTNULL(newcomer, "A new connected listener could not enter the occupied cabin.")
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(newcomer.alert_audio), 1, "A new audience missed the persistent cabin fault.")
	channel = alert_pod.cabin_alert_channel
	TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(channel)], alert_pod, "The renewed audience has no managed warning channel.")
	qdel(alert_pod)
	TEST_ASSERT(channel in newcomer.stopped_channels, "QDELETING did not stop the remaining listener's warning.")
	TEST_ASSERT(SSsounds.using_channels[num2text(channel)] != alert_pod && !length(SSsounds.using_channels_by_datum[alert_pod]), "Deleting the cabin leaked its warning channel.")

/// Muted or otherwise rejected audio is attempted once, and shipped voices are valid native sounds.
/datum/unit_test/spacepod_cabin_alerts/declined_audio/Run()
	TEST_ASSERT(prepare_alert_cabin(), "Could not board the declined-audio fixture.")
	alert_pilot.accept_audio = FALSE
	alert_pod.battery.charge = alert_pod.battery.maxcharge * 0.20
	alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "The declined voice was not attempted once.")
	for(var/retry in 1 to 3)
		COOLDOWN_RESET(alert_pod, cabin_alert_cooldown)
		alert_pod.process_cabin_alerts()
	TEST_ASSERT_EQUAL(length(alert_pilot.alert_audio), 1, "Declined or muted audio was retried while the same fault persisted.")
	var/list/voices = list(
		'modular_bandastation/spacepods/sound/alerts/battery_low.ogg',
		'modular_bandastation/spacepods/sound/alerts/battery_critical.ogg',
		'modular_bandastation/spacepods/sound/alerts/oxygen_low.ogg',
		'modular_bandastation/spacepods/sound/alerts/oxygen_critical.ogg',
		'modular_bandastation/spacepods/sound/alerts/reserve_low.ogg',
		'modular_bandastation/spacepods/sound/alerts/hull_low.ogg',
		'modular_bandastation/spacepods/sound/alerts/hull_critical.ogg',
	)
	for(var/voice in voices)
		var/length_ds = SSsounds.get_sound_length(voice)
		TEST_ASSERT(length_ds > 0 && length_ds < 6 SECONDS, "A shipped cabin voice is invalid or longer than its playback cooldown: [voice].")
