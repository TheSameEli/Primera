// AI EDIT START - Implement and verify independent ear slots
/mob/living/carbon/human
	/// Secondary inventory slots reserved by clothing, keyed by stringified slot bit.
	var/list/occupied_clothing_slots

/// Reserve additional clothing slots while keeping one real equipment slot and one set of effects.
/datum/component/occupies_slots
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/occupied_slots
	var/primary_slot = NONE
	var/datum/weakref/wearer_ref

/datum/component/occupies_slots/Initialize(occupied_slots)
	if(!isitem(parent) || !isnum(occupied_slots) || occupied_slots <= 0 || round(occupied_slots) != occupied_slots || (occupied_slots & ~(ITEM_SLOT_ON_BODY | ITEM_SLOT_STORAGE)))
		return COMPONENT_INCOMPATIBLE
	src.occupied_slots = occupied_slots

/datum/component/occupies_slots/RegisterWithParent()
	// UNIQUE creates a temporary duplicate; only the retained component owns reservations.
	if(parent.GetComponent(type) != src)
		return
	RegisterSignal(parent, COMSIG_ITEM_EQUIP_CHECK, PROC_REF(on_equip_check))
	RegisterSignal(parent, COMSIG_ITEM_POST_EQUIPPED, PROC_REF(on_equipped))
	RegisterSignal(parent, COMSIG_ITEM_DROPPED, PROC_REF(on_dropped))
	RegisterSignal(parent, COMSIG_ATOM_UPDATED_ICON, PROC_REF(on_icon_updated))
	var/obj/item/item = parent
	var/mob/living/carbon/human/current_wearer = item.loc
	if(istype(current_wearer))
		reserve_slots(current_wearer, current_wearer.get_slot_by_item(item))

/datum/component/occupies_slots/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ITEM_EQUIP_CHECK, COMSIG_ITEM_POST_EQUIPPED, COMSIG_ITEM_DROPPED, COMSIG_ATOM_UPDATED_ICON))
	release_slots()

/datum/component/occupies_slots/Destroy(force)
	release_slots()
	return ..()

/// ignore_equipped must not allow another item to steal a required slot.
/datum/component/occupies_slots/proc/can_equip(mob/living/carbon/human/target, target_slot)
	if(!(target_slot & occupied_slots))
		return TRUE
	if(QDELETED(target) || QDELETED(parent))
		return FALSE
	for(var/slot in bitfield_to_list(occupied_slots))
		var/obj/item/occupant = target.get_item_by_slot(slot)
		if(occupant && occupant != parent)
			return FALSE
	return TRUE

/datum/component/occupies_slots/proc/on_equip_check(datum/source, mob/living/carbon/human/target, target_slot)
	SIGNAL_HANDLER
	if(!can_equip(target, target_slot))
		return COMPONENT_BLOCK_EQUIP

/datum/component/occupies_slots/proc/on_wearer_equipping(datum/source, obj/item/equipping, slot)
	SIGNAL_HANDLER
	if(equipping != parent && (slot & occupied_slots))
		return COMPONENT_BLOCK_EQUIP

/datum/component/occupies_slots/proc/on_equipped(datum/source, mob/user, slot)
	SIGNAL_HANDLER
	return reserve_slots(user, slot)

/datum/component/occupies_slots/proc/reserve_slots(mob/living/carbon/human/target, target_slot)
	release_slots()
	if(!istype(target) || !(target_slot & occupied_slots))
		return
	var/obj/item/item = parent
	if(QDELETED(item) || item.loc != target || target.get_slot_by_item(item) != target_slot)
		return
	if(!can_equip(target, target_slot))
		// Also protect raw equip calls and components attached to already worn clothing.
		INVOKE_ASYNC(target, TYPE_PROC_REF(/mob, dropItemToGround), item, TRUE, TRUE)
		return COMPONENT_EQUIPPED_FAILED
	wearer_ref = WEAKREF(target)
	primary_slot = target_slot
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_wearer_deleted))
	RegisterSignal(target, COMSIG_HUMAN_EQUIPPING_ITEM, PROC_REF(on_wearer_equipping))
	for(var/slot in bitfield_to_list(occupied_slots & ~primary_slot))
		LAZYSET(target.occupied_clothing_slots, "[slot]", item)
	refresh_hud()

/datum/component/occupies_slots/proc/on_dropped(datum/source, mob/user)
	SIGNAL_HANDLER
	release_slots()

/datum/component/occupies_slots/proc/on_wearer_deleted(datum/source)
	SIGNAL_HANDLER
	// A weakref cannot resolve its owner once QDELETING has started.
	release_slots(source)

/datum/component/occupies_slots/proc/on_icon_updated(datum/source)
	SIGNAL_HANDLER
	refresh_hud()

/datum/component/occupies_slots/proc/refresh_hud(mob/living/carbon/human/target)
	if(!target)
		target = wearer_ref?.resolve()
	if(QDELETED(target))
		return
	for(var/slot in bitfield_to_list(occupied_slots))
		target.hud_used?.update_inventory_slot(slot)

/datum/component/occupies_slots/proc/release_slots(mob/living/carbon/human/old_wearer)
	if(!old_wearer)
		old_wearer = wearer_ref?.resolve()
	if(old_wearer)
		UnregisterSignal(old_wearer, list(COMSIG_QDELETING, COMSIG_HUMAN_EQUIPPING_ITEM))
		for(var/slot in bitfield_to_list(occupied_slots & ~primary_slot))
			if(LAZYACCESS(old_wearer.occupied_clothing_slots, "[slot]") == parent)
				LAZYREMOVE(old_wearer.occupied_clothing_slots, "[slot]")
		refresh_hud(old_wearer)
	wearer_ref = null
	primary_slot = NONE
// AI EDIT END
