/// Manual, broken and EMP disguises must only offer PDAs that can exist without a silicon owner.
/datum/unit_test/chameleon_tablet_disguises/Run()
	for(var/tablet_type in list(/obj/item/modular_computer/pda/chameleon, /obj/item/modular_computer/pda/chameleon/broken))
		var/obj/item/modular_computer/pda/tablet = allocate(tablet_type)
		var/datum/action/item_action/chameleon/change/tablet/action = locate() in tablet.actions
		TEST_ASSERT_NOTNULL(action, "The chameleon PDA has no disguise action.")
		TEST_ASSERT(length(action.chameleon_list), "The chameleon PDA has no available disguises.")
		for(var/disguise_name in action.chameleon_list)
			var/obj/item/disguise_type = action.chameleon_list[disguise_name]
			TEST_ASSERT(!ispath(disguise_type, /obj/item/modular_computer/pda/silicon), "The chameleon PDA offers an internal silicon PDA: [disguise_type].")
			action.update_look(disguise_type)
			TEST_ASSERT(!QDELETED(tablet), "Applying an available disguise deleted the chameleon PDA.")
			TEST_ASSERT_EQUAL(action.active_type, disguise_type, "The chameleon PDA did not apply an available disguise.")
			TEST_ASSERT_EQUAL(tablet.name, disguise_type::name, "The chameleon PDA did not copy the disguise's name.")
		tablet.emp_act(EMP_HEAVY)
		TEST_ASSERT(!COOLDOWN_FINISHED(action, emp_timer), "The chameleon PDA did not enter EMP randomisation.")
		TEST_ASSERT_NOTNULL(action.active_type, "The EMP left the chameleon PDA without a disguise.")
		TEST_ASSERT(!ispath(action.active_type, /obj/item/modular_computer/pda/silicon), "The EMP selected an internal silicon PDA.")

/// Outfit selection must respect the same exclusions as the manual and random disguise lists.
/datum/unit_test/chameleon_tablet_outfit/Run()
	var/obj/item/modular_computer/pda/chameleon/tablet = allocate(__IMPLIED_TYPE__)
	var/datum/action/item_action/chameleon/change/tablet/action = locate() in tablet.actions
	TEST_ASSERT_NOTNULL(action, "The chameleon PDA has no disguise action.")
	var/datum/outfit/outfit = allocate(__IMPLIED_TYPE__)
	action.update_look(/obj/item/modular_computer/pda)
	var/old_name = tablet.name
	var/old_icon_state = tablet.icon_state
	var/old_disguise = action.active_type
	var/forbidden_disguise = /obj/item/modular_computer/pda/silicon/cyborg/syndicate
	var/list/forbidden_outfit = list(forbidden_disguise)
	TEST_ASSERT(!action.apply_outfit(outfit, forbidden_outfit), "An outfit applied an internal silicon PDA disguise.")
	TEST_ASSERT_EQUAL(action.active_type, old_disguise, "A rejected outfit changed the PDA's active disguise.")
	TEST_ASSERT_EQUAL(tablet.name, old_name, "A rejected outfit changed the PDA's name.")
	TEST_ASSERT_EQUAL(tablet.icon_state, old_icon_state, "A rejected outfit changed the PDA's appearance.")
	TEST_ASSERT_EQUAL(length(forbidden_outfit), 1, "A rejected outfit consumed its forbidden disguise.")
	var/obj/item/valid_disguise = /obj/item/modular_computer/pda/crew/engineering
	var/list/mixed_outfit = list(forbidden_disguise, valid_disguise)
	TEST_ASSERT(action.apply_outfit(outfit, mixed_outfit), "An internal PDA prevented an outfit from applying its valid PDA disguise.")
	TEST_ASSERT_EQUAL(action.active_type, valid_disguise, "The mixed outfit selected the wrong PDA disguise.")
	TEST_ASSERT_EQUAL(tablet.name, valid_disguise::name, "The mixed outfit did not update the PDA's name.")
	TEST_ASSERT_EQUAL(length(mixed_outfit), 1, "The mixed outfit consumed the wrong number of disguises.")
	TEST_ASSERT_EQUAL(mixed_outfit[1], forbidden_disguise, "The mixed outfit consumed the forbidden disguise.")
