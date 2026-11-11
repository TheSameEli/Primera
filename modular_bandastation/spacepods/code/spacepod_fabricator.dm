/// Keep the native material, stock-part, queue and output machinery with an engineering-only catalog.
/obj/machinery/mecha_part_fabricator/spacepod
	name = "spacepod fabricator"
	desc = "Фабрикатор деталей, брони и оборудования космических челноков."
	req_access = list(ACCESS_ENGINE_EQUIP)
	circuit = /obj/item/circuitboard/machine/mechfab/spacepod
	allowed_buildtypes = PODFAB

/obj/machinery/mecha_part_fabricator/spacepod/ui_interact(mob/user, datum/tgui/ui)
	if(!allowed(user))
		balloon_alert(user, "в доступе отказано!")
		return
	return ..()

/obj/machinery/mecha_part_fabricator/spacepod/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	// Revalidate the current ID for every request, including an already-open interface.
	if(QDELETED(ui) || QDELETED(ui.user) || !allowed(ui.user))
		return FALSE
	return ..()

/obj/item/circuitboard/machine/mechfab/spacepod
	name = "Spacepod Fabricator"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/mecha_part_fabricator/spacepod

/datum/design/board/spacepod_fabricator
	name = "Spacepod Fabricator Board"
	desc = "Плата инженерного фабрикатора деталей и оборудования космических челноков."
	build_type = IMPRINTER
	build_path = /obj/item/circuitboard/machine/mechfab/spacepod
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_FAB)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
