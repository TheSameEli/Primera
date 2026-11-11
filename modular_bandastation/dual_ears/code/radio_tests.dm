// AI EDIT START - Implement and verify independent ear slots
/// Each message uses one headset, including channels available only in the left ear.
/datum/unit_test/dual_ears_radio
	var/list/transmitters = list()

/datum/unit_test/dual_ears_radio/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset/headset_med)
	TEST_ASSERT(human.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right headset.")
	TEST_ASSERT(human.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left headset.")
	RegisterSignal(right, COMSIG_RADIO_NEW_MESSAGE, PROC_REF(on_radio_message))
	RegisterSignal(left, COMSIG_RADIO_NEW_MESSAGE, PROC_REF(on_radio_message))

	human.radio("Common test", list(MODE_HEADSET = TRUE), list(), /datum/language/common)
	human.radio("Medical test", list(RADIO_EXTENSION = RADIO_CHANNEL_MEDICAL), list(), /datum/language/common)
	TEST_ASSERT_EQUAL(length(transmitters), 2, "Two messages did not produce exactly two transmissions.")
	TEST_ASSERT_EQUAL(transmitters[1], REF(right), "Common speech did not prefer the right headset.")
	TEST_ASSERT_EQUAL(transmitters[2], REF(left), "Medical speech did not use the left headset.")

/datum/unit_test/dual_ears_radio/proc/on_radio_message(datum/source)
	SIGNAL_HANDLER
	transmitters += REF(source)

/// An unavailable right transmitter must not block a usable headset in the left ear.
/datum/unit_test/dual_ears_radio_fallback/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset/headset_med)
	TEST_ASSERT(human.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right headset.")
	TEST_ASSERT(human.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left headset.")
	TEST_ASSERT_EQUAL(human.get_headset_for_channel(MODE_DEPARTMENT), left, "Department speech ignored the left headset's channel.")
	right.set_broadcasting(FALSE)
	TEST_ASSERT_EQUAL(human.get_headset_for_channel(), left, "A muted right microphone blocked the left headset.")
	right.set_broadcasting(TRUE)
	right.wires.cut(WIRE_TX)
	TEST_ASSERT_EQUAL(human.get_headset_for_channel(), left, "A cut right transmitter blocked the left headset.")
	right.wires.cut(WIRE_TX)
	right.set_on(FALSE)
	TEST_ASSERT_EQUAL(human.get_headset_for_channel(), left, "A powered-off right headset blocked the left headset.")
	left.channels[RADIO_CHANNEL_MEDICAL] = FALSE
	TEST_ASSERT_NULL(human.get_headset_for_channel(RADIO_CHANNEL_MEDICAL), "A disabled channel was selected for transmission.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(right), "Could not remove the right headset.")
	TEST_ASSERT_EQUAL(human.get_headset_for_channel(), left, "A headset worn only on the left was ignored.")

/// Removing one translator preserves the language supplied by the other headset.
/datum/unit_test/dual_ears_languages/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset/binary)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset/binary)
	TEST_ASSERT(human.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right translator.")
	TEST_ASSERT(human.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left translator.")
	TEST_ASSERT(human.has_language(/datum/language/machine, UNDERSTOOD_LANGUAGE), "Worn translators did not grant their language.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(right), "Could not remove the right translator.")
	TEST_ASSERT(human.has_language(/datum/language/machine, UNDERSTOOD_LANGUAGE), "Removing one translator cleared the other's language.")
	TEST_ASSERT(human.binarycheck(), "A binary translator worn only in the left ear was ignored.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(left), "Could not remove the left translator.")
	TEST_ASSERT(!human.has_language(/datum/language/machine, UNDERSTOOD_LANGUAGE), "Removing the last translator kept its language.")
	TEST_ASSERT(!human.binarycheck(), "Removing the last translator kept binary network access.")

/// Partial translators retain the strongest remaining source when one headset is removed.
/datum/unit_test/dual_ears_partial_languages/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset/headset_med)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset/headset_eng)
	right.keyslot.language_data = list(/datum/language/moffic = 25)
	left.keyslot.language_data = list(/datum/language/moffic = 60)
	TEST_ASSERT(human.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right partial translator.")
	TEST_ASSERT(human.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left partial translator.")
	var/datum/language_holder/holder = human.get_language_holder()
	TEST_ASSERT_EQUAL(holder.has_partial_language(/datum/language/moffic), 60, "The strongest translation was not selected.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(left), "Could not remove the stronger translator.")
	TEST_ASSERT_EQUAL(holder.has_partial_language(/datum/language/moffic), 25, "Removing the stronger translator lost the remaining source.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(right), "Could not remove the last translator.")
	TEST_ASSERT(!holder.has_partial_language(/datum/language/moffic), "Removing the last translator retained its partial language.")

/// Removing a key updates translations while its headset remains in the left ear.
/datum/unit_test/dual_ears_languages_rekey/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/binary)
	TEST_ASSERT(human.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the left translator.")
	TEST_ASSERT(human.has_language(/datum/language/machine, UNDERSTOOD_LANGUAGE), "The left translator did not grant its language.")
	headset.remove_keys(human)
	TEST_ASSERT(!human.has_language(/datum/language/machine, UNDERSTOOD_LANGUAGE), "Removing the left headset's key kept its translation.")

/// Each mining headset owns its speech boost independently.
/datum/unit_test/dual_ears_mining_traits/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset/headset_cargo/mining)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset/headset_cargo/mining)
	TEST_ASSERT(human.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right mining headset.")
	TEST_ASSERT(human.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left mining headset.")
	TEST_ASSERT(HAS_TRAIT(human, TRAIT_SPEECH_BOOSTER), "Worn mining headsets did not grant speech boost.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(right), "Could not remove the right mining headset.")
	TEST_ASSERT(HAS_TRAIT(human, TRAIT_SPEECH_BOOSTER), "Removing one mining headset cleared the other's speech boost.")
	TEST_ASSERT(human.temporarilyRemoveItemFromInventory(left), "Could not remove the left mining headset.")
	TEST_ASSERT(!HAS_TRAIT(human, TRAIT_SPEECH_BOOSTER), "Removing the last mining headset kept its speech boost.")
// AI EDIT END
