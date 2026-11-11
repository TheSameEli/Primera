/datum/unit_test/spacepod_vacuum/proc/get_wreckage()
	var/list/debris = list()
	for(var/turf/tile as anything in vacuum_block.reserved_turfs)
		for(var/obj/effect/decal/remains/robot/spacepod/fragment in tile)
			if(!QDELETED(fragment))
				debris += fragment
	return debris

/datum/unit_test/spacepod_vacuum/wreckage
	/// The subject's occupied turfs, retained after its deletion.
	var/list/blast_footprint = list()
	/// A separate native blast verifies that world events are not attributed to the pod.
	var/turf/control_epicenter
	/// Actual blasts centered within the subject's footprint.
	var/subject_explosions = 0
	/// Actual blasts centered at the independent control.
	var/control_explosions = 0

/datum/unit_test/spacepod_vacuum/wreckage/Destroy()
	UnregisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION)
	blast_footprint.Cut()
	control_epicenter = null
	return ..()

/// Observe real blast events without replacing the native explosion path.
/datum/unit_test/spacepod_vacuum/wreckage/proc/on_explosion(datum/source, turf/epicenter, devastation_range, heavy_impact_range, light_impact_range, took, orig_dev_range, orig_heavy_range, orig_light_range, atom/explosion_cause, explosion_index)
	SIGNAL_HANDLER
	if(epicenter in blast_footprint)
		subject_explosions++
	if(epicenter == control_epicenter)
		control_explosions++
	log_test("Spacepod wreckage explosion: index=[explosion_index] epicenter=([epicenter.x],[epicenter.y],[epicenter.z]) ranges=(d[devastation_range],h[heavy_impact_range],l[light_impact_range]) cause=[explosion_cause] type=[explosion_cause?.type] subject=[epicenter in blast_footprint] control=[epicenter == control_epicenter]")

/// Real blast processing must leave floating debris; cleanup and repeated callbacks must not create it.
/datum/unit_test/spacepod_vacuum/wreckage/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve open space for the wreckage test.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	qdel(pod)
	sleep(1 TICKS)
	TEST_ASSERT_EQUAL(length(get_wreckage()), 0, "Administrative deletion created explosion wreckage.")
	pod = allocate(/obj/vehicle/sealed/spacepod/civilian, vacuum_origin)
	var/list/turf/footprint = pod.locs.Copy()
	blast_footprint = footprint
	control_epicenter = locate(vacuum_origin.x - 4, vacuum_origin.y - 4, vacuum_origin.z)
	TEST_ASSERT(control_epicenter in vacuum_block.reserved_turfs, "The independent blast control is outside the private reservation.")
	RegisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION, PROC_REF(on_explosion))
	explosion(vacuum_origin, devastation_range = 1, adminlog = FALSE, silent = TRUE)
	// A real independent blast must not be attributed to the cabin under test.
	explosion(control_epicenter, devastation_range = 1, adminlog = FALSE, silent = TRUE)
	var/deadline = world.time + 6 SECONDS
	var/list/debris
	while(world.time < deadline)
		debris = get_wreckage()
		if(QDELETED(pod) && !SSexplosions.is_exploding() && length(debris) == 4)
			break
		stoplag(1)
	allocated |= debris
	TEST_ASSERT(QDELETED(pod), "The real devastating explosion did not destroy the cabin.")
	TEST_ASSERT(!SSexplosions.is_exploding(), "The real wreckage test blast did not drain its native queue.")
	TEST_ASSERT_EQUAL(control_explosions, 1, "The independent control did not produce exactly one real blast; see the wreckage explosion log.")
	TEST_ASSERT_EQUAL(subject_explosions, 1, "External devastation triggered an additional blast within the pod footprint; see the wreckage explosion log.")
	TEST_ASSERT_EQUAL(length(debris), 4, "The destroyed 2x2 cabin must leave exactly four pieces of mechanical debris.")
	for(var/obj/effect/decal/remains/robot/spacepod/fragment as anything in debris)
		TEST_ASSERT(fragment.loc in footprint, "A debris fragment appeared outside the destroyed cabin's footprint.")
		TEST_ASSERT_EQUAL(fragment.icon_state, "remainsrobot", "Mechanical wreckage does not use the native robot-debris sprite.")
		TEST_ASSERT(fragment.icon_state in icon_states(fragment.icon), "The wreckage sprite is missing.")
		TEST_ASSERT_EQUAL(fragment.plane, GAME_PLANE, "Floating wreckage is hidden in the floor plane.")
	pod.ex_act(EXPLODE_DEVASTATE)
	pod.detonate()
	sleep(1 TICKS)
	deadline = world.time + 6 SECONDS
	while(SSexplosions.is_exploding() && world.time < deadline)
		stoplag(1)
	TEST_ASSERT(!SSexplosions.is_exploding(), "Repeated destruction callbacks left an undrained native blast queue.")
	TEST_ASSERT_EQUAL(length(get_wreckage()), 4, "Repeated destruction callbacks duplicated the debris.")
	TEST_ASSERT_EQUAL(subject_explosions, 1, "A deleted cabin detonated again; see the wreckage explosion log.")
	var/obj/vehicle/sealed/spacepod/nullspace_pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	nullspace_pod.moveToNullspace()
	nullspace_pod.ex_act(EXPLODE_DEVASTATE)
	sleep(1 TICKS)
	TEST_ASSERT(QDELETED(nullspace_pod), "A devastating hit did not dispose of a cabin without a turf.")
	TEST_ASSERT_EQUAL(length(get_wreckage()), 4, "A cabin without a turf spawned stray debris.")
