/datum/unit_test/sidearm_delivery_cases/Run()
	var/obj/item/clothing/accessory/holster/holster = allocate(/obj/item/clothing/accessory/holster)
	var/list/beacon_types = list(
		/obj/item/choice_beacon/weapon/security_pistol = 2,
		/obj/item/choice_beacon/weapon/hos = 4,
		/obj/item/choice_beacon/weapon/blueshield = 4,
	)
	for(var/beacon_type in beacon_types)
		var/obj/item/choice_beacon/beacon = allocate(beacon_type)
		var/list/options = beacon.generate_display_names()
		TEST_ASSERT_EQUAL(length(options), beacon_types[beacon_type], "Incorrect selection for [beacon_type]")
		for(var/option in options)
			var/option_type = options[option]
			if(!ispath(option_type, /obj/item/storage/toolbox/guncase))
				continue
			var/obj/item/storage/toolbox/guncase/guncase = allocate(option_type)
			var/obj/item/gun/gun = locate() in guncase
			TEST_ASSERT_NOTNULL(gun, "[option_type] did not contain a gun")
			TEST_ASSERT(icon_exists(gun.icon, gun.icon_state), "[gun.type] has an invalid icon")
			TEST_ASSERT(holster.atom_storage.can_insert(gun, messages = FALSE), "[gun.type] does not fit the supplied holster")
			var/list/items = guncase.contents.Copy()
			for(var/obj/item/item as anything in items)
				item.forceMove(run_loc_floor_bottom_left)
			for(var/obj/item/item as anything in items)
				TEST_ASSERT(guncase.atom_storage.attempt_insert(item, messages = FALSE), "[item.type] cannot be put back in [option_type]")
			if(!guncase.extra_to_spawn)
				continue
			var/expected_items = istype(guncase, /obj/item/storage/toolbox/guncase/ntcase/pistol/gp9) ? 3 : 4
			TEST_ASSERT_EQUAL(length(items), expected_items, "[option_type] has an incorrect number of spare magazines")
			var/obj/item/gun/ballistic/ballistic = gun
			for(var/obj/item/ammo_box/magazine/magazine in items)
				TEST_ASSERT(istype(magazine, ballistic.accepted_magazine_type), "[magazine.type] does not fit [gun.type]")
		TEST_ASSERT_EQUAL(length(beacon.generate_display_names()), beacon_types[beacon_type], "Another beacon changed this selection")

/datum/unit_test/sidearm_loadouts/Run()
	var/mob/living/carbon/human/blueshield = allocate(/mob/living/carbon/human/consistent)
	blueshield.equipOutfit(/datum/outfit/job/blueshield)
	TEST_ASSERT(locate(/obj/item/choice_beacon/weapon/blueshield) in blueshield.back, "Blueshield did not spawn with a weapon beacon")
	TEST_ASSERT(locate(/obj/item/storage/box/deathimp) in blueshield.back, "Blueshield lost the death implant box")
	var/obj/structure/closet/secure_closet/hos/hos_locker = allocate(/obj/structure/closet/secure_closet/hos)
	TEST_ASSERT(locate(/obj/item/choice_beacon/weapon/hos) in hos_locker, "HoS locker has no weapon beacon")
	hos_locker.PopulateContents()
	TEST_ASSERT(locate(/obj/item/clothing/accessory/holster) in hos_locker, "HoS locker has no holster")
	var/obj/structure/closet/secure_closet/blueshield/blueshield_locker = allocate(/obj/structure/closet/secure_closet/blueshield)
	blueshield_locker.PopulateContents()
	TEST_ASSERT(locate(/obj/item/storage/belt/medical/paramedic) in blueshield_locker, "Blueshield locker has no paramedic belt")
	TEST_ASSERT(locate(/obj/item/clothing/accessory/holster) in blueshield_locker, "Blueshield locker has no holster")

/datum/unit_test/hos_sidearm_theft/Run()
	var/list/station_levels = SSmapping.levels_by_trait(ZTRAIT_STATION)
	var/turf/station_turf = locate(1, 1, station_levels[1])
	var/obj/item/choice_beacon/weapon/hos/beacon = allocate(/obj/item/choice_beacon/weapon/hos, station_turf)
	var/mob/living/carbon/human/thief = allocate(/mob/living/carbon/human/consistent)
	thief.mind_initialize()
	var/datum/objective_item/steal/hoslaser/target_info = allocate(/datum/objective_item/steal/hoslaser)
	var/datum/spy_bounty/objective_item/sidearm_test/spy_bounty = allocate(/datum/spy_bounty/objective_item/sidearm_test)
	spy_bounty.desired_item = target_info
	var/datum/objective/steal/objective = allocate(/datum/objective/steal)
	objective.owner = thief.mind
	objective.set_target(target_info)
	TEST_ASSERT(!objective.check_completion(), "An empty-handed thief completed the sidearm objective")
	qdel(beacon)
	var/list/tracked_items = GLOB.steal_item_handler.objectives_by_path[target_info.targetitem]
	var/list/target_types = target_info.altitems + target_info.targetitem
	for(var/target_type in target_types)
		var/obj/item/target = allocate(target_type, station_turf)
		TEST_ASSERT(target in tracked_items, "[target_type] was not registered for theft")
		target.forceMove(thief)
		TEST_ASSERT(objective.check_completion(), "[target_type] did not satisfy the sidearm objective")
		TEST_ASSERT(spy_bounty.is_stealable(target), "[target_type] did not satisfy the spy bounty")
		ADD_TRAIT(target, TRAIT_ITEM_OBJECTIVE_BLOCKED, "unit_test")
		TEST_ASSERT(!spy_bounty.is_stealable(target), "The spy bounty accepted a blocked [target_type]")
		REMOVE_TRAIT(target, TRAIT_ITEM_OBJECTIVE_BLOCKED, "unit_test")
		qdel(target)
		TEST_ASSERT(!(target in tracked_items), "Deleted [target_type] remained registered for theft")
		TEST_ASSERT(!objective.check_completion(), "The sidearm objective stayed complete after deleting [target_type]")
	var/obj/item/gun/energy/e_gun/ordinary_gun = allocate(/obj/item/gun/energy/e_gun)
	TEST_ASSERT(!spy_bounty.is_stealable(ordinary_gun), "The spy bounty accepted an ordinary energy gun")
	TEST_ASSERT(!spy_bounty.is_stealable(null), "The spy bounty accepted a null target")

// Supply the objective directly in the test, without generating a random bounty.
/datum/spy_bounty/objective_item/sidearm_test/init_bounty(datum/spy_bounty_handler/handler)
	return FALSE

/datum/unit_test/sidearm_power_pack/Run()
	var/obj/item/ammo_box/magazine/recharge/small/power_pack = allocate(/obj/item/ammo_box/magazine/recharge/small)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	for(var/charge in 0 to power_pack.max_ammo)
		power_pack.update_appearance()
		TEST_ASSERT(icon_exists(power_pack.icon, power_pack.icon_state), "Power pack has no icon at charge [power_pack.ammo_count()]")
		var/obj/item/ammo_casing/shot = power_pack.get_round()
		qdel(shot)
	var/obj/item/ammo_casing/casing = allocate(/obj/item/ammo_casing/laser)
	power_pack.try_load(user, casing)
	TEST_ASSERT_EQUAL(power_pack.ammo_count(), 0, "A power pack accepted a loose casing")
	var/obj/machinery/recharger/recharger = allocate(/obj/machinery/recharger)
	power_pack.forceMove(recharger)
	recharger.machine_stat = NONE
	recharger.process(1)
	TEST_ASSERT_EQUAL(power_pack.ammo_count(), 1, "The small power pack could not be recharged")
