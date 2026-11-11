/// Cabin telemetry belongs only to a current occupant, independently of pilot controls.
/obj/vehicle/sealed/spacepod/proc/can_view_status(mob/user)
	return !QDELETED(src) && !QDELETED(user) && isliving(user) && is_occupant(user) && user.loc == src

/obj/vehicle/sealed/spacepod/ui_status(mob/user, datum/ui_state/state)
	// The native window dims UI_UPDATE; this monitor has no vehicle ui_act commands.
	return can_view_status(user) ? UI_INTERACTIVE : UI_CLOSE

/obj/vehicle/sealed/spacepod/ui_interact(mob/user, datum/tgui/ui)
	if(!can_view_status(user))
		SStgui.close_user_uis(user, src)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SpacepodStatus", "Состояние челнока")
		if(!ui.open())
			qdel(ui)

/obj/vehicle/sealed/spacepod/ui_data(mob/user)
	if(!can_view_status(user))
		return list()
	var/list/data = get_status_data()
	data["name"] = declent_ru(NOMINATIVE)
	data["cabin_temperature_k"] = cabin_air?.temperature
	data["lights_on"] = !!lights
	data["locked"] = !unlocked
	data["occupant_count"] = occupant_amount()
	data["occupant_capacity"] = max_occupants
	return data
