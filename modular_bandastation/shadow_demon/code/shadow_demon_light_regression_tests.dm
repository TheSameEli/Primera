#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// Record emission while preserving the real sound delivery path.
/obj/structure/shadowcocoon/lure_test
	var/lure_sound_count = 0

/obj/structure/shadowcocoon/lure_test/play_lure_sound()
	lure_sound_count++
	return ..()

/// Ordinary melee must use every lighter's native off path without burning its fuel.
/datum/unit_test/shadow_demon_lighters/Run()
	var/mob/living/basic/demon/shadow/demon = allocate(/mob/living/basic/demon/shadow)
	// Isolate extinguishing from the target item's integrity and combat balance.
	demon.obj_damage = 0
	for(var/lighter_type in list(/obj/item/lighter, /obj/item/lighter/greyscale, /obj/item/lighter/slime, /obj/item/lighter/skull, /obj/item/lighter/mime, /obj/item/lighter/bright))
		var/obj/item/lighter/lighter = allocate(lighter_type)
		lighter.set_lit(TRUE)
		var/starting_fuel = lighter.get_fuel()
		demon.melee_attack(lighter, ignore_cooldown = TRUE)
		TEST_ASSERT(!lighter.lit, "Ordinary melee did not close [lighter_type].")
		TEST_ASSERT(!lighter.light_on, "Ordinary melee left [lighter_type] emitting light.")
		TEST_ASSERT_EQUAL(lighter.get_temperature(), 0, "An extinguished lighter still supplied ignition heat.")
		TEST_ASSERT_EQUAL(lighter.get_fuel(), starting_fuel, "Extinguishing a lighter consumed its fuel.")

	var/mob/living/carbon/human/carrier = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/lighter/mime/carried_lighter = allocate(/obj/item/lighter/mime, carrier)
	carried_lighter.set_lit(TRUE)
	shadow_demon_extinguish(carrier)
	TEST_ASSERT(!carried_lighter.lit, "A carried lighter with zero light range bypassed native extinguishing.")

/// A stationary or newly arrived light must be suppressed on the next pulse, without retries.
/datum/unit_test/shadow_demon_cocoon_lights/Run()
	var/obj/structure/shadowcocoon/cocoon = allocate(/obj/structure/shadowcocoon)
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	welder.switched_on()
	TEST_ASSERT(welder.isOn(), "The welding tool fixture did not ignite.")
	var/obj/item/lighter/lighter = allocate(/obj/item/lighter)
	var/obj/item/flashlight/flashlight = allocate(/obj/item/flashlight)
	lighter.set_lit(TRUE)
	flashlight.set_light_on(TRUE)
	var/starting_fuel = lighter.get_fuel()
	var/obj/item/flashlight/flare/unlit_flare = allocate(/obj/item/flashlight/flare)
	var/flare_fuel = unlit_flare.fuel
	cocoon.process(2)
	TEST_ASSERT(!welder.isOn(), "A cocoon pulse left a welding tool lit.")
	TEST_ASSERT(!lighter.lit && !lighter.light_on, "A cocoon pulse left a stationary lighter lit.")
	TEST_ASSERT(!flashlight.light_on, "A cocoon pulse did not suppress a stationary flashlight immediately after a welder.")
	TEST_ASSERT_EQUAL(lighter.get_fuel(), starting_fuel, "A cocoon unnecessarily destroyed a lighter's fuel.")
	TEST_ASSERT_EQUAL(unlit_flare.fuel, flare_fuel, "The cocoon consumed fuel from an unlit flare.")

	var/mob/living/carbon/human/carrier = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
	var/obj/item/lighter/carried_lighter = allocate(/obj/item/lighter, carrier)
	carried_lighter.set_lit(TRUE)
	carrier.forceMove(get_turf(cocoon))
	flashlight.set_light_on(TRUE)
	cocoon.process(2)
	TEST_ASSERT(!carried_lighter.lit, "A newly arrived carried lighter escaped the next cocoon pulse.")
	TEST_ASSERT(!flashlight.light_on, "Relighting a stationary flashlight bypassed the next cocoon pulse.")

/// Shadow touch, grapple and cocoon pulses keep the mech's native light and pilot action in sync.
/datum/unit_test/shadow_demon_mech_lights/Run()
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(mech.mob_enter(pilot, silent = TRUE), "The pilot could not enter the mech fixture.")
	var/datum/action/vehicle/sealed/mecha/mech_toggle_lights/light_action = locate() in pilot.actions
	TEST_ASSERT_NOTNULL(light_action, "The pilot did not receive the native light action.")
	var/datum/component/overlay_lighting/lighting = mech.GetComponent(/datum/component/overlay_lighting)
	TEST_ASSERT_NOTNULL(lighting, "The mech fixture has no directional light component.")
	light_action.Trigger(pilot)
	TEST_ASSERT(mech.light_on && (mech.mecha_flags & LIGHTS_ON), "The native action did not switch on the mech's lights.")
	TEST_ASSERT(lighting.light.overlay_lighting_flags & LIGHTING_ON, "The mech fixture did not enable its rendered light.")
	shadow_demon_extinguish(mech)
	TEST_ASSERT(!mech.light_on && !(mech.mecha_flags & LIGHTS_ON), "Shadow touch did not disable the mech's light and flag.")
	TEST_ASSERT(!(lighting.light.overlay_lighting_flags & LIGHTING_ON), "Shadow touch left the mech's rendered light enabled.")
	TEST_ASSERT_EQUAL(light_action.button_icon_state, "mech_lights_off", "Shadow touch did not update the pilot's light action.")
	shadow_demon_extinguish(mech)
	TEST_ASSERT(!mech.light_on, "Touching an unlit mech switched its lights back on.")

	var/mob/living/basic/demon/shadow/demon = allocate(/mob/living/basic/demon/shadow, get_step(get_turf(mech), EAST))
	demon.obj_damage = 0
	light_action.Trigger(pilot)
	TEST_ASSERT(mech.light_on, "The pilot could not relight the mech after shadow touch.")
	demon.melee_attack(mech, ignore_cooldown = TRUE)
	TEST_ASSERT(!mech.light_on, "A direct demon melee hit did not extinguish the mech.")
	light_action.Trigger(pilot)
	var/obj/projectile/magic/shadow_hand/projectile = allocate(/obj/projectile/magic/shadow_hand, get_turf(mech))
	projectile.firer = demon
	projectile.on_hit(mech)
	TEST_ASSERT(!mech.light_on, "Shadow Grapple did not extinguish the mech.")

	var/obj/structure/shadowcocoon/cocoon = allocate(/obj/structure/shadowcocoon, get_turf(mech))
	light_action.Trigger(pilot)
	cocoon.process(2)
	TEST_ASSERT(!mech.light_on && !(mech.mecha_flags & LIGHTS_ON), "A cocoon pulse did not extinguish the mech.")
	TEST_ASSERT_EQUAL(light_action.button_icon_state, "mech_lights_off", "A cocoon pulse left the pilot's light action out of sync.")
	cocoon.process(2)
	TEST_ASSERT(!mech.light_on, "A second cocoon pulse relit an already dark mech.")
	light_action.Trigger(pilot)
	TEST_ASSERT(mech.light_on, "Shadow suppression permanently disabled the mech's native light action.")

/// The actual Alt-click route must give immediate feedback and keep periodic lures running.
/datum/unit_test/shadow_demon_cocoon_lure/Run()
	var/obj/structure/shadowcocoon/lure_test/cocoon = allocate(/obj/structure/shadowcocoon/lure_test)
	var/mob/living/basic/demon/shadow/demon = allocate(/mob/living/basic/demon/shadow)
	TEST_ASSERT(cocoon.silent, "The lure unexpectedly started enabled.")
	TEST_ASSERT(demon.base_click_alt(cocoon), "Native Alt-click did not reach the cocoon's toggle.")
	TEST_ASSERT(!cocoon.silent, "Alt-click did not enable the lure.")
	TEST_ASSERT_EQUAL(cocoon.lure_sound_count, 1, "Enabling the lure did not emit its first sound immediately.")
	TEST_ASSERT_EQUAL(cocoon.time_since_last_hallucination, 0, "The immediate lure did not reset its periodic timer.")

	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	welder.switched_on()
	cocoon.process(24)
	TEST_ASSERT_EQUAL(cocoon.lure_sound_count, 2, "Extinguishing a welder skipped the periodic lure sound.")
	TEST_ASSERT_EQUAL(cocoon.time_since_last_hallucination, 0, "The periodic lure failed to reset its timer.")
	TEST_ASSERT(demon.base_click_alt(cocoon), "Native Alt-click could not disable the lure.")
	TEST_ASSERT(cocoon.silent, "Alt-click did not disable the lure.")
	cocoon.process(100)
	TEST_ASSERT_EQUAL(cocoon.lure_sound_count, 2, "A disabled lure kept emitting sounds.")
	var/mob/living/carbon/human/outsider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT_EQUAL(cocoon.click_alt(outsider), NONE, "A human enabled the demonic lure.")
	TEST_ASSERT(cocoon.silent, "An unauthorized toggle changed the lure state.")

#endif
