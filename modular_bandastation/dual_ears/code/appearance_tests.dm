// AI EDIT START - Verify baked ear states through the worn renderer
/// A one-ear headset stays on the chosen side and disappears behind the far profile.
/datum/unit_test/dual_ear_sprites/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset)
	for(var/slot_id in list(ITEM_SLOT_EAR_RIGHT, ITEM_SLOT_EAR_LEFT))
		TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, slot_id), "Could not equip the headset for its profile check.")
		var/list/rendered = wearer.overlays_standing[EARS_LAYER]
		TEST_ASSERT_EQUAL(length(rendered), 1, "One headset should produce one worn overlay.")
		var/mutable_appearance/overlay = rendered[1]
		var/side = slot_id == ITEM_SLOT_EAR_RIGHT ? "right" : "left"
		TEST_ASSERT_EQUAL(overlay.icon_state, "headset_[side]", "The worn renderer did not select the baked state for the chosen ear.")
		var/icon/sprite = icon(overlay.icon)
		var/near_direction = slot_id == ITEM_SLOT_EAR_RIGHT ? EAST : WEST
		var/near_pixels = 0
		var/far_pixels = 0
		for(var/x in 1 to sprite.Width())
			for(var/y in 1 to sprite.Height())
				if(sprite.GetPixel(x, y, overlay.icon_state, near_direction))
					near_pixels++
				if(sprite.GetPixel(x, y, overlay.icon_state, REVERSE_DIR(near_direction)))
					far_pixels++
		TEST_ASSERT(near_pixels, "The chosen earpiece disappeared from its near profile.")
		TEST_ASSERT_EQUAL(far_pixels, 0, "The earpiece shows through the head from its far profile.")
		TEST_ASSERT(wearer.dropItemToGround(headset), "Could not move the headset to the other ear.")

/// Each ear renders independently, while covering headgear hides both.
/datum/unit_test/dual_ear_appearance/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(right, ITEM_SLOT_EAR_RIGHT), "Could not equip the right headset.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(left, ITEM_SLOT_EAR_LEFT), "Could not equip the left headset.")
	var/list/rendered = wearer.overlays_standing[EARS_LAYER]
	TEST_ASSERT_EQUAL(length(rendered), 2, "Equipping both ears did not produce both clothing overlays.")
	var/mutable_appearance/right_overlay = rendered[1]
	var/mutable_appearance/left_overlay = rendered[2]
	TEST_ASSERT_EQUAL(right_overlay.icon_state, "headset_right", "The right ear selected the wrong state.")
	TEST_ASSERT_EQUAL(left_overlay.icon_state, "headset_left", "The left ear selected the wrong state.")

	ADD_TRAIT(right, TRAIT_NO_WORN_ICON, TRAIT_SOURCE_UNIT_TESTS)
	wearer.update_worn_ears()
	rendered = wearer.overlays_standing[EARS_LAYER]
	TEST_ASSERT_EQUAL(length(rendered), 1, "Hiding one ear's worn icon also hid the other ear.")
	left_overlay = rendered[1]
	TEST_ASSERT_EQUAL(left_overlay.icon_state, "headset_left", "Hiding the right ear changed the left ear's state.")
	REMOVE_TRAIT(right, TRAIT_NO_WORN_ICON, TRAIT_SOURCE_UNIT_TESTS)

	var/obj/item/clothing/head/helmet/toggleable/riot/helmet = allocate(/obj/item/clothing/head/helmet/toggleable/riot)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(helmet, ITEM_SLOT_HEAD), "Could not equip the ear-covering helmet.")
	TEST_ASSERT_NULL(wearer.overlays_standing[EARS_LAYER], "The helmet left an earpiece visible.")
	TEST_ASSERT(wearer.dropItemToGround(helmet), "Could not remove the ear-covering helmet.")
	TEST_ASSERT_EQUAL(length(wearer.overlays_standing[EARS_LAYER]), 2, "Removing the helmet did not reveal both earpieces.")

/// The same non-ear item selects a different worn state in its head and mask slots.
/datum/unit_test/worn_icon_state_by_slot/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/mask/surgical/garment = allocate(/obj/item/clothing/mask/surgical)
	garment.slot_flags |= ITEM_SLOT_HEAD
	garment.worn_icon = 'icons/mob/clothing/ears.dmi'
	garment.worn_icon_state = "eng_headset"
	garment.worn_icon_state_by_slot = alist(ITEM_SLOT_MASK = "headset", ITEM_SLOT_HEAD = "sec_headset")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(garment, ITEM_SLOT_MASK), "Could not equip the generic item as a mask.")
	var/mutable_appearance/overlay = wearer.overlays_standing[FACEMASK_LAYER]
	TEST_ASSERT_EQUAL(overlay.icon_state, "headset", "A non-ear item ignored its mask-slot state.")
	TEST_ASSERT(wearer.dropItemToGround(garment), "Could not remove the generic mask.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(garment, ITEM_SLOT_HEAD), "Could not equip the same item on the head.")
	overlay = wearer.overlays_standing[HEAD_LAYER]
	TEST_ASSERT_EQUAL(overlay.icon_state, "sec_headset", "Moving the item to the head did not select its other state.")
	garment.worn_icon_state_by_slot = null
	wearer.update_worn_head()
	overlay = wearer.overlays_standing[HEAD_LAYER]
	TEST_ASSERT_EQUAL(overlay.icon_state, "eng_headset", "An item without a slot override lost its ordinary worn state.")

/// Chameleon appearance changes copy the slot map and clear it for a bilateral disguise.
/datum/unit_test/slot_worn_chameleon/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/chameleon/headset = allocate(/obj/item/radio/headset/chameleon)
	var/datum/action/item_action/chameleon/change/action = locate() in headset.actions
	TEST_ASSERT_NOTNULL(action, "The chameleon headset has no appearance action.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not wear the chameleon headset.")
	action.update_look(/obj/item/radio/headset/headset_eng)
	TEST_ASSERT_EQUAL(headset.worn_icon_state, "eng_headset", "The chameleon action did not apply the engineering disguise.")
	TEST_ASSERT_EQUAL(headset.get_worn_icon_state(ITEM_SLOT_EAR_LEFT), "eng_headset_left", "The chameleon action did not copy the engineering slot map.")
	var/list/rendered = wearer.overlays_standing[EARS_LAYER]
	var/mutable_appearance/overlay = rendered[1]
	TEST_ASSERT_EQUAL(overlay.icon_state, "eng_headset_left", "The engineering disguise lost its left-ear state.")
	action.update_look(/obj/item/radio/headset/headset_sec/alt)
	rendered = wearer.overlays_standing[EARS_LAYER]
	overlay = rendered[1]
	TEST_ASSERT_EQUAL(overlay.icon_state, "sec_headset_alt", "A bilateral disguise retained the old one-ear override.")
	action.update_look(/obj/item/radio/headset/headset_cent/empty)
	rendered = wearer.overlays_standing[EARS_LAYER]
	overlay = rendered[1]
	TEST_ASSERT_EQUAL(overlay.icon_state, "cent_headset_left", "The disguise did not inherit its type's slot-state proc.")

/// A saved changeling appearance keeps its slot states after the source item changes.
/datum/unit_test/slot_worn_changeling/Run()
	var/mob/living/carbon/human/source = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/chameleon/headset = allocate(/obj/item/radio/headset/chameleon)
	var/datum/action/item_action/chameleon/change/action = locate() in headset.actions
	TEST_ASSERT_NOTNULL(action, "The source headset has no appearance action.")
	action.update_look(/obj/item/radio/headset/headset_eng)
	TEST_ASSERT(source.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the profile source.")
	var/datum/antagonist/changeling/changeling = allocate(/datum/antagonist/changeling)
	var/datum/changeling_profile/profile = changeling.create_profile(source)
	allocated += profile
	headset.worn_icon_state_by_slot[ITEM_SLOT_EAR_LEFT] = "sec_headset_left"
	changeling.transform(target, profile)
	var/list/rendered = target.overlays_standing[EARS_LAYER]
	TEST_ASSERT_EQUAL(length(rendered), 1, "The copied appearance did not recreate its earpiece.")
	var/mutable_appearance/overlay = rendered[1]
	TEST_ASSERT_EQUAL(overlay.icon_state, "eng_headset_left", "Changing the source item corrupted the saved slot state.")

/// Fitted assets must support both the mapped one-ear state and ordinary bilateral earwear.
/datum/unit_test/dual_ear_species_appearance/Run()
	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_species(/datum/species/vox)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(headset, ITEM_SLOT_EAR_LEFT), "Could not equip the fitted one-ear headset.")
	var/list/rendered = wearer.overlays_standing[EARS_LAYER]
	var/mutable_appearance/overlay = rendered[1]
	TEST_ASSERT_EQUAL(overlay.icon, 'icons/bandastation/mob/species/vox/clothing/ears.dmi', "The left earpiece ignored its fitted vox file.")
	TEST_ASSERT_EQUAL(overlay.icon_state, "headset_left", "The fitted earpiece ignored its slot-specific state.")
	TEST_ASSERT(wearer.dropItemToGround(headset), "Could not replace the fitted earpiece.")
	var/obj/item/clothing/ears/earmuffs/muffs = allocate(/obj/item/clothing/ears/earmuffs)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(muffs, ITEM_SLOT_EAR_LEFT), "Could not equip fitted earmuffs.")
	rendered = wearer.overlays_standing[EARS_LAYER]
	TEST_ASSERT_EQUAL(length(rendered), 1, "The fitted earmuffs did not produce one worn overlay.")
	overlay = rendered[1]
	TEST_ASSERT_EQUAL(overlay.icon, 'icons/bandastation/mob/species/vox/clothing/ears.dmi', "The earmuffs ignored their fitted vox sprite.")
	TEST_ASSERT_EQUAL(overlay.icon_state, muffs.worn_icon_state || muffs.icon_state, "Bilateral earmuffs were replaced with a one-ear state.")
// AI EDIT END
