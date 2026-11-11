/datum/inventory_slot/human/underwear
	name = "нижнее бельё"
	slot_id = ITEM_SLOT_UNDERWEAR
	screen_group = HUD_GROUP_TOGGLEABLE_INVENTORY

/datum/inventory_slot/human/undershirt
	name = "майка"
	slot_id = ITEM_SLOT_UNDERSHIRT
	screen_group = HUD_GROUP_TOGGLEABLE_INVENTORY

/datum/inventory_slot/human/socks
	name = "носки"
	slot_id = ITEM_SLOT_SOCKS
	screen_group = HUD_GROUP_TOGGLEABLE_INVENTORY

/datum/strippable_item/mob_item_slot/underclothing
	key = "underwear"
	item_slot = ITEM_SLOT_UNDERWEAR

/datum/strippable_item/mob_item_slot/underclothing/shirt
	key = "undershirt"
	item_slot = ITEM_SLOT_UNDERSHIRT

/datum/strippable_item/mob_item_slot/underclothing/socks
	key = "socks"
	item_slot = ITEM_SLOT_SOCKS

/datum/strippable_item/mob_item_slot/underclothing/should_show(atom/source, mob/user)
	return ishuman(source) && !HAS_TRAIT(source, TRAIT_NO_UNDERWEAR)

/datum/strippable_item/mob_item_slot/underclothing/get_obscuring(atom/source)
	var/mob/living/carbon/human/wearer = source
	if(wearer.underclothing_hidden(item_slot))
		return STRIPPABLE_OBSCURING_COMPLETELY
	return ..()

/datum/strippable_item/mob_item_slot/underclothing/finish_equip(atom/source, obj/item/equipping, mob/user)
	// Outer clothing or stripping permissions may have changed during do_after.
	if(QDELETED(equipping))
		return FALSE
	if(!user.can_perform_action(source, FORBID_TELEKINESIS_REACH|ALLOW_RESTING) || !try_equip(source, equipping, user))
		INVOKE_ASYNC(user, TYPE_PROC_REF(/mob, put_in_hands), equipping)
		return FALSE
	return ..()

/datum/strippable_item/mob_item_slot/underclothing/finish_unequip(atom/source, mob/user)
	if(!user.can_perform_action(source, FORBID_TELEKINESIS_REACH|ALLOW_RESTING) || get_obscuring(source) != STRIPPABLE_OBSCURING_NONE || !try_unequip(source, user))
		return FALSE
	var/obj/item/worn_item = get_item(source)
	if(HAS_TRAIT(worn_item, TRAIT_NO_STRIP))
		return FALSE
	return ..()
