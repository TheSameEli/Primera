/// Test you can mouse-drop a defib off your back to unequip it
/datum/unit_test/unequip_defib

/datum/unit_test/unequip_defib/Run()
	var/mob/living/carbon/human/consistent/dummy = EASY_ALLOCATE()
	dummy.mock_client = new()
	dummy.set_hud_used(new dummy.hud_type(dummy))
	var/obj/item/defibrillator/defib = EASY_ALLOCATE()
	dummy.equip_to_slot(defib, ITEM_SLOT_BACK)

	var/old_usr = usr

	usr = dummy // mouse drop still uses usr

	defib.MouseDrop(dummy.hud_used.screen_objects[HUD_KEY_HAND_SLOT(1)])
	if(!dummy.is_holding(defib))
		TEST_FAIL("The dummy failed to remove the defib from their back via mouse drop.")

	usr = old_usr

// AI EDIT START - Cover floor defibrillation and paddle cable range
// BANDASTATION ADDITION START - Floor defibrillator regression tests
/datum/unit_test/defib_from_floor/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/defibrillator/loaded/defib = allocate(/obj/item/defibrillator/loaded)
	click_wrapper(user, defib)
	TEST_ASSERT(user.is_holding(defib.paddles), "Clicking a defibrillator on the floor did not give the user its paddles.")
	TEST_ASSERT_EQUAL(defib.loc, run_loc_floor_bottom_left, "Taking the paddles picked up the main defibrillator unit.")

	defib.paddles.attack_self(user)
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_heartattack(TRUE)
	var/initial_charge = defib.cell.charge
	click_wrapper(user, patient)
	TEST_ASSERT(!patient.undergoing_cardiac_arrest(), "The defibrillator on the floor did not restart the patient's heart.")
	TEST_ASSERT(defib.cell.charge < initial_charge, "Defibrillation from the floor did not consume battery charge.")
	user.dropItemToGround(defib.paddles, TRUE)

/datum/unit_test/defib_from_floor_range/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.reach_length = 2
	var/turf/far_turf = get_step(get_step(run_loc_floor_bottom_left, EAST), EAST)
	var/obj/item/defibrillator/loaded/defib = allocate(/obj/item/defibrillator/loaded, far_turf)
	click_wrapper(user, defib)
	TEST_ASSERT_EQUAL(defib.paddles.loc, defib, "The user took the paddles from a defibrillator outside their reach.")
	TEST_ASSERT(!user.is_holding(defib.paddles), "Extended reach left out-of-range paddles in the user's hands.")

	defib.forceMove(get_step(run_loc_floor_bottom_left, EAST))
	click_wrapper(user, defib)
	TEST_ASSERT(user.is_holding(defib.paddles), "The user could not take the paddles from an adjacent defibrillator.")
	defib.paddles.attack_self(user)
	defib.forceMove(far_turf)
	TEST_ASSERT_EQUAL(defib.paddles.loc, defib, "The paddles did not return when the main unit moved out of cable range.")
	TEST_ASSERT(!HAS_TRAIT(defib.paddles, TRAIT_WIELDED), "The user kept wielding the paddles after they returned to the main unit.")
// BANDASTATION ADDITION END
// AI EDIT END
