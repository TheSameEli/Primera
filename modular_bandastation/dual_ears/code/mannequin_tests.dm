// AI EDIT START - Mannequins use the same slot states as living wearers
/// Mannequins must render both baked ear states from the normal worn resource.
/datum/unit_test/dual_ears_mannequin/Run()
	var/obj/structure/mannequin/mannequin = allocate(/obj/structure/mannequin)
	var/obj/item/radio/headset/right = allocate(/obj/item/radio/headset, mannequin)
	var/obj/item/radio/headset/left = allocate(/obj/item/radio/headset, mannequin)
	mannequin.worn_items["[ITEM_SLOT_EAR_RIGHT]"] = right
	mannequin.worn_items["[ITEM_SLOT_EAR_LEFT]"] = left
	var/list/ear_overlays = list()
	for(var/mutable_appearance/overlay as anything in mannequin.update_overlays())
		if(overlay.layer == -EARS_LAYER)
			ear_overlays += overlay
	TEST_ASSERT_EQUAL(length(ear_overlays), 2, "The mannequin did not render both ear slots.")
	var/mutable_appearance/right_overlay = ear_overlays[1]
	var/mutable_appearance/left_overlay = ear_overlays[2]
	TEST_ASSERT_EQUAL(right_overlay.icon_state, "headset_right", "The mannequin changed the right-ear state.")
	TEST_ASSERT_EQUAL(left_overlay.icon_state, "headset_left", "The mannequin changed the left-ear state.")
// AI EDIT END
