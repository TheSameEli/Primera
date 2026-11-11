GLOBAL_LIST_INIT(inventory_slot_datums, initialize_inventory_slots())

/proc/initialize_inventory_slots()
	var/list/slot_types = list()
	for (var/slot_type in valid_subtypesof(/datum/inventory_slot))
		slot_types[slot_type] = new slot_type()
	return slot_types

/// Inventory slot datum (singleton) which holds data about an inventory screen element
/datum/inventory_slot
	abstract_type = /datum/inventory_slot
	/// Name assigned to the screen element
	var/name = "error"
	/// Should the slot inherit HUD's ui_style?
	var/inherit_style = TRUE
	/// Slot ID of the element
	var/slot_id = NONE
	/// Icon state of the element with nothing in it/unassigned icon_full
	var/icon_state = "template"
	/// Icon state of the element when it has an item in it
	var/icon_full = "template"
	/// Location of the element
	var/screen_loc = null
	/// Screen group to which the element is assigned
	var/screen_group = HUD_GROUP_STATIC
	/// Typepath of the screen element
	var/screen_type = /atom/movable/screen/inventory

/datum/inventory_slot/proc/create_element(datum/hud/hud)
	var/atom/movable/screen/inventory/inv_box = hud.add_screen_object(screen_type, HUD_KEY_ITEM_SLOT(slot_id), screen_group, inherit_style ? hud.ui_style : null, screen_loc)
	inv_box.name = name
	inv_box.icon_state = icon_state
	inv_box.icon_full = icon_full
	inv_box.slot_id = slot_id
	return inv_box

/// Returns the item held in this slot by hud's mymob
/datum/inventory_slot/proc/get_slot_item(mob/owner)
	return owner.get_item_by_slot(slot_id)

/// Returns a screen object for this slot for a particular hud datum
/datum/inventory_slot/proc/get_screen_slot(datum/hud/hud)
	return hud.screen_objects[HUD_KEY_ITEM_SLOT(slot_id)]

/// Update inventory slot visuals
/datum/inventory_slot/proc/update_inventory_slot(datum/hud/hud, mob/owner)
	var/atom/movable/screen/inventory/slot = get_screen_slot(hud)
	if (!slot)
		return

	var/obj/item/slot_item = get_slot_item(owner)
	// AI EDIT START - Multi-slot clothing
	update_slot_icon_contents(slot, slot_item, slot_item && owner.get_slot_by_item(slot_item) != slot_id) // BANDASTATION EDIT - Multi-slot clothing
	// AI EDIT END

/// Updates the slot icon and its contents
// AI EDIT START - Multi-slot clothing
/datum/inventory_slot/proc/update_slot_icon_contents(atom/movable/screen/inventory/slot, obj/item/slot_item, secondary = FALSE) // BANDASTATION EDIT - Multi-slot clothing
// AI EDIT END
	// AI EDIT START - Keep the reserved icon separate from hover overlays.
	// BANDASTATION ADDITION START - Keep the reserved icon separate from hover overlays.
	if(slot.occupied_slot_overlay)
		slot.cut_overlay(slot.occupied_slot_overlay)
		slot.occupied_slot_overlay = null
	// BANDASTATION ADDITION END
	// AI EDIT END
	slot.update_appearance(UPDATE_ICON)
	// AI EDIT START - Secondary slots copy the sprite without changing the actual item's alpha.
	// BANDASTATION ADDITION START - Secondary slots copy the sprite without changing the actual item's alpha.
	if(secondary && slot_item)
		slot.vis_contents.Cut()
		var/mutable_appearance/ghost = new(slot_item.appearance)
		ghost.alpha = round(slot_item.alpha * 0.5)
		ghost.layer = FLOAT_LAYER
		ghost.plane = FLOAT_PLANE
		ghost.pixel_x = slot_item.base_pixel_x
		ghost.pixel_y = slot_item.base_pixel_y
		slot.occupied_slot_overlay = ghost
		slot.add_overlay(ghost)
		return
	// BANDASTATION ADDITION END
	// AI EDIT END
	if (!slot_item)
		slot.vis_contents.Cut()
		return

	if (slot_item in slot.vis_contents)
		return

	// Reset pixel offsets in order to make it fit the box
	slot_item.pixel_x = slot_item.base_pixel_x
	slot_item.pixel_y = slot_item.base_pixel_y
	slot.vis_contents += slot_item

// Not a real inventory slot, but this is used as a generic abstraction for hand slot UI behaviors
/datum/inventory_slot/hands
	slot_id = ITEM_SLOT_HANDS

/datum/inventory_slot/hands/create_element(datum/hud/hud)
	CRASH("[hud] attempted to call create_element on a behavior-only hands inventory slot datum!")

/datum/inventory_slot/hands/get_slot_item(mob/owner, hand_index = 1)
	return owner.get_item_for_held_index(hand_index)

/datum/inventory_slot/hands/get_screen_slot(datum/hud/hud, hand_index = 1)
	return hud.screen_objects[HUD_KEY_HAND_SLOT(hand_index)]

/datum/inventory_slot/hands/update_inventory_slot(datum/hud/hud, mob/owner, hand_index = null)
	// If no index was passed, update all hand slots
	if (isnull(hand_index))
		for (var/i in 1 to owner.get_num_hand_slots())
			update_inventory_slot(hud, owner, i)
		return

	var/atom/movable/screen/inventory/slot = get_screen_slot(hud, hand_index)
	if (!slot)
		return

	var/obj/item/slot_item = get_slot_item(owner, hand_index)
	update_slot_icon_contents(slot, slot_item)
