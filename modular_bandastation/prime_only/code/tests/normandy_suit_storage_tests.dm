// AI EDIT START - Cover Normandy kit cleanup and invalidated dressing cycles
/datum/unit_test/normandy_suit_storage
	abstract_type = /datum/unit_test/normandy_suit_storage

/datum/unit_test/normandy_suit_storage/return_kit/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y

	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	if(!storage.is_kit_worn_by(wearer))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return
	if(wearer.pixel_y == original_pixel_y)
		TEST_FAIL("Dressing did not apply the character offset")
		return

	if(!storage.store_kit_from(wearer))
		TEST_FAIL("The kit could not be returned to its storage unit")
		return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Returning the kit did not restore the character offset ([wearer.pixel_y], expected [original_pixel_y])")
		return
	qdel(storage)
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Deleting the empty unit applied the character offset a second time")

/datum/unit_test/normandy_suit_storage/delete_storage/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y

	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	if(!storage.is_kit_worn_by(wearer))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return
	if(wearer.pixel_y == original_pixel_y)
		TEST_FAIL("Dressing did not apply the character offset")
		return

	qdel(storage)
	for(var/slot in list(ITEM_SLOT_HEAD, ITEM_SLOT_OCLOTHING, ITEM_SLOT_GLOVES, ITEM_SLOT_FEET, ITEM_SLOT_NECK))
		var/obj/item/worn_item = wearer.get_item_by_slot(slot)
		if(worn_item && !wearer.dropItemToGround(worn_item))
			TEST_FAIL("The kit could not be removed after deleting its storage unit")
			return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Deleting the unit and removing its kit left a permanent character offset ([wearer.pixel_y], expected [original_pixel_y])")

/datum/unit_test/normandy_suit_storage/delete_wearer/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/list/deleted_refs = dress_and_delete_wearer(storage)
	if(isnull(deleted_refs))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return

	// Stop waiting once collected, while staying well before the hard-delete queue.
	var/collection_deadline = world.time + 30 SECONDS
	for(var/deleted_part in deleted_refs)
		UNTIL(!locate(deleted_refs[deleted_part]) || world.time >= collection_deadline)
		if(locate(deleted_refs[deleted_part]))
			TEST_FAIL("The surviving storage unit kept its deleted [deleted_part] alive")

/datum/unit_test/normandy_suit_storage/delete_wearer/proc/dress_and_delete_wearer(obj/machinery/normandy_suit_storage/storage)
	// allocate() would itself retain the wearer until the test ends.
	var/mob/living/carbon/human/wearer = new /mob/living/carbon/human/consistent(run_loc_floor_bottom_left)
	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	var/was_dressed = storage.is_kit_worn_by(wearer)
	var/list/deleted_refs = list(
		"wearer" = text_ref(wearer),
		"armor" = text_ref(storage.stored_armor),
		"gloves" = text_ref(storage.stored_gloves),
		"boots" = text_ref(storage.stored_boots),
		"helmet" = text_ref(storage.stored_helmet),
		"cloak" = text_ref(storage.stored_cloak),
	)
	qdel(wearer)
	wearer = null
	return was_dressed ? deleted_refs : null

/datum/unit_test/normandy_suit_storage/delete_kit_piece/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	if(!storage.is_kit_stored())
		TEST_FAIL("The unit did not start with its complete kit stored")
		return

	var/boots_ref = text_ref(storage.stored_boots)
	qdel(storage.stored_boots)
	if(!isnull(storage.stored_boots))
		TEST_FAIL("The unit kept a reference to its deleted boots")
	if(locate(boots_ref) in storage.kit_items)
		TEST_FAIL("The unit kept its deleted boots in the kit list")
	if(storage.is_kit_stored())
		TEST_FAIL("The unit considered its four remaining pieces a complete stored kit")

	storage.close_machine(wearer)
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("The unit started closing with an incomplete kit")

/// Losing a kit piece during the real dressing action must not strip the wearer's own clothes.
/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing
	/// The storage-owned piece deleted when the wearer's dressing action begins.
	var/obj/item/clothing/shoes/combat/normandy/kit_piece_to_delete

/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing/Destroy()
	kit_piece_to_delete = null
	return ..()

/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent/slow)
	var/obj/item/clothing/gloves/combat/original_gloves = allocate(/obj/item/clothing/gloves/combat)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y
	if(!wearer.equip_to_slot_if_possible(original_gloves, ITEM_SLOT_GLOVES))
		TEST_FAIL("Could not equip the wearer's original gloves")
		return
	storage.close_machine(wearer)
	if(storage.state_open || wearer.loc != storage)
		TEST_FAIL("The complete unit could not close for dressing")
		return
	storage.cancel_dressing_start_timer()
	kit_piece_to_delete = storage.stored_boots
	RegisterSignal(wearer, COMSIG_DO_AFTER_BEGAN, PROC_REF(delete_pending_kit_piece))

	storage.begin_dressing()
	UnregisterSignal(wearer, COMSIG_DO_AFTER_BEGAN)
	kit_piece_to_delete = null
	if(!isnull(storage.stored_boots))
		TEST_FAIL("The kit piece was not deleted during the dressing action")
		return
	if(wearer.gloves != original_gloves)
		TEST_FAIL("An invalidated dressing cycle stripped the wearer's original gloves")
		return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("An invalidated dressing cycle changed the character offset")
		return
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("An invalidated dressing cycle did not release its occupant")

/// Invalidate the kit at the action boundary without replacing do_after or its validation.
/datum/unit_test/normandy_suit_storage/delete_kit_piece_during_dressing/proc/delete_pending_kit_piece(mob/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_DO_AFTER_BEGAN)
	// Wait one tick so the real dressing action has yielded before the kit changes.
	QDEL_IN(kit_piece_to_delete, world.tick_lag)
	kit_piece_to_delete = null

/// Destroyed armor must release its visual offset and still allow the remaining kit to be returned.
/datum/unit_test/normandy_suit_storage/return_incomplete_kit/Run()
	var/obj/machinery/normandy_suit_storage/storage = allocate(/obj/machinery/normandy_suit_storage)
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_base_pixel_y(3)
	var/original_pixel_y = wearer.pixel_y

	storage.close_machine(wearer)
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	if(!storage.is_kit_worn_by(wearer))
		TEST_FAIL("The dressing cycle did not equip its kit")
		return
	if(wearer.pixel_y == original_pixel_y)
		TEST_FAIL("Dressing did not apply the character offset")
		return

	var/obj/item/clothing/shoes/combat/normandy/boots = storage.stored_boots
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent)
	if(!wearer.transferItemToLoc(boots, get_turf(wearer), force = TRUE, animated = FALSE))
		TEST_FAIL("Could not remove the kit boots before giving them to another holder")
		return
	if(!holder.put_in_hands(boots))
		TEST_FAIL("The other holder could not pick up the kit boots")
		return

	qdel(storage.stored_armor)
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Deleting worn armor left its character offset active")
		return
	storage.close_machine(wearer)
	if(storage.state_open || wearer.loc != storage)
		TEST_FAIL("The wearer could not return the remaining pieces of an incomplete kit")
		return
	storage.cancel_dressing_start_timer()
	storage.begin_dressing()
	for(var/obj/item/remaining_item as anything in list(storage.stored_gloves, storage.stored_boots, storage.stored_cloak))
		if(remaining_item?.loc != storage)
			TEST_FAIL("Returning an incomplete kit did not store every surviving piece")
			return
	if(holder.is_holding(boots))
		TEST_FAIL("Returning the kit left its boots in the other holder's inventory")
		return
	if(wearer.pixel_y != original_pixel_y)
		TEST_FAIL("Returning the remaining kit changed the restored character offset")
		return
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("Returning an incomplete kit did not release its wearer")
		return
	storage.close_machine(wearer)
	if(!storage.state_open || wearer.loc == storage)
		TEST_FAIL("The unit started another dressing cycle with an incomplete kit")
// AI EDIT END
