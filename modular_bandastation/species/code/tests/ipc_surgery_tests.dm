/// A rejected core must not displace the patient's brain or leave the surgeon's hand.
/datum/unit_test/ipc_core_organic_rejection/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/brain/original_brain = patient.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/organ/brain/ipc/core = allocate(/obj/item/organ/brain/ipc)
	TEST_ASSERT(!core.Insert(patient, special = TRUE, movement_flags = DELETE_IF_REPLACED), "Special insertion bypassed an IPC core's recipient restrictions.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_BRAIN), original_brain, "A rejected core displaced the existing organic brain.")
	TEST_ASSERT_NULL(core.owner, "A rejected core acquired an organic owner.")

	var/obj/item/bodypart/chest/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	chest.add_surgical_state(SURGERY_BONE_SAWED)
	var/datum/surgery_operation/limb/organ_manipulation/internal/surgery = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	TEST_ASSERT(!surgery.is_insert_available(chest, core, BODY_ZONE_CHEST), "Organic surgery offered an incompatible positronic core.")
	original_brain.Remove(patient)
	allocated += original_brain
	surgeon.put_in_active_hand(core)
	surgeon.zone_selected = BODY_ZONE_CHEST
	core.attack(patient, surgeon)
	TEST_ASSERT_EQUAL(surgeon.get_active_held_item(), core, "A rejected chest core was taken out of the surgeon's hand.")
	TEST_ASSERT_NULL(patient.get_organ_slot(ORGAN_SLOT_BRAIN), "Direct insertion put an IPC core into an organic patient.")

/// Every body zone and the installed internal organs must be synthetic before transplanting into another species.
/datum/unit_test/ipc_core_augmented_recipient/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/android)
	var/obj/item/organ/brain/ipc/core = allocate(/obj/item/organ/brain/ipc)
	var/obj/item/organ/liver/organic_liver = allocate(/obj/item/organ/liver)
	organic_liver.Insert(patient)
	TEST_ASSERT(!core.Insert(patient), "Robotic limbs allowed a core to drive organic internal organs.")
	organic_liver.Remove(patient, special = TRUE)

	var/obj/item/bodypart/arm/left/robotic_arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	allocated += robotic_arm
	var/obj/item/bodypart/arm/left/organic_arm = allocate(/obj/item/bodypart/arm/left)
	TEST_ASSERT(organic_arm.replace_limb(patient), "Could not install the organic control arm.")
	TEST_ASSERT(!core.Insert(patient), "One organic limb was enough to bypass full augmentation.")
	TEST_ASSERT(robotic_arm.replace_limb(patient), "Could not restore the robotic control arm.")

	var/obj/item/bodypart/head/head = patient.get_bodypart(BODY_ZONE_HEAD)
	head.drop_limb(special = TRUE)
	TEST_ASSERT(!core.Insert(patient), "Removing a body zone bypassed the augmentation requirement.")
	TEST_ASSERT(head.try_attach_limb(patient, special = TRUE), "Could not restore the synthetic head.")
	TEST_ASSERT(core.Insert(patient, special = TRUE, movement_flags = DELETE_IF_REPLACED), "A fully synthetic non-IPC chassis rejected the core.")
	TEST_ASSERT_EQUAL(core.owner, patient, "The transplanted core did not acquire its compatible owner.")
	TEST_ASSERT_EQUAL(core.bodypart_owner, patient.get_bodypart(BODY_ZONE_CHEST), "A transplanted core was inserted into the head instead of the chest.")
	core.Remove(patient, special = TRUE)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	surgeon.put_in_active_hand(core)
	surgeon.zone_selected = BODY_ZONE_CHEST
	core.attack(patient, surgeon)
	TEST_ASSERT_EQUAL(core.owner, patient, "Direct chest insertion rejected a fully synthetic chassis.")
	TEST_ASSERT_EQUAL(core.bodypart_owner, patient.get_bodypart(BODY_ZONE_CHEST), "Direct insertion placed the core outside its chest compartment.")

/// A core hidden inside a detached chassis must face the same checks when the chassis is attached.
/datum/unit_test/ipc_core_detached_chassis_rejection/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/brain/original_brain = patient.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/bodypart/chest/old_chest = patient.get_bodypart(BODY_ZONE_CHEST)
	allocated += old_chest
	var/obj/item/bodypart/chest/robot/chassis = allocate(/obj/item/bodypart/chest/robot)
	var/obj/item/organ/brain/ipc/core = allocate(/obj/item/organ/brain/ipc)
	core.bodypart_insert(chassis)
	TEST_ASSERT(chassis.replace_limb(patient), "Could not attach the core-bearing chassis.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_BRAIN), original_brain, "A detached chassis bypassed transplant compatibility and replaced the organic brain.")
	TEST_ASSERT_NULL(core.owner, "A core inside a detached chassis acquired an incompatible owner.")
	TEST_ASSERT_NULL(core.bodypart_owner, "The rejected core remained trapped in the attached chassis.")
	TEST_ASSERT_EQUAL(core.loc, patient.drop_location(), "A rejected core was not returned to the floor.")

/// Reusing the organ policy must preserve the AI-uplink's original allowance for organic limbs.
/datum/unit_test/ipc_core_ai_shell_policy/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/android)
	var/obj/item/organ/brain/cybernetic/ai/uplink = allocate(/obj/item/organ/brain/cybernetic/ai)
	TEST_ASSERT(uplink.Insert(patient, special = TRUE, movement_flags = DELETE_IF_REPLACED), "Could not install an AI-uplink control brain.")
	var/obj/item/bodypart/arm/left/old_arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	allocated += old_arm
	var/obj/item/bodypart/arm/left/organic_arm = allocate(/obj/item/bodypart/arm/left)
	TEST_ASSERT(organic_arm.replace_limb(patient), "Could not install the AI-shell's organic control limb.")
	TEST_ASSERT(uplink.is_sufficiently_augmented(), "IPC core restrictions also restricted the AI-uplink's limb policy.")
	var/obj/item/organ/liver/organic_liver = allocate(/obj/item/organ/liver)
	organic_liver.Insert(patient)
	TEST_ASSERT(!uplink.is_sufficiently_augmented(), "An AI shell stopped rejecting organic internal organs.")

/// Ordinary and mechanical pain callbacks must not make synthetic maintenance painful; humans retain surgical mood effects.
/datum/unit_test/ipc_surgery_pain
	var/scream_attempts = 0

/datum/unit_test/ipc_surgery_pain/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/ipc)
	var/datum/surgery_operation/limb/incise_skin/surgery = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	RegisterSignal(patient, COMSIG_MOB_PRE_EMOTED, PROC_REF(on_emote))
	// The old organic path screamed probabilistically; synthetic patients must never reach that path.
	for(var/attempt in 1 to 100)
		UNLINT(surgery.display_pain(patient, "Organic pain control", FALSE))
	UNLINT(surgery.display_pain(patient, "Mechanical sensation control", TRUE))
	UNLINT(surgery.update_surgery_mood(patient, SURGERY_STATE_STARTED))
	UnregisterSignal(patient, COMSIG_MOB_PRE_EMOTED)
	TEST_ASSERT_EQUAL(scream_attempts, 0, "IPC maintenance attempted a human pain scream.")
	TEST_ASSERT_NULL(patient.mob_mood?.mood_events[SURGERY_MOOD_CATEGORY], "IPC maintenance created organic surgical pain trauma.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_ANALGESIA), "Synthetic pain suppression granted pharmaceutical anesthesia.")

	patient.set_species(/datum/species/human)
	UNLINT(surgery.update_surgery_mood(patient, SURGERY_STATE_STARTED))
	TEST_ASSERT_NOTNULL(patient.mob_mood?.mood_events[SURGERY_MOOD_CATEGORY], "Synthetic pain suppression leaked after a transformation into an organic patient.")

/datum/unit_test/ipc_surgery_pain/proc/on_emote(datum/source, emote_key)
	SIGNAL_HANDLER
	if(emote_key == "scream")
		scream_attempts++
	return COMPONENT_CANT_EMOTE

/// Implant extraction requires an open chest, regardless of whether its skin is organic or robotic.
/datum/unit_test/ipc_implant_removal_availability/Run()
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/hemostat/tool = allocate(/obj/item/hemostat)
	var/datum/surgery_operation/basic/implant_removal/surgery = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	for(var/species_type in list(/datum/species/human, /datum/species/android, /datum/species/ipc))
		var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
		patient.set_species(species_type)
		patient.set_resting(TRUE)
		ADD_TRAIT(patient, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
		var/obj/item/bodypart/chest/chest = patient.get_bodypart(BODY_ZONE_CHEST)
		ADD_TRAIT(chest, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
		TEST_ASSERT(!surgery.check_availability(patient, patient, surgeon, tool, BODY_ZONE_CHEST), "[species_type] offered implant removal through a closed chest.")
		chest.add_surgical_state(SURGERY_SKIN_CUT)
		TEST_ASSERT(!surgery.check_availability(patient, patient, surgeon, tool, BODY_ZONE_CHEST), "[species_type] offered implant removal before opening the chest.")
		chest.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_VESSELS_CLAMPED)
		chest.remove_surgical_state(SURGERY_SKIN_CUT)
		TEST_ASSERT(surgery.check_availability(patient, patient, surgeon, tool, BODY_ZONE_CHEST), "[species_type] could not remove implants through an open chest.")
		TEST_ASSERT(!surgery.check_availability(patient, patient, surgeon, tool, BODY_ZONE_HEAD), "[species_type] offered chest implant removal from the head.")
		chest.remove_surgical_state(SURGERY_VESSELS_CLAMPED)
		chest.add_surgical_state(SURGERY_VESSELS_UNCLAMPED)
		TEST_ASSERT(!surgery.check_availability(patient, patient, surgeon, tool, BODY_ZONE_CHEST), "[species_type] ignored unclamped vessels during implant extraction.")

/// Use the ordinary removal operation and its implant hooks, including storage contents and damage.
/datum/unit_test/ipc_implant_removal/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/ipc)
	patient.set_resting(TRUE)
	ADD_TRAIT(patient, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/bodypart/chest/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	ADD_TRAIT(chest, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	var/datum/surgery_operation/limb/mechanical_incision/incision = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	var/datum/surgery_operation/limb/mechanical_open/open_hatch = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	var/datum/surgery_operation/basic/implant_removal/surgery = GLOB.operations.operations_by_typepath[__IMPLIED_TYPE__]
	var/list/operation_args = list(OPERATION_TARGET_ZONE = BODY_ZONE_CHEST)
	surgeon.put_in_active_hand(screwdriver)
	TEST_ASSERT_EQUAL(incision.try_perform(chest, surgeon, screwdriver, operation_args), ITEM_INTERACT_SUCCESS, "Could not unscrew the IPC chest.")
	surgeon.dropItemToGround(screwdriver)
	surgeon.put_in_active_hand(crowbar)
	TEST_ASSERT_EQUAL(open_hatch.try_perform(chest, surgeon, crowbar, operation_args), ITEM_INTERACT_SUCCESS, "Could not open the IPC chest.")
	for(var/implant_type in list(/obj/item/implant/mindshield, /obj/item/implant/storage, /obj/item/implant/tracking))
		var/obj/item/implant/implant = allocate(implant_type)
		TEST_ASSERT(implant.implant(patient, surgeon, silent = TRUE), "Could not install [implant_type] in the IPC.")
		var/obj/item/implantcase/case = allocate(/obj/item/implantcase, patient.loc)
		surgeon.put_in_hands(case)
		var/obj/item/pen/stored_item
		if(istype(implant, /obj/item/implant/storage))
			stored_item = allocate(/obj/item/pen, implant)
		if(istype(implant, /obj/item/implant/mindshield))
			TEST_ASSERT(HAS_TRAIT(patient, TRAIT_MINDSHIELD), "The implanted mindshield was not functional.")
		var/previous_damage = chest.brute_dam
		TEST_ASSERT_EQUAL(surgery.try_perform(patient, surgeon, crowbar, operation_args), ITEM_INTERACT_SUCCESS, "Could not extract [implant_type] from the IPC.")
		TEST_ASSERT_EQUAL(case.imp, implant, "The empty case did not receive [implant_type].")
		TEST_ASSERT_EQUAL(implant.loc, case, "The extracted [implant_type] was left outside its case.")
		TEST_ASSERT_NULL(implant.imp_in, "The extracted [implant_type] still has an owner.")
		TEST_ASSERT(!(implant in patient.implants), "The extracted [implant_type] remains in the patient's implant list.")
		TEST_ASSERT(!(implant in GLOB.tracked_implants), "The extracted [implant_type] remains globally tracked.")
		TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_MINDSHIELD), "The removed mindshield still protects the IPC.")
		for(var/datum/action/implant_action as anything in implant.actions)
			TEST_ASSERT(!(implant_action in patient.actions), "The extracted [implant_type] left its action on the patient.")
		if(stored_item)
			TEST_ASSERT_EQUAL(stored_item.loc, patient.drop_location(), "Extracting the storage implant lost its contents.")
			TEST_ASSERT_EQUAL(chest.brute_dam, previous_damage + 20, "Extracting the storage implant bypassed its normal damage.")
		surgeon.dropItemToGround(case)
	var/obj/item/implant/tracking/unsaved_implant = allocate(/obj/item/implant/tracking)
	TEST_ASSERT(unsaved_implant.implant(patient, surgeon, silent = TRUE), "Could not install the no-case control implant.")
	TEST_ASSERT_EQUAL(surgery.try_perform(patient, surgeon, crowbar, operation_args), ITEM_INTERACT_SUCCESS, "Could not remove an implant without an empty case.")
	TEST_ASSERT_NULL(unsaved_implant.imp_in, "Removal without a case left the implant installed.")
	TEST_ASSERT_NULL(unsaved_implant.loc, "An implant without an empty case was unexpectedly preserved in an item.")
