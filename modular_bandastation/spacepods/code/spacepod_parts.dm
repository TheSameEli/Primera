/// Adapted from ss220-space/Paradise, code/modules/spacepods/parts.dm (AGPL-3.0).
/obj/item/pod_parts
	parent_type = /obj/item/mecha_parts
	abstract_type = /obj/item/pod_parts
	icon = 'modular_bandastation/spacepods/icons/pod_parts.dmi'
	icon_state = null

/obj/item/pod_parts/core
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/uranium = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "space pod core"
	desc = "Двигатель и система жизнеобеспечения космического челнока."
	icon_state = "core"

/obj/item/pod_parts/armor
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 5)
	name = "civilian pod armor"
	desc = "Комплект лёгкой брони для гражданского космического челнока."
	icon_state = "pod_armor_civ"

/obj/item/circuitboard/mecha/pod
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "Space Pod Mainboard (Exosuit Board)"
	icon_state = "mainboard"

/obj/item/pod_parts/pod_frame
	name = "space pod frame component"
	abstract_type = /obj/item/pod_parts/pod_frame
	interaction_flags_item = NONE
	/// Next distinct frame part, clockwise around the assembled square.
	var/link_to
	/// Direction to the next part, relative to the common facing of the four parts.
	var/link_angle = 0

/obj/item/pod_parts/pod_frame/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_rotation)

/// Return exactly four anchored, distinct parts forming a closed, equally oriented square.
/obj/item/pod_parts/pod_frame/proc/find_square()
	if(!isturf(loc) || !anchored || !(dir in GLOB.cardinals))
		return null
	var/list/needed_parts = list(
		/obj/item/pod_parts/pod_frame/aft_port,
		/obj/item/pod_parts/pod_frame/aft_starboard,
		/obj/item/pod_parts/pod_frame/fore_port,
		/obj/item/pod_parts/pod_frame/fore_starboard,
	)
	var/list/connected_parts = list()
	var/obj/item/pod_parts/pod_frame/current_part = src
	for(var/part_index in 1 to 4)
		if(!(current_part.type in needed_parts))
			return null
		needed_parts -= current_part.type
		connected_parts += current_part
		var/turf/next_turf = get_step(current_part, turn(dir, -current_part.link_angle))
		var/obj/item/pod_parts/pod_frame/next_part
		for(var/obj/item/pod_parts/pod_frame/candidate in next_turf)
			if(candidate.type == current_part.link_to && candidate.dir == dir && candidate.anchored)
				next_part = candidate
				break
		if(!next_part)
			return null
		current_part = next_part
	if(current_part != src || length(needed_parts))
		return null
	return connected_parts

/obj/item/pod_parts/pod_frame/item_interaction(mob/living/user, obj/item/used_item, list/modifiers)
	if(!istype(used_item, /obj/item/stack/rods))
		return NONE
	if(!user.can_perform_action(src, NEED_DEXTERITY|NEED_HANDS) || !user.is_holding(used_item))
		return ITEM_INTERACT_BLOCKING
	var/list/connected_parts = find_square()
	if(!connected_parts)
		balloon_alert(user, "нужны четыре закреплённые секции!")
		return ITEM_INTERACT_BLOCKING
	var/anchor_x = x
	var/anchor_y = y
	for(var/obj/item/pod_parts/pod_frame/frame as anything in connected_parts)
		anchor_x = min(anchor_x, frame.x)
		anchor_y = min(anchor_y, frame.y)
		var/turf/frame_turf = frame.loc
		if(frame_turf.is_blocked_turf(ignore_atoms = connected_parts))
			balloon_alert(user, "каркас заблокирован!")
			return ITEM_INTERACT_BLOCKING
	var/turf/anchor_turf = locate(anchor_x, anchor_y, z)
	var/obj/item/stack/rods/rods = used_item
	if(!rods.use(10))
		balloon_alert(user, "нужно 10 стержней!")
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/spacepod_frame/chassis = new(anchor_turf)
	chassis.add_fingerprint(user)
	for(var/obj/item/pod_parts/pod_frame/frame as anything in connected_parts)
		frame.transfer_fingerprints_to(chassis)
		qdel(frame)
	to_chat(user, span_notice("Вы укрепляете каркас челнока стержнями."))
	return ITEM_INTERACT_SUCCESS

/obj/item/pod_parts/pod_frame/wrench_act(mob/living/user, obj/item/tool)
	if(!isturf(loc))
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 0, volume = 50))
		return ITEM_INTERACT_BLOCKING
	set_anchored(!anchored)
	set_density(anchored)
	balloon_alert(user, anchored ? "секция закреплена" : "крепления ослаблены")
	return ITEM_INTERACT_SUCCESS

/obj/item/pod_parts/pod_frame/fore_port
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "fore port pod frame"
	desc = "Передняя левая секция каркаса космического челнока."
	icon_state = "pod_fp"
	link_to = /obj/item/pod_parts/pod_frame/fore_starboard
	link_angle = 90

/obj/item/pod_parts/pod_frame/fore_starboard
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "fore starboard pod frame"
	desc = "Передняя правая секция каркаса космического челнока."
	icon_state = "pod_fs"
	link_to = /obj/item/pod_parts/pod_frame/aft_starboard
	link_angle = 180

/obj/item/pod_parts/pod_frame/aft_port
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "aft port pod frame"
	desc = "Задняя левая секция каркаса космического челнока."
	icon_state = "pod_ap"
	link_to = /obj/item/pod_parts/pod_frame/fore_port

/obj/item/pod_parts/pod_frame/aft_starboard
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "aft starboard pod frame"
	desc = "Задняя правая секция каркаса космического челнока."
	icon_state = "pod_as"
	link_to = /obj/item/pod_parts/pod_frame/aft_port
	link_angle = 270
