/// Mechanical fragments must remain visible when the cabin breaks apart in open space.
/obj/effect/decal/remains/robot/spacepod
	name = "spacepod wreckage"
	desc = "Обугленные фрагменты корпуса, проводки и механизмов космического челнока."
	plane = GAME_PLANE
	layer = LOW_OBJ_LAYER

/obj/effect/decal/remains/robot/spacepod/NeverShouldHaveComeHere(turf/here_turf)
	return isclosedturf(here_turf)

/obj/vehicle/sealed/spacepod/proc/leave_wreckage()
	if(!isturf(loc))
		return
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(spawn_spacepod_wreckage), locs.Copy())

/// Ordinary decals are destroyed by ex_act; create the debris after the blast queue has drained.
/proc/spawn_spacepod_wreckage(list/turf/footprint)
	UNTIL(!SSexplosions.is_exploding())
	for(var/turf/tile as anything in footprint)
		if(!tile || isclosedturf(tile))
			continue
		var/obj/effect/decal/remains/robot/spacepod/debris = new(tile)
		debris.pixel_x = rand(-6, 6)
		debris.pixel_y = rand(-6, 6)
