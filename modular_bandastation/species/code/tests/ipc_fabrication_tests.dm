/// IPC parts and maintenance supplies must be researched and dispensed through the actual robotic fabricator.
/datum/unit_test/ipc_fabrication/Run()
	var/datum/techweb_node/augmentation/node = SSresearch.techweb_nodes[/datum/techweb_node/augmentation]
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	fabricator.drop_direction = NONE
	var/list/design_paths = list(/datum/design/ipc_head, /datum/design/ipc_chassis, /datum/design/ipc_microbattery, /datum/design/ipc_power_cord, /datum/design/ipc_voicebox, /datum/design/ipc_nanopaste)
	for(var/design_path in design_paths)
		var/datum/design/design = SSresearch.techweb_designs[design_path]
		TEST_ASSERT_NOTNULL(design, "IPC replacement design [design_path] was not registered.")
		TEST_ASSERT(design_path in node.unlocked_designs, "IPC replacement [design_path] is not available with standard augmentation research.")
		TEST_ASSERT(design.build_type & MECHFAB, "IPC replacement [design_path] cannot be printed by robotics.")
		TEST_ASSERT(fabricator.dispense_built_part(design), "The fabricator failed to dispense [design_path].")
		var/atom/movable/part = locate(design.build_path) in get_turf(fabricator)
		TEST_ASSERT_NOTNULL(part, "The fabricator produced no [design.build_path].")
		allocated += part

	var/obj/item/bodypart/head/robot/ipc/head = locate() in get_turf(fabricator)
	var/obj/item/organ/tongue/robot/ipc/bundled_voicebox = locate() in head
	TEST_ASSERT_NOTNULL(bundled_voicebox, "The printed IPC head has no voicebox.")
	TEST_ASSERT_EQUAL(bundled_voicebox.bodypart_owner, head, "The printed voicebox was not physically installed in its head.")
	TEST_ASSERT_NULL(bundled_voicebox.owner, "A detached printed voicebox acquired a mob owner.")
	TEST_ASSERT_EQUAL(length(head.contents), 1, "The printed head contains duplicate speech hardware or unpriced organs.")
	var/datum/design/head_design = SSresearch.techweb_designs[/datum/design/ipc_head]
	for(var/datum/material/material as anything in head_design.materials)
		TEST_ASSERT_EQUAL(head.custom_materials[material] + bundled_voicebox.custom_materials[material], head_design.materials[material], "The printed head and voicebox did not account for their fabrication materials.")

	var/obj/item/organ/tongue/robot/ipc/voicebox = locate() in get_turf(fabricator)
	TEST_ASSERT_NOTNULL(voicebox, "Robotics did not dispense a standalone replacement voicebox.")
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left, /datum/species/ipc)
	TEST_ASSERT(voicebox.Insert(ipc, special = TRUE, movement_flags = DELETE_IF_REPLACED), "A fabricated voicebox could not replace an IPC's speech hardware.")
	TEST_ASSERT(HAS_TRAIT(ipc, TRAIT_SILICON_EMOTES_ALLOWED), "A replacement voicebox did not enable machine emotes.")
	TEST_ASSERT(ipc.emote("beep", intentional = TRUE), "A fabricated replacement voicebox could not beep.")

	var/obj/item/stack/nanopaste/paste = locate() in get_turf(fabricator)
	TEST_ASSERT_NOTNULL(paste, "Robotics did not dispense nanopaste.")
	TEST_ASSERT_EQUAL(paste.amount, 6, "Robotics printed a single nanopaste dose instead of a complete tube.")
	var/datum/design/paste_design = SSresearch.techweb_designs[/datum/design/ipc_nanopaste]
	var/list/tube_materials = paste.custom_materials
	for(var/datum/material/material as anything in paste_design.materials)
		TEST_ASSERT_EQUAL(tube_materials[material], paste_design.materials[material], "The printed nanopaste tube did not contain its fabrication materials.")

	var/mob/living/carbon/human/species/ipc_chassis/chassis = locate() in get_turf(fabricator)
	TEST_ASSERT(is_species(chassis, /datum/species/ipc), "The fabricated chassis is not an IPC.")
	TEST_ASSERT_EQUAL(chassis.stat, DEAD, "An unfinished chassis came alive without a core or battery.")
	TEST_ASSERT_EQUAL(length(chassis.organs), 0, "Printing a chassis provided free organs or a positronic personality.")
	TEST_ASSERT_EQUAL(length(chassis.get_bodyparts()), 1, "The chassis included free limbs or a head.")
	TEST_ASSERT_NOTNULL(chassis.get_bodypart(BODY_ZONE_CHEST), "The chassis was printed without its torso.")
	TEST_ASSERT_EQUAL(chassis.nutrition, 0, "Printing a chassis created battery charge.")
	TEST_ASSERT_NULL(chassis.mind, "Printing a chassis created a second personality.")

/// A blocked outlet must retain exactly one chassis and dispense that same frame after clearing.
/datum/unit_test/ipc_fabrication_blocked_outlet/Run()
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	var/turf/outlet = get_step(fabricator, EAST)
	fabricator.drop_direction = EAST
	var/original_density = outlet.density
	outlet.density = TRUE
	var/datum/design/design = SSresearch.techweb_designs[/datum/design/ipc_chassis]
	var/success = fabricator.dispense_built_part(design)
	outlet.density = original_density
	TEST_ASSERT(!success, "The fabricator dispensed a chassis through a blocked outlet.")
	var/mob/living/carbon/human/species/ipc_chassis/chassis = fabricator.stored_part
	TEST_ASSERT(istype(chassis), "The blocked outlet lost its stored IPC chassis.")
	allocated += chassis
	TEST_ASSERT_EQUAL(chassis.loc, fabricator, "The blocked chassis escaped the fabricator.")
	fabricator.process()
	TEST_ASSERT_EQUAL(chassis.loc, outlet, "The fabricator did not release its original chassis onto the outlet.")
	TEST_ASSERT_NULL(fabricator.stored_part, "The released chassis remained referenced as a stored part.")

/// A printed frame must be buildable through normal surgery and reuse an existing positronic personality.
/datum/unit_test/ipc_fabricated_chassis_assembly/Run()
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(/obj/machinery/mecha_part_fabricator)
	fabricator.drop_direction = NONE
	var/datum/design/chassis_design = SSresearch.techweb_designs[/datum/design/ipc_chassis]
	TEST_ASSERT(fabricator.dispense_built_part(chassis_design), "Could not print the assembly test chassis.")
	var/mob/living/carbon/human/species/ipc_chassis/chassis = locate() in get_turf(fabricator)
	TEST_ASSERT_NOTNULL(chassis, "The assembly test received no printed chassis.")
	allocated += chassis
	chassis.set_resting(TRUE)
	ADD_TRAIT(chassis, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	for(var/obj/item/bodypart/part as anything in chassis.get_bodyparts(include_stumps = TRUE))
		ADD_TRAIT(part, TRAIT_READY_TO_OPERATE, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/screwdriver/screwdriver = allocate(/obj/item/screwdriver)
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	var/list/limb_designs = list(/datum/design/ipc_head, /datum/design/borg_l_arm, /datum/design/borg_r_arm, /datum/design/borg_l_leg, /datum/design/borg_r_leg)
	for(var/design_path in limb_designs)
		var/datum/design/design = SSresearch.techweb_designs[design_path]
		var/obj/item/bodypart/part = design.create_result(surgeon.loc)
		allocated += part
		var/obj/item/bodypart/stump = chassis.get_bodypart(part.body_zone, include_stumps = TRUE)
		TEST_ASSERT(stump && IS_STUMP(stump), "The printed chassis has no surgical socket for [part.body_zone].")
		TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/mechanical_incision, chassis, surgeon, screwdriver, part.body_zone), "Could not unscrew the [part.body_zone] socket.")
		TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/mechanical_open, chassis, surgeon, IMPLEMENT_HAND, part.body_zone), "Could not open the [part.body_zone] socket.")
		TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/prosthetic_replacement, chassis, surgeon, part, part.body_zone), "Normal prosthetic surgery could not attach [part.body_zone].")
		TEST_ASSERT_EQUAL(chassis.get_bodypart(part.body_zone), part, "Surgery did not attach its supplied [part.body_zone].")
	TEST_ASSERT_EQUAL(length(chassis.get_bodyparts()), 6, "The printed chassis could not receive all six body parts.")
	var/obj/item/organ/tongue/robot/ipc/voicebox = chassis.get_organ_slot(ORGAN_SLOT_TONGUE)
	TEST_ASSERT_NOTNULL(voicebox, "Attaching the printed head did not install its bundled voicebox.")
	TEST_ASSERT(HAS_TRAIT(chassis, TRAIT_SILICON_EMOTES_ALLOWED), "Attaching the printed head did not enable machine emotes.")
	var/voicebox_count = 0
	for(var/obj/item/organ/tongue/tongue in chassis.organs)
		voicebox_count++
	TEST_ASSERT_EQUAL(voicebox_count, 1, "Attaching the printed head installed duplicate speech hardware.")

	TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/mechanical_incision, chassis, surgeon, screwdriver, BODY_ZONE_CHEST), "Could not unscrew the empty chassis.")
	TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/mechanical_open, chassis, surgeon, IMPLEMENT_HAND, BODY_ZONE_CHEST), "Could not open the empty chassis.")
	TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/prepare_electronics, chassis, surgeon, multitool, BODY_ZONE_CHEST), "Could not prepare the empty chassis for components.")
	TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/mechanic_unwrench, chassis, surgeon, wrench, BODY_ZONE_CHEST), "Could not open the chassis endoskeleton.")
	var/datum/design/battery_design = SSresearch.techweb_designs[/datum/design/ipc_microbattery]
	var/obj/item/organ/heart/ipc/battery = battery_design.create_result(surgeon.loc)
	allocated += battery
	TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/organ_manipulation/internal/mechanic, chassis, surgeon, battery, BODY_ZONE_CHEST, list(OPERATION_ACTION = "insert")), "Normal surgery could not install the printed microbattery.")
	TEST_ASSERT_EQUAL(battery.owner, chassis, "The microbattery was not installed in the printed chassis.")
	TEST_ASSERT_EQUAL(chassis.nutrition, 0, "Installing an empty microbattery created free charge.")

	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.set_species(/datum/species/ipc)
	donor.mind_initialize()
	var/datum/mind/personality = donor.mind
	var/obj/item/organ/brain/ipc/core = donor.get_organ_slot(ORGAN_SLOT_BRAIN)
	allocated += core
	core.Remove(donor)
	TEST_ASSERT(perform_assembly_step(/datum/surgery_operation/limb/organ_manipulation/internal/mechanic, chassis, surgeon, core, BODY_ZONE_CHEST, list(OPERATION_ACTION = "insert")), "Normal surgery could not transplant an existing positronic core into the printed chassis.")
	TEST_ASSERT_EQUAL(chassis.mind, personality, "Assembly replaced the existing positronic personality.")
	TEST_ASSERT_EQUAL(core.owner, chassis, "Assembly lost the transplanted core.")
	var/datum/species/ipc/species = chassis.dna.species
	TEST_ASSERT(!species.try_restart(chassis), "The assembled chassis rebooted without battery charge.")
	battery.adjust_charge(NUTRITION_LEVEL_WELL_FED)
	TEST_ASSERT(species.try_restart(chassis), "A repaired, charged chassis with an existing core could not boot.")
	TEST_ASSERT_NOTEQUAL(chassis.stat, DEAD, "The assembled chassis remained dead after rebooting.")
	TEST_ASSERT_EQUAL(personality.current, chassis, "The original personality did not retain control after booting.")
	TEST_ASSERT(chassis.emote("beep", intentional = TRUE), "The assembled positronic personality could not use its printed voicebox.")

/// A human brain transplanted into a printed chassis must retain the printed head's machine controls.
/datum/unit_test/ipc_fabricated_chassis_assembly/organic_brain/Run()
	..()
	var/mob/living/carbon/human/species/ipc_chassis/chassis = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(chassis, "The assembly fixture left no printed chassis for an organic brain.")
	var/obj/item/organ/brain/ipc/core = chassis.get_organ_slot(ORGAN_SLOT_BRAIN)
	core.Remove(chassis)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/datum/mind/personality = donor.mind
	var/obj/item/organ/brain/brain = donor.get_organ_slot(ORGAN_SLOT_BRAIN)
	allocated += brain
	brain.Remove(donor)
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	surgeon.put_in_active_hand(brain)
	surgeon.zone_selected = BODY_ZONE_HEAD
	brain.attack(chassis, surgeon)
	TEST_ASSERT_EQUAL(chassis.get_organ_slot(ORGAN_SLOT_BRAIN), brain, "Direct transplantation did not insert the organic brain into the printed chassis.")
	TEST_ASSERT_EQUAL(chassis.mind, personality, "The printed chassis lost its human donor's personality.")
	var/datum/species/ipc/species = chassis.dna.species
	TEST_ASSERT(istype(species) && species.try_restart(chassis), "The printed chassis could not boot with an organic brain.")
	TEST_ASSERT_NOTEQUAL(chassis.stat, DEAD, "The printed chassis remained dead after receiving its organic brain.")
	TEST_ASSERT(HAS_TRAIT(chassis, TRAIT_SILICON_EMOTES_ALLOWED), "The organic brain transplant disabled the printed voicebox.")
	TEST_ASSERT(/mob/living/carbon/human/proc/open_ipc_emote_panel in chassis.verbs, "The printed chassis lost its machine emotion controls.")
	var/datum/emote_panel/panel = allocate(/datum/emote_panel)
	var/list/panel_data = panel.ui_static_data(chassis)
	var/list/panel_keys = list()
	for(var/list/emote_data as anything in panel_data["emotes"])
		panel_keys += emote_data["key"]
	for(var/emote_key in list("beep", "ping", "buzz", "yes", "no", "scream"))
		TEST_ASSERT(emote_key in panel_keys, "The printed chassis hid a human donor's machine emotion: [emote_key].")
	TEST_ASSERT(chassis.emote("ping", intentional = TRUE), "A transplanted human brain could not use the printed voicebox.")

/// Resolve the player's real surgical target and use normal tool holding, checks, delay and completion.
/datum/unit_test/ipc_fabricated_chassis_assembly/proc/perform_assembly_step(operation_path, mob/living/carbon/human/patient, mob/living/carbon/human/surgeon, tool, zone, list/operation_args)
	var/datum/surgery_operation/operation = GLOB.operations.operations_by_typepath[operation_path]
	var/atom/movable/operating_on = operation.get_operation_target(patient, zone)
	if(!operating_on)
		return FALSE
	var/obj/item/held = surgeon.get_active_held_item()
	if(held && held != tool)
		surgeon.dropItemToGround(held)
	if(isitem(tool) && surgeon.get_active_held_item() != tool && !surgeon.put_in_active_hand(tool))
		return FALSE
	operation_args ||= list()
	operation_args[OPERATION_TARGET_ZONE] = zone
	return operation.try_perform(operating_on, surgeon, tool, operation_args) == ITEM_INTERACT_SUCCESS

/// Swapping batteries or reinstalling a battery-bearing torso must never refill the chassis's charge balance.
/datum/unit_test/ipc_battery_charge_replacement/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/ipc)
	patient.set_nutrition(37, forced = TRUE)
	var/obj/item/organ/heart/ipc/old_battery = patient.get_organ_slot(ORGAN_SLOT_HEART)
	allocated += old_battery
	var/datum/design/battery_design = SSresearch.techweb_designs[/datum/design/ipc_microbattery]
	var/obj/item/organ/heart/ipc/replacement = battery_design.create_result(patient.loc)
	allocated += replacement
	TEST_ASSERT(replacement.Insert(patient, special = TRUE), "Could not swap the printed microbattery into a low-charge IPC.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_HEART), replacement, "The battery swap did not install its supplied replacement.")
	TEST_ASSERT_NULL(old_battery.owner, "The replaced microbattery retained its former owner.")
	TEST_ASSERT_EQUAL(patient.nutrition, 37, "Replacing a low-charge IPC's microbattery created free energy.")

	for(var/real_charge in list(0, 37, NUTRITION_LEVEL_FULL - 1))
		patient.set_nutrition(real_charge, forced = TRUE)
		replacement.Remove(patient, special = TRUE)
		TEST_ASSERT_EQUAL(patient.nutrition, real_charge, "Removing a microbattery changed stored chassis charge.")
		TEST_ASSERT(replacement.Insert(patient, special = TRUE), "Could not reinstall the test microbattery.")
		TEST_ASSERT_EQUAL(patient.nutrition, real_charge, "Reinstalling a microbattery reset stored chassis charge.")

	patient.set_nutrition(37, forced = TRUE)
	var/obj/item/bodypart/chest/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	chest.drop_limb(special = TRUE)
	TEST_ASSERT_EQUAL(patient.nutrition, 37, "Detaching the battery-bearing torso changed stored chassis charge.")
	TEST_ASSERT(chest.try_attach_limb(patient, special = TRUE), "Could not reattach the battery-bearing torso.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_HEART), replacement, "Reattaching the torso lost its installed microbattery.")
	TEST_ASSERT_EQUAL(patient.nutrition, 37, "Reattaching a torso bypassed charge preservation through mob_insert.")
