// AI EDIT START - Implement and verify independent ear slots
/datum/unit_test/multi_slot_inventory/Run()
	for(var/primary_slot in list(ITEM_SLOT_EAR_RIGHT, ITEM_SLOT_EAR_LEFT))
		var/secondary_slot = primary_slot == ITEM_SLOT_EAR_RIGHT ? ITEM_SLOT_EAR_LEFT : ITEM_SLOT_EAR_RIGHT
		var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
		var/obj/item/radio/headset/blocker = allocate(/obj/item/radio/headset)
		var/baseline_protection = wearer.get_ear_protection()
		TEST_ASSERT(wearer.equip_to_slot_if_possible(blocker, secondary_slot), "Could not occupy slot [secondary_slot].")
		TEST_ASSERT(!wearer.can_equip(headset, primary_slot, disable_warning = TRUE, ignore_equipped = TRUE), "A protected headset ignored occupied slot [secondary_slot].")
		TEST_ASSERT(wearer.dropItemToGround(blocker), "Could not remove the blocker.")
		TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, primary_slot), "Could not equip a protected headset in slot [primary_slot].")
		TEST_ASSERT_EQUAL(wearer.get_item_by_slot(secondary_slot), headset, "The opposite ear was not reserved.")
		TEST_ASSERT_EQUAL(wearer.get_slot_by_item(headset), primary_slot, "The reservation replaced the primary slot.")
		TEST_ASSERT_EQUAL(length(wearer.get_items_by_slots(ITEM_SLOT_EARS)), 1, "Slot enumeration duplicated one physical item.")
		TEST_ASSERT_EQUAL(wearer.get_ear_protection(), baseline_protection + EAR_PROTECTION_NORMAL, "The headset should grant protection exactly once.")
		TEST_ASSERT(!wearer.can_equip(blocker, secondary_slot, disable_warning = TRUE, ignore_equipped = TRUE), "An ordinary headset could steal a reserved slot.")
		TEST_ASSERT(wearer.dropItemToGround(headset), "Could not remove the protected headset.")
		TEST_ASSERT_NULL(wearer.get_item_by_slot(primary_slot), "Removal retained the primary slot.")
		TEST_ASSERT_NULL(wearer.get_item_by_slot(secondary_slot), "Removal retained the reservation.")
		TEST_ASSERT_EQUAL(wearer.get_ear_protection(), baseline_protection, "Removal retained hearing protection.")
		TEST_ASSERT(wearer.equip_to_slot_if_possible(blocker, secondary_slot), "Removal left a blocking signal handler.")

/datum/unit_test/multi_slot_lifecycle/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the protected headset.")
	headset.forceMove(wearer.drop_location())
	TEST_ASSERT_NULL(wearer.get_item_by_slot(ITEM_SLOT_EAR_RIGHT), "forceMove retained the reservation.")
	TEST_ASSERT_NULL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), "forceMove retained the primary slot.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not re-equip the headset.")
	qdel(headset)
	TEST_ASSERT_NULL(wearer.get_item_by_slot(ITEM_SLOT_EAR_RIGHT), "Deleting the item retained its reservation.")
	TEST_ASSERT_NULL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), "Deleting the item retained its primary slot.")

/datum/unit_test/multi_slot_component_removal/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	var/obj/item/radio/headset/other = allocate(/obj/item/radio/headset)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the protected headset.")
	qdel(headset.GetComponent(/datum/component/occupies_slots))
	TEST_ASSERT_EQUAL(wearer.ear_left, headset, "Deleting the component removed the primary item.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(other, ITEM_SLOT_EAR_RIGHT), "Deleting the component did not release its reservation and signal handler.")

/datum/unit_test/multi_slot_dynamic_protection/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset)
	var/obj/item/radio/headset/blocker = allocate(/obj/item/radio/headset)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_RIGHT), "Could not equip the headset.")
// AI EDIT END
	// AI EDIT START - Attach inventory requirements explicitly alongside hearing protection
	headset.AddComponent(/datum/component/wearertargeting/earprotection)
	headset.AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
	TEST_ASSERT_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), headset, "Adding explicit slot requirements did not reserve the other ear.")
	// AI EDIT END
	// AI EDIT START - Implement and verify independent ear slots
	headset.AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
	TEST_ASSERT_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), headset, "Duplicate attachment cleared the reservation.")
	TEST_ASSERT(!wearer.equip_to_slot_if_possible(blocker, ITEM_SLOT_EAR_LEFT, disable_warning = TRUE), "The late reservation did not block the other ear.")

/datum/unit_test/multi_slot_conflicting_attachment/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right headset.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left headset.")
	// AI EDIT END
	// AI EDIT START - Attach inventory requirements explicitly alongside hearing protection
	right.AddComponent(/datum/component/wearertargeting/earprotection)
	right.AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
	TEST_ASSERT_NULL(wearer.ear_right, "Adding slot requirements retained an item that cannot fit.")
	TEST_ASSERT_EQUAL(wearer.ear_left, left, "Adding slot requirements displaced the other item.")
	// AI EDIT END
	// AI EDIT START - Implement and verify independent ear slots
	TEST_ASSERT_EQUAL(right.loc, wearer.drop_location(), "The incompatible item was not dropped.")
	wearer.equip_to_slot(right, ITEM_SLOT_EAR_RIGHT)
	TEST_ASSERT_NULL(wearer.ear_right, "Unchecked equipment bypassed the occupied required slot.")
	TEST_ASSERT_EQUAL(wearer.ear_left, left, "Unchecked equipment displaced the other item.")
	// AI EDIT END

// AI EDIT START - Exercise every independent protected-earpiece initialization at the equip boundary
/// Each consumer must attach its own slot requirements alongside hearing protection.
/datum/unit_test/multi_slot_protected_earpieces/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/blocker = allocate(/obj/item/radio/headset)
	var/list/protected_types = list(
		/obj/item/radio/headset/syndicate/alt,
		/obj/item/radio/headset/headset_sec/alt,
		/obj/item/radio/headset/heads/captain/alt,
		/obj/item/radio/headset/heads/hos/alt,
		/obj/item/radio/headset/headset_cent/alt,
		/obj/item/radio/headset/blueshield/alt,
		/obj/item/radio/headset/heads/nanotrasen_representative/alt,
		/obj/item/radio/headset/heads/magistrate/alt,
		/obj/item/radio/headset/psyker,
		/obj/item/radio/headset/psyker_seer,
		/obj/item/radio/headset/abductor,
		/obj/item/clothing/ears/earmuffs,
	)
	for(var/earpiece_type in protected_types)
		var/obj/item/earpiece = allocate(earpiece_type)
		TEST_ASSERT(wearer.equip_to_slot_if_possible(blocker, ITEM_SLOT_EAR_LEFT), "Could not occupy the other ear before testing [earpiece_type].")
		TEST_ASSERT(!wearer.equip_to_slot_if_possible(earpiece, ITEM_SLOT_EAR_RIGHT, disable_warning = TRUE), "[earpiece_type] fitted despite its occupied required ear.")
		TEST_ASSERT(wearer.dropItemToGround(blocker), "Could not clear the other ear before testing [earpiece_type].")
		TEST_ASSERT(wearer.equip_to_slot_if_possible(earpiece, ITEM_SLOT_EAR_RIGHT), "Could not equip [earpiece_type] with both ears free.")
		TEST_ASSERT_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), earpiece, "[earpiece_type] did not reserve the other ear.")
		TEST_ASSERT(wearer.dropItemToGround(earpiece), "Could not remove [earpiece_type] before testing the next consumer.")
// AI EDIT END

// AI EDIT START - Implement and verify independent ear slots
/datum/unit_test/multi_slot_generic/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/head/helmet/helmet = allocate(/obj/item/clothing/head/helmet)
	helmet.AddComponent(/datum/component/occupies_slots, ITEM_SLOT_HEAD | ITEM_SLOT_MASK)
	var/obj/item/clothing/mask/surgical/mask = allocate(/obj/item/clothing/mask/surgical)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK), "Could not equip the mask.")
	TEST_ASSERT(!wearer.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD, disable_warning = TRUE), "The component ignored an occupied non-ear slot.")
	TEST_ASSERT(wearer.dropItemToGround(mask), "Could not remove the mask.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD), "Could not equip the two-slot helmet.")
	TEST_ASSERT_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_MASK), helmet, "The component did not reserve a non-ear slot.")
	TEST_ASSERT(wearer.dropItemToGround(helmet), "Could not remove the helmet.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK), "Removing the helmet did not release the mask slot.")

/datum/unit_test/multi_slot_signal_checks/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/dresser = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	var/obj/item/radio/headset/blocker = allocate(/obj/item/radio/headset)
	var/datum/strippable_item/mob_item_slot/right_slot = GLOB.strippable_human_items[STRIPPABLE_ITEM_EAR_RIGHT]
	TEST_ASSERT(dresser.put_in_hands(headset), "The dresser could not hold the headset.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(blocker, ITEM_SLOT_EAR_LEFT), "Could not occupy the target's other ear.")
	TEST_ASSERT(!right_slot.try_equip(wearer, headset, dresser), "Dressing another mob ignored its occupied required slot.")
	TEST_ASSERT(wearer.dropItemToGround(blocker), "Could not clear the target's ear.")
	TEST_ASSERT(dresser.equip_to_slot_if_possible(blocker, ITEM_SLOT_EAR_LEFT), "Could not occupy the dresser's own ear.")
	TEST_ASSERT(right_slot.try_equip(wearer, headset, dresser), "The dresser's inventory blocked the target's free slots.")
	TEST_ASSERT(dresser.temporarilyRemoveItemFromInventory(headset), "Could not remove the headset from the dresser's hands.")
	right_slot.finish_equip(wearer, headset, dresser)
	TEST_ASSERT_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_EAR_LEFT), headset, "Dressing another mob did not reserve its secondary slot.")
	TEST_ASSERT_EQUAL(dresser.ear_left, blocker, "Dressing another mob displaced the dresser's own equipment.")

/// Neither a candidate nor a current wearer may skip revalidation across an equip delay.
/datum/unit_test/multi_slot_equip_delay
	var/blocker_equipped = FALSE
	var/obj/item/blocker_on_delay

/datum/unit_test/multi_slot_equip_delay/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent/slow)
	var/obj/item/radio/headset/double = allocate(/obj/item/radio/headset/headset_sec/alt)
	double.equip_delay_self = 1 SECONDS
	var/obj/item/radio/headset/blocker = allocate(/obj/item/radio/headset)
	blocker_on_delay = blocker
	RegisterSignal(wearer, COMSIG_DO_AFTER_BEGAN, PROC_REF(on_equip_delay))
	var/candidate_equipped = wearer.equip_to_slot_if_possible(double, ITEM_SLOT_EAR_RIGHT, disable_warning = TRUE)
	TEST_ASSERT(blocker_equipped, "The delayed candidate test never occupied the other ear.")
	TEST_ASSERT(!candidate_equipped, "A multi-slot candidate ignored a slot occupied during its equip delay.")
	TEST_ASSERT_EQUAL(wearer.ear_left, blocker, "Delayed equipment displaced the required-slot blocker.")
	TEST_ASSERT_NULL(wearer.ear_right, "A rejected delayed candidate was still equipped.")
	TEST_ASSERT(wearer.dropItemToGround(blocker), "Could not reset the occupied ear.")

	var/obj/item/radio/headset/single = allocate(/obj/item/radio/headset)
	single.equip_delay_self = 1 SECONDS
	var/obj/item/radio/headset/protected = allocate(/obj/item/radio/headset/headset_sec/alt)
	protected.equip_delay_self = 0
	blocker_equipped = FALSE
	blocker_on_delay = protected
	RegisterSignal(wearer, COMSIG_DO_AFTER_BEGAN, PROC_REF(on_equip_delay))
	candidate_equipped = wearer.equip_to_slot_if_possible(single, ITEM_SLOT_EAR_RIGHT, disable_warning = TRUE)
	TEST_ASSERT(blocker_equipped, "The delayed wearer test never installed the two-ear item.")
	TEST_ASSERT(!candidate_equipped, "An ordinary item stole a slot reserved during its equip delay.")
	TEST_ASSERT_EQUAL(wearer.get_item_by_slot(ITEM_SLOT_EAR_RIGHT), protected, "A delayed ordinary candidate overwrote a new secondary reservation.")
	TEST_ASSERT_NULL(wearer.ear_right, "The ordinary candidate was equipped behind a reserved slot.")

/datum/unit_test/multi_slot_equip_delay/proc/on_equip_delay(mob/living/carbon/human/wearer)
	SIGNAL_HANDLER
	UnregisterSignal(wearer, COMSIG_DO_AFTER_BEGAN)
	// Install the blocker after the first checks, without racing the timer subsystem.
	blocker_equipped = wearer.equip_to_slot_if_possible(blocker_on_delay, ITEM_SLOT_EAR_LEFT, disable_warning = TRUE, bypass_equip_delay_self = TRUE)
	blocker_on_delay = null

/datum/unit_test/multi_slot_owner_transfer/Run()
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	var/obj/item/radio/headset/blocker = allocate(/obj/item/radio/headset)
	TEST_ASSERT(first.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_RIGHT), "Could not equip the first owner.")
	TEST_ASSERT(first.temporarilyRemoveItemFromInventory(headset), "Could not remove the transferred headset.")
	TEST_ASSERT(second.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the second owner.")
	TEST_ASSERT(first.equip_to_slot_if_possible(blocker, ITEM_SLOT_EAR_LEFT), "A stale reservation or signal blocked the old owner.")
	TEST_ASSERT_EQUAL(second.get_item_by_slot(ITEM_SLOT_EAR_RIGHT), headset, "The reservation did not follow the new owner.")
	TEST_ASSERT(!second.can_equip(blocker, ITEM_SLOT_EAR_RIGHT, disable_warning = TRUE, ignore_equipped = TRUE), "The new owner's reserved slot was not protected.")

/datum/unit_test/multi_slot_wearer_deletion/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_sec/alt)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_RIGHT), "Could not equip the protected headset.")
	var/datum/component/occupies_slots/slots = headset.GetComponent(/datum/component/occupies_slots)
	// Keep the old list observable after the owner's weakref stops resolving.
	var/list/reservations = wearer.occupied_clothing_slots
	qdel(wearer)
	TEST_ASSERT_NULL(slots.wearer_ref, "Deleting the wearer retained its component weakref.")
	TEST_ASSERT_EQUAL(length(reservations), 0, "Deleting the wearer did not clear its reservations.")
// AI EDIT END
