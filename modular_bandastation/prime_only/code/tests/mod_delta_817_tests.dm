// AI EDIT START - Cover Delta-817 hair visibility across helmet activation.
/// Delta-817 leaves hair visible with its helmet open and hides it once sealed.
/datum/unit_test/mod_delta_817_hair_visibility/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_hairstyle(/datum/sprite_accessory/hair/bedheadv4::name)
	var/obj/item/mod/control/pre_equipped/apocryphal/delta_817/mod = allocate(/obj/item/mod/control/pre_equipped/apocryphal/delta_817)
	if(!wearer.equip_to_slot_if_possible(mod, ITEM_SLOT_BACK, disable_warning = TRUE))
		TEST_FAIL("Could not equip the Delta-817 MODsuit")
		return
	mod.quick_deploy(wearer)
	var/obj/item/bodypart/head/head = wearer.get_bodypart(BODY_ZONE_HEAD)
	if(!length(head.get_hair_overlays()))
		TEST_FAIL("The open Delta-817 helmet hid the wearer's hair")
		return

	mod.quick_deploy(wearer)
	mod.quick_activation()
	var/datum/mod_part/helmet = mod.get_part_datum(wearer.head)
	if(!helmet.sealed)
		TEST_FAIL("The Delta-817 MODsuit did not seal its helmet")
		return
	if(length(head.get_hair_overlays()))
		TEST_FAIL("The sealed Delta-817 helmet left the wearer's hair visible")
		return

	mod.seal_part(wearer.head, is_sealed = FALSE)
	if(!length(head.get_hair_overlays()))
		TEST_FAIL("Unsealing the Delta-817 helmet did not restore the wearer's hair")
// AI EDIT END
