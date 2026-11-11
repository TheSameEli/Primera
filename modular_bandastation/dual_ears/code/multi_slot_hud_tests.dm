// AI EDIT START - Implement and verify independent ear slots
/// Only the primary slot displays the real item; reserved slots use independent translucent appearances.
/datum/unit_test/multi_slot_hud/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/datum/hud/human/player_hud = allocate(/datum/hud/human, wearer)
	wearer.hud_used = player_hud
	var/datum/inventory_slot/right_slot = player_hud.inventory_slots[ITEM_SLOT_EAR_RIGHT]
	var/datum/inventory_slot/left_slot = player_hud.inventory_slots[ITEM_SLOT_EAR_LEFT]
	var/atom/movable/screen/inventory/right_box = right_slot.get_screen_slot(player_hud)
	var/atom/movable/screen/inventory/left_box = left_slot.get_screen_slot(player_hud)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_RIGHT), "Could not equip the HUD fixture.")
	TEST_ASSERT(headset in right_box.vis_contents, "The primary slot lost the real item.")
	TEST_ASSERT(!(headset in left_box.vis_contents), "The secondary slot displays the real item at full opacity.")
	TEST_ASSERT_EQUAL(length(left_box.overlays), 1, "The secondary slot has no unique ghost icon.")
	var/mutable_appearance/ghost = left_box.overlays[1]
	TEST_ASSERT(ghost.alpha > 0 && ghost.alpha < headset.alpha, "The secondary icon is not translucent.")
	TEST_ASSERT_EQUAL(headset.alpha, 255, "The ghost changed the actual item's alpha.")
	TEST_ASSERT_EQUAL(ghost.icon_state, headset.icon_state, "The secondary slot displays a different item.")

	headset.icon_state = "eng_headset"
	headset.color = COLOR_RED
	headset.update_appearance()
	ghost = left_box.overlays[1]
	TEST_ASSERT_EQUAL(ghost.icon_state, headset.icon_state, "The secondary icon did not update after an appearance change.")
	TEST_ASSERT_EQUAL(ghost.color, headset.color, "The secondary icon lost its item's color.")

	TEST_ASSERT(wearer.temporarilyRemoveItemFromInventory(headset), "Could not remove the HUD fixture.")
	TEST_ASSERT_EQUAL(length(left_box.overlays), 0, "Removing the item left a ghost in its reserved slot.")
	TEST_ASSERT_EQUAL(length(right_box.vis_contents), 0, "Removing the item left its primary HUD icon.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not make the left ear primary.")
	TEST_ASSERT(headset in left_box.vis_contents, "The new primary slot has no real item.")
	TEST_ASSERT(!(headset in right_box.vis_contents), "The former primary slot kept a real item instead of a ghost.")
	TEST_ASSERT_EQUAL(length(right_box.overlays), 1, "Reversing the primary slot did not move the ghost.")
	qdel(headset)
	TEST_ASSERT_EQUAL(length(right_box.overlays), 0, "Deleting the item left a ghost icon.")
	TEST_ASSERT_EQUAL(length(left_box.vis_contents), 0, "Deleting the item left its primary HUD icon.")

/// Both stripping entries resolve to one item, and only the reserved entry is translucent.
/datum/unit_test/multi_slot_stripping/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/dresser = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the stripping fixture.")
	var/datum/element/strippable/rules = SSdcs.GetElement(list(
		/datum/element/strippable,
		GLOB.strippable_human_items,
		TYPE_PROC_REF(/mob/living/carbon/human/, should_strip),
	), init_element = FALSE)
	TEST_ASSERT_NOTNULL(rules, "The human stripping rules were not initialized.")
	var/datum/strip_menu/menu = allocate(/datum/strip_menu, wearer, rules)
	var/list/data = menu.ui_data(dresser)
	var/list/items = data["items"]
	var/list/right = items[STRIPPABLE_ITEM_EAR_RIGHT]
	var/list/left = items[STRIPPABLE_ITEM_EAR_LEFT]
	TEST_ASSERT_NOTNULL(right, "The stripping menu has no right-ear entry.")
	TEST_ASSERT_NOTNULL(left, "The stripping menu has no left-ear entry.")
	TEST_ASSERT(right["secondary_slot"], "The stripping menu does not mark the reserved slot.")
	TEST_ASSERT(!left["secondary_slot"], "The stripping menu marks the actual primary slot as secondary.")
	TEST_ASSERT_EQUAL(right["icon"], left["icon"], "The two occupied slots display different items.")
	var/datum/strippable_item/mob_item_slot/secondary = GLOB.strippable_human_items[STRIPPABLE_ITEM_EAR_RIGHT]
	TEST_ASSERT_EQUAL(secondary.get_item(wearer), headset, "The secondary strip slot cannot resolve its item.")
	secondary.finish_unequip(wearer, dresser)
	TEST_ASSERT_NULL(wearer.get_item_by_slot(ITEM_SLOT_EAR_RIGHT), "Stripping the reserved slot did not release it.")
	TEST_ASSERT_NULL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), "Stripping the reserved slot left the primary item equipped.")
	TEST_ASSERT_EQUAL(headset.loc, wearer.drop_location(), "Stripping the reserved slot did not drop the real item at its wearer.")
// AI EDIT END
