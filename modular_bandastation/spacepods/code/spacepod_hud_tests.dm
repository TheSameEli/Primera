/// Both real occupant roles receive the status action immediately before Eject in the native default list.
/datum/unit_test/spacepod_ui_actions/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	pilot.set_hud_used(new pilot.hud_type(pilot))
	passenger.set_hud_used(new passenger.hud_type(passenger))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The status-action pilot could not board.")
	TEST_ASSERT(pod.mob_try_enter(passenger), "The status-action passenger could not board.")
	for(var/mob/living/user as anything in list(pilot, passenger))
		var/datum/action/vehicle/sealed/spacepod/status/status_action = pod.occupant_actions[user][/datum/action/vehicle/sealed/spacepod/status]
		var/datum/action/vehicle/sealed/spacepod/eject/eject_action = pod.occupant_actions[user][/datum/action/vehicle/sealed/spacepod/eject]
		TEST_ASSERT_NOTNULL(status_action, "A boarded occupant did not receive the status action.")
		TEST_ASSERT_NOTNULL(eject_action, "A boarded occupant did not receive Eject.")
		TEST_ASSERT(status_action.IsAvailable(), "The status action is unavailable to a conscious occupant.")
		var/atom/movable/screen/movable/action_button/status_button = status_action.viewers[user.hud_used]
		var/atom/movable/screen/movable/action_button/eject_button = eject_action.viewers[user.hud_used]
		TEST_ASSERT_NOTNULL(status_button, "The status action has no real native HUD button.")
		TEST_ASSERT_NOTNULL(eject_button, "Eject has no real native HUD button.")
		var/status_index = user.hud_used.listed_actions.index_of(status_button)
		var/eject_index = user.hud_used.listed_actions.index_of(eject_button)
		TEST_ASSERT(status_index > 0 && eject_index == status_index + 1, "Status is not immediately before Eject in the native default action list.")
		TEST_ASSERT(status_action.button_icon_state in icon_states(status_action.button_icon), "The status action references a missing icon state.")
		TEST_ASSERT(status_action.Trigger(user), "A real status action rejected its boarded owner.")
	TEST_ASSERT(!pod.can_control(passenger), "Opening read-only status granted the passenger pilot controls.")
	var/datum/tgui/ui = allocate(/datum/tgui, passenger, pod, "SpacepodStatus")
	var/charge_before = pod.battery.charge
	var/lights_before = pod.lights
	var/air_before = pod.use_internal_tank
	for(var/forged_action in list("fire", "eject", "exit", "toggle_lights", "toggle_internal_tank"))
		pod.ui_act(forged_action, list(), ui, ui.state)
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_before, "A forged status UI command used vehicle power.")
	TEST_ASSERT_EQUAL(pod.lights, lights_before, "A forged status UI command toggled the vehicle lights.")
	TEST_ASSERT_EQUAL(pod.use_internal_tank, air_before, "A forged status UI command changed the breathing source.")
	TEST_ASSERT_EQUAL(passenger.loc, pod, "A forged status UI command ejected its passenger.")

/// Telemetry permission requires both native occupant registration and physical presence.
/datum/unit_test/spacepod_ui_access/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/outsider = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The status-access pilot could not board.")
	TEST_ASSERT(pod.can_view_status(pilot), "The actual occupant cannot view cabin telemetry.")
	TEST_ASSERT_EQUAL(pod.ui_status(pilot), UI_INTERACTIVE, "A legitimate status window is disabled or dimmed.")
	TEST_ASSERT(length(pod.ui_data(pilot)), "An actual occupant received no telemetry.")
	TEST_ASSERT(!pod.can_view_status(outsider) && !pod.can_view_status(null), "An outsider or null user passed cabin telemetry authorization.")
	TEST_ASSERT_EQUAL(pod.ui_status(outsider), UI_CLOSE, "An outsider's cabin status window remains open.")
	TEST_ASSERT_EQUAL(length(pod.ui_data(outsider)), 0, "Cabin telemetry leaked to an outsider.")
	// A stale registration alone must not authorize a mob physically outside the cabin.
	pod.occupants[outsider] = NONE
	var/stale_allowed = pod.can_view_status(outsider)
	var/stale_status = pod.ui_status(outsider)
	var/list/stale_data = pod.ui_data(outsider)
	pod.occupants -= outsider
	TEST_ASSERT(!stale_allowed, "A stale occupant registration authorized a mob outside the cabin.")
	TEST_ASSERT_EQUAL(stale_status, UI_CLOSE, "A stale occupant registration retained a status window.")
	TEST_ASSERT_EQUAL(length(stale_data), 0, "A stale occupant registration leaked live telemetry.")
	TEST_ASSERT(pod.mob_exit(pilot, silent = TRUE), "The status-access pilot could not leave.")
	TEST_ASSERT(!pod.can_view_status(pilot), "Leaving the cabin retained telemetry authorization.")
	TEST_ASSERT_EQUAL(pod.ui_status(pilot), UI_CLOSE, "Leaving retained an authorized status window.")
	TEST_ASSERT_EQUAL(length(pod.ui_data(pilot)), 0, "A former occupant retained live telemetry.")

/// Only browser/client registration is omitted; UI close and all native registry cleanup remain real.
/datum/tgui_window/spacepod_unit_test/New()
	id = "spacepod-unit-test"

/datum/unit_test/spacepod_ui_lifecycle/proc/register_status_ui(mob/user, obj/vehicle/sealed/spacepod/pod)
	var/datum/tgui/ui = allocate(/datum/tgui, user, pod, "SpacepodStatus")
	ui.window = allocate(/datum/tgui_window/spacepod_unit_test)
	ui.initialized = TRUE
	ui.opened_at = world.time
	ui.window.acquire_lock(ui)
	SStgui.on_open(ui)
	return ui

/// Revalidation, disembarking and deletion close actual tgui datums and remove every native reference.
/datum/unit_test/spacepod_ui_lifecycle/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/mob/living/carbon/human/consistent/outsider = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot) && pod.mob_try_enter(passenger), "The status lifecycle occupants could not board.")
	var/datum/tgui/pilot_ui = register_status_ui(pilot, pod)
	var/datum/tgui/passenger_ui = register_status_ui(passenger, pod)
	var/datum/tgui/outsider_ui = register_status_ui(outsider, pod)
	TEST_ASSERT((pilot_ui in SStgui.all_uis) && (pilot_ui in pilot.tgui_open_uis) && (pilot_ui in pod.open_uis), "The fixture did not register a real native status UI.")
	pod.ui_interact(outsider, outsider_ui)
	TEST_ASSERT(QDELETED(outsider_ui), "ui_interact did not close a window after authorization failed.")
	TEST_ASSERT(!(outsider_ui in SStgui.all_uis) && !(outsider_ui in outsider.tgui_open_uis) && !(outsider_ui in pod.open_uis), "Revalidation left an unauthorized UI in native registries.")
	var/datum/tgui_window/pilot_window = pilot_ui.window
	TEST_ASSERT(pod.mob_exit(pilot, silent = TRUE), "The status-window pilot could not disembark.")
	TEST_ASSERT(QDELETED(pilot_ui), "Disembarking retained the pilot's status UI.")
	TEST_ASSERT(!(pilot_ui in SStgui.all_uis) && !(pilot_ui in pilot.tgui_open_uis) && !(pilot_ui in pod.open_uis), "Disembarking retained a native UI registry reference.")
	TEST_ASSERT(!pilot_window.locked && isnull(pilot_window.locked_by), "Closing a departed pilot's UI retained its native window lock.")
	TEST_ASSERT(!QDELETED(passenger_ui) && (passenger_ui in pod.open_uis), "The pilot leaving closed the remaining passenger's status UI.")
	qdel(pod)
	TEST_ASSERT(QDELETED(passenger_ui), "Deleting the cabin retained the passenger's status UI.")
	TEST_ASSERT(!(passenger_ui in SStgui.all_uis) && !(passenger_ui in passenger.tgui_open_uis), "Deleting the cabin retained a native UI registry reference.")
	TEST_ASSERT(!length(pod.open_uis), "A deleted cabin retains an open UI list.")
	TEST_ASSERT(!pod.can_view_status(passenger), "A deleted cabin still authorizes telemetry access.")

/// ui_data must reflect real changing supplies and the selected air source for both occupant roles.
/datum/unit_test/spacepod_vacuum/ui_live/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve actual vacuum for status UI telemetry.")
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot) && pod.mob_try_enter(passenger), "The live status UI occupants could not board.")
	var/list/initial_data = pod.ui_data(passenger)
	TEST_ASSERT_EQUAL(initial_data["charge_percent"], 100, "The UI did not expose the real full battery.")
	TEST_ASSERT_EQUAL(initial_data["integrity_percent"], 100, "The UI did not expose the real intact hull.")
	TEST_ASSERT_EQUAL(initial_data["occupant_count"], 2, "The status UI omitted the real cabin occupant count.")
	TEST_ASSERT_EQUAL(initial_data["occupant_capacity"], pod.max_occupants, "The status UI exposed the wrong cabin capacity.")
	TEST_ASSERT(length(initial_data["name"]), "The status UI did not expose the cabin name.")
	TEST_ASSERT(pod.battery.use(pod.battery.charge / 4), "The real battery could not be partially discharged.")
	pod.take_damage(pod.max_integrity / 4, BRUTE, MELEE, sound_effect = FALSE)
	var/datum/gas_mixture/removed_air = pod.cabin_air.remove_ratio(0.5)
	// Native gas transfer quantizes moles, so compare against the actual remaining share.
	var/remaining_oxygen_ratio = pod.cabin_air.moles[/datum/gas/oxygen] / (pod.cabin_air.moles[/datum/gas/oxygen] + removed_air.moles[/datum/gas/oxygen])
	qdel(removed_air)
	var/list/updated_data = pod.ui_data(passenger)
	TEST_ASSERT_EQUAL(updated_data["charge_percent"], 75, "The status UI retained a stale battery percentage.")
	TEST_ASSERT_EQUAL(updated_data["integrity_percent"], 75, "The status UI retained stale hull integrity.")
	TEST_ASSERT(abs(updated_data["cabin_oxygen_liters"] - initial_data["cabin_oxygen_liters"] * remaining_oxygen_ratio) < 0.001, "The status UI retained stale cabin oxygen quantity.")
	TEST_ASSERT(abs(updated_data["cabin_oxygen_kpa"] - initial_data["cabin_oxygen_kpa"] * remaining_oxygen_ratio) < 0.001, "The status UI retained stale cabin oxygen pressure.")
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "The pilot could not select the real external vacuum.")
	updated_data = pod.ui_data(passenger)
	TEST_ASSERT(!updated_data["using_internal_air"], "The status UI retained the old breathing source.")
	TEST_ASSERT_EQUAL(updated_data["active_oxygen_kpa"], 0, "The status UI concealed the selected external vacuum.")
	TEST_ASSERT(updated_data["cabin_oxygen_liters"] > 0, "Selecting external vacuum incorrectly emptied the isolated cabin reading.")
	var/list/pilot_data = pod.ui_data(pilot)
	TEST_ASSERT_EQUAL(pilot_data["charge_percent"], updated_data["charge_percent"], "Pilot and passenger receive inconsistent live telemetry.")
	TEST_ASSERT(!pod.can_control(passenger), "Reading live status granted the passenger control authorization.")
	var/obj/item/stock_parts/power_store/cell/battery = pod.battery
	battery.forceMove(vacuum_origin)
	QDEL_NULL(pod.cabin_air)
	updated_data = pod.ui_data(passenger)
	TEST_ASSERT(!updated_data["battery_present"] && isnull(updated_data["charge_percent"]), "The UI confused a missing battery with a charged or depleted installed battery.")
	TEST_ASSERT(isnull(updated_data["cabin_oxygen_liters"]) && isnull(updated_data["cabin_oxygen_kpa"]), "The UI confused missing cabin measurements with measured zero.")
