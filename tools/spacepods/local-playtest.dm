// Compiled only by start-local.ps1; never included in the normal game.
/datum/job/spacepod_technician
	exp_requirements = 0
	minimal_player_age = 0
	random_spawns_possible = FALSE

/area/misc/testroom/spacepod_local
	name = "Локальный ангар подов"

/area/misc/testroom/spacepod_local/vacuum
	name = "Локальный полигон: вакуум"
	default_gravity = ZERO_GRAVITY

// The local hangar can be flown out of without venting its breathable workshop.
/obj/effect/forcefield/spacepod_local
	name = "атмосферная граница полигона"
	desc = "Тестовое поле удерживает воздух, пропуская людей и поды. За ним — настоящий вакуум."
	density = FALSE
	can_atmos_pass = ATMOS_PASS_NO
	initial_duration = 0

/datum/modpack/spacepod_local
	name = "Локальная проверка подов"
	desc = "Изолированный игровой стенд для ручной проверки порта."
	author = "PrimeDream"
	var/datum/turf_reservation/arena
	var/turf/origin

/datum/modpack/spacepod_local/post_initialize()
	RegisterSignal(SSticker, COMSIG_TICKER_ENTER_PREGAME, PROC_REF(on_pregame))

/datum/modpack/spacepod_local/Destroy()
	origin = null
	QDEL_NULL(arena)
	return ..()

/datum/modpack/spacepod_local/proc/on_pregame(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(SSticker, COMSIG_TICKER_ENTER_PREGAME)
	INVOKE_ASYNC(src, PROC_REF(build_hangar))

/datum/modpack/spacepod_local/proc/at(x_offset, y_offset)
	return locate(origin.x + x_offset, origin.y + y_offset, origin.z)

/datum/modpack/spacepod_local/proc/build_hangar()
	arena = SSmapping.request_turf_block_reservation(48, 36, 1, turf_type_override = /turf/open/space)
	if(!arena)
		CRASH("Could not reserve the local spacepod arena.")
	origin = arena.bottom_left_turfs[1]
	var/area/misc/testroom/spacepod_local/hangar = new
	var/area/misc/testroom/spacepod_local/vacuum/vacuum = new
	for(var/turf/tile as anything in arena.reserved_turfs)
		tile.change_area(get_area(tile), vacuum)
	for(var/dx in 8 to 31)
		for(var/dy in 8 to 25)
			var/turf/tile = at(dx, dy)
			tile = tile.ChangeTurf(/turf/open/floor/iron, flags = CHANGETURF_IGNORE_AIR)
			tile.change_area(get_area(tile), hangar)
			if(dx == 8 || dx == 31 || dy == 8 || dy == 25)
				new /obj/effect/forcefield/spacepod_local(tile)
	// Keep the real station's engineering job spawn; the separate hangar remains available to admin area jumps.
	var/obj/vehicle/sealed/spacepod/civilian/civilian = new(at(18, 14))
	civilian.name = "Тестовый гражданский под"
	civilian.add_equipment(null, new /obj/item/spacepod_equipment/weaponry/mining_laser_basic(civilian), "weapon_system")
	civilian.add_equipment(null, new /obj/item/spacepod_equipment/misc/tracker(civilian), "misc_system")
	civilian.add_equipment(null, new /obj/item/spacepod_equipment/sec_cargo/chair(civilian), "sec_cargo_system")
	civilian.add_equipment(null, new /obj/item/spacepod_equipment/cargo/ore(civilian), "cargo_system")
	var/obj/vehicle/sealed/spacepod/sec/security = new(at(24, 14))
	security.name = "Тестовый под СБ"
	var/obj/vehicle/sealed/spacepod/civilian/cargo_pod = new(at(18, 17))
	cargo_pod.name = "Тестовый грузовой под"
	var/obj/item/spacepod_equipment/cargo/crate/crate_bay = new(cargo_pod)
	cargo_pod.install_equipment(crate_bay, crate_bay.slot)
	var/obj/item/spacepod_equipment/sec_cargo/loot_box/loot_bay = new(cargo_pod)
	cargo_pod.install_equipment(loot_bay, loot_bay.slot)
	new /obj/item/flashlight(loot_bay)
	crate_bay.storage = new /obj/structure/closet/crate(crate_bay)
	var/obj/item/spacepod_equipment/key/key = new(at(14, 15))
	key.id = security.lock_system.id
	new /obj/vehicle/sealed/spacepod/civilian/damaged(at(24, 20))
	new /obj/machinery/computer/podtracker(at(12, 20))
	var/obj/machinery/mecha_part_fabricator/spacepod/fabricator = new(at(12, 22))
	fabricator.rmat.set_local_size(7 * 200 * SHEET_MATERIAL_AMOUNT)
	for(var/material_type in list(/datum/material/iron, /datum/material/glass, /datum/material/plasma, /datum/material/uranium, /datum/material/gold, /datum/material/silver, /datum/material/diamond))
		fabricator.rmat.mat_container.insert_amount_mat(200 * SHEET_MATERIAL_AMOUNT, material_type)
	new /obj/machinery/portable_atmospherics/canister/air(at(15, 22))
	new /obj/machinery/portable_atmospherics/canister/air(at(16, 22))
	var/list/supplies = list(
		/obj/item/storage/toolbox/mechanical,
		/obj/item/weldingtool/largetank,
		/obj/item/clothing/head/utility/welding,
		/obj/item/stack/sheet/iron/fifty,
		/obj/item/stack/sheet/glass/fifty,
		/obj/item/stock_parts/power_store/cell/high,
		/obj/item/pod_paint_bucket,
		/obj/item/pod_parts/core,
		/obj/item/pod_parts/armor,
		/obj/item/circuitboard/mecha/pod,
		/obj/item/spacepod_equipment/weaponry/laser,
		/obj/item/spacepod_equipment/cargo/crate,
		/obj/item/spacepod_equipment/locators/basic_pod_locator,
		/obj/item/clothing/suit/space/eva,
		/obj/item/clothing/head/helmet/space/eva,
	)
	var/supply_index = 0
	for(var/supply_type in supplies)
		new supply_type(at(11 + (supply_index % 6), 10 + FLOOR(supply_index / 6, 1)))
		supply_index++
	new /obj/item/stack/cable_coil(at(17, 10), 50)
	new /obj/structure/spacepod_frame(at(19, 20))
	new /obj/structure/closet/crate(at(28, 20))
	for(var/dy in 12 to 18)
		var/turf/tile = at(39, dy)
		tile.ChangeTurf(/turf/closed/mineral/iron)
	SSticker.start_immediately = FALSE
	SSticker.timeLeft = 120 SECONDS
	log_world("SPACEPODS_LOCAL_READY: map=[SSmapping.current_map.map_name]; role spawns in station engineering; test hangar [origin.x + 14],[origin.y + 16],[origin.z].")
