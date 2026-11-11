/mob/living/carbon/human
	var/obj/item/clothing/underwear/w_underwear
	var/obj/item/clothing/underwear/shirt/w_undershirt
	var/obj/item/clothing/underwear/socks/w_socks
	/// Prevents inventory callbacks from re-entering appearance synchronization.
	var/syncing_underclothing = FALSE

/// Keep the existing preference/save format and appearance-changing callers working.
/mob/living/carbon/human/proc/sync_underclothing()
	if(syncing_underclothing || QDELETED(src) || !SSaccessories.underwear_list || istype(src, /mob/living/carbon/human/dummy))
		return
	syncing_underclothing = TRUE
	sync_underclothing_slot("underwear", SSaccessories.underwear_list, /obj/item/clothing/underwear, underwear_color)
	sync_underclothing_slot("undershirt", SSaccessories.undershirt_list, /obj/item/clothing/underwear/shirt)
	sync_underclothing_slot("socks", SSaccessories.socks_list, /obj/item/clothing/underwear/socks)
	syncing_underclothing = FALSE

/mob/living/carbon/human/proc/sync_underclothing_slot(key, list/styles, obj/item/clothing/underwear/item_type, tint = COLOR_WHITE)
	var/datum/sprite_accessory/clothing/style = styles[vars[key]]
	var/obj/item/clothing/underwear/garment = vars["w_[key]"]
	if(HAS_TRAIT(src, TRAIT_NO_UNDERWEAR))
		if(garment)
			dropItemToGround(garment, TRUE)
		return
	if(!style?.icon_state)
		if(garment)
			vars["w_[key]"] = null
			qdel(garment)
			hud_used?.update_inventory_slot(initial(item_type.slot_flags))
		return
	if(garment)
		if(garment.accessory != style || garment.garment_color != tint)
			garment.set_style(style, tint)
		return
	garment = new item_type(src, style, tint)
	// Generic hand/stack dispatch may yield; appearance updates must not block.
	INVOKE_ASYNC(src, PROC_REF(equip_to_slot), garment, garment.slot_flags, TRUE)

/mob/living/carbon/human/proc/wear_underclothing(obj/item/clothing/underwear/garment)
	vars["w_[garment.appearance_key]"] = garment
	vars[garment.appearance_key] = garment.accessory.name
	if(garment.slot_flags == ITEM_SLOT_UNDERWEAR)
		underwear_color = garment.garment_color
	update_body()
	hud_used?.update_inventory_slot(garment.slot_flags)

/mob/living/carbon/human/proc/remove_underclothing(obj/item/clothing/underwear/garment)
	vars["w_[garment.appearance_key]"] = null
	vars[garment.appearance_key] = "Nude"
	if(!QDELETED(src))
		update_body()
		hud_used?.update_inventory_slot(garment.slot_flags)

/// Clothing covering the relevant body area must be removed first.
/mob/living/carbon/human/proc/underclothing_hidden(slot)
	var/covered = (w_uniform?.body_parts_covered || NONE)|(wear_suit?.body_parts_covered || NONE)
	switch(slot)
		if(ITEM_SLOT_UNDERWEAR)
			return !!(covered & GROIN)
		if(ITEM_SLOT_UNDERSHIRT)
			return !!(covered & CHEST)
		if(ITEM_SLOT_SOCKS)
			return !!((covered|(shoes?.body_parts_covered || NONE)) & FEET)
	return FALSE

/mob/living/carbon/human/proc/can_wear_underclothing(slot)
	if(HAS_TRAIT(src, TRAIT_NO_UNDERWEAR) || underclothing_hidden(slot))
		return FALSE
	if(slot == ITEM_SLOT_SOCKS && (num_legs < 2 || (bodyshape & BODYSHAPE_DIGITIGRADE)))
		return FALSE
	return TRUE
