// Adapted from BlueMoon-Station's removable underclothing; uses this build's existing sprite accessories.
/obj/item/clothing/underwear
	name = "underwear"
	desc = "Нижнее бельё."
	icon = 'icons/mob/clothing/underwear.dmi'
	icon_state = "male_briefs"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_UNDERWEAR
	body_parts_covered = GROIN
	/// Existing human appearance field represented by this item.
	var/appearance_key = "underwear"
	/// Shared accessory singleton, owned by SSaccessories.
	var/datum/sprite_accessory/clothing/accessory
	var/garment_color = COLOR_BLACK

/obj/item/clothing/underwear/Initialize(mapload, datum/sprite_accessory/clothing/style, tint = COLOR_BLACK)
	. = ..()
	slot_equipment_priority = list(slot_flags)
	if(style)
		set_style(style, tint)
	else
		switch(slot_flags)
			if(ITEM_SLOT_UNDERWEAR)
				set_style(SSaccessories.underwear_list[/datum/sprite_accessory/clothing/underwear/male_briefs::name], tint)
			if(ITEM_SLOT_UNDERSHIRT)
				set_style(SSaccessories.undershirt_list[/datum/sprite_accessory/clothing/undershirt/sports_bra::name], tint)
			if(ITEM_SLOT_SOCKS)
				set_style(SSaccessories.socks_list[/datum/sprite_accessory/clothing/socks/black_knee::name], tint)

/obj/item/clothing/underwear/Destroy()
	accessory = null
	return ..()

/// Reuses the existing color, greyscale and static-pattern rendering for loose items.
/obj/item/clothing/underwear/proc/set_style(datum/sprite_accessory/clothing/style, tint)
	accessory = style
	garment_color = tint
	desc = "[initial(desc)] Модель: [style.name]."
	var/mutable_appearance/rendered = style.make_appearance(tint)
	icon = rendered.icon
	icon_state = rendered.icon_state
	if(slot_flags == ITEM_SLOT_SOCKS)
		// Body-aligned socks sit at the feet; center only the loose-item copy.
		var/icon/centered_socks = icon(icon, icon_state)
		centered_socks.Shift(NORTH, 12)
		icon = centered_socks
		icon_state = ""
	color = rendered.color
	update_appearance()

/obj/item/clothing/underwear/can_mob_unequip(mob/user)
	. = ..()
	if(!. || !ishuman(user) || user.get_item_by_slot(slot_flags) != src)
		return .
	var/mob/living/carbon/human/wearer = user
	if(wearer.underclothing_hidden(slot_flags))
		balloon_alert(user, "сначала снимите верхнюю одежду!")
		return FALSE

/obj/item/clothing/underwear/attack_self(mob/user, list/modifiers)
	. = ..()
	if(!. && user.is_holding(src) && user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return user.equip_to_slot_if_possible(src, slot_flags)

/obj/item/clothing/underwear/shirt
	name = "undershirt"
	desc = "Майка или бельё для верхней части тела."
	appearance_key = "undershirt"
	slot_flags = ITEM_SLOT_UNDERSHIRT
	body_parts_covered = CHEST

/obj/item/clothing/underwear/socks
	name = "socks"
	desc = "Пара носков или чулок."
	appearance_key = "socks"
	slot_flags = ITEM_SLOT_SOCKS
	body_parts_covered = FEET
