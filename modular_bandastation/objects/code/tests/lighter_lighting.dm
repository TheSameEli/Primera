/// Painting a burning lighter updates its light mask, survives relighting, and restores its native tint.
/datum/unit_test/lighter_lighting/Run()
	var/obj/item/lighter/lighter = allocate(/obj/item/lighter)
	var/datum/component/overlay_lighting/lighting = lighter.GetComponent(/datum/component/overlay_lighting)
	lighter.set_lit(TRUE)

	lighter.add_atom_colour(color_transition_filter(COLOR_BLUE, SATURATION_OVERRIDE), WASHABLE_COLOUR_PRIORITY)
	var/list/blue_rgb = rgb2num(lighting.light.visible_mask.color)
	TEST_ASSERT(blue_rgb[3] > blue_rgb[1] && blue_rgb[3] > blue_rgb[2], "Painting a burning lighter blue did not turn its emitted light blue.")
	var/blue_light = lighting.light.visible_mask.color

	lighter.set_lit(FALSE)
	lighter.set_lit(TRUE)
	TEST_ASSERT_EQUAL(lighting.light.visible_mask.color, blue_light, "Relighting a painted lighter lost its light tint.")

	lighter.add_atom_colour(COLOR_GREEN, ADMIN_COLOUR_PRIORITY)
	var/list/green_rgb = rgb2num(lighting.light.visible_mask.color)
	TEST_ASSERT(green_rgb[2] > green_rgb[1] && green_rgb[2] > green_rgb[3], "A higher-priority plain color did not update the emitted light.")

	lighter.remove_atom_colour(ADMIN_COLOUR_PRIORITY)
	TEST_ASSERT_EQUAL(lighting.light.visible_mask.color, blue_light, "Removing the plain color did not restore the underlying paint's light tint.")
	lighter.remove_atom_colour(WASHABLE_COLOUR_PRIORITY)
	TEST_ASSERT_EQUAL(LOWER_TEXT(lighting.light.visible_mask.color), LOWER_TEXT(initial(lighter.light_color)), "Removing all paint did not restore the lighter's native light tint.")
