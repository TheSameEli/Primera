/// Makes sure items using GAGS have all the icon states needed to work
/datum/unit_test/greyscale_item_icon_states

/datum/unit_test/greyscale_item_icon_states/Run()
	for(var/obj/item/item_path as anything in subtypesof(/obj/item))
		if(isnull(initial(item_path.greyscale_colors)))
			continue //All configs depend on greyscale_colors being defined.
		var/held_icon_state = initial(item_path.inhand_icon_state) || initial(item_path.post_init_icon_state)

		var/datum/greyscale_config/lefthand = SSgreyscale.configurations["[initial(item_path.greyscale_config_inhand_left)]"]
		if(lefthand && !lefthand.icon_states[held_icon_state])
			TEST_FAIL("[lefthand.DebugName()] is missing a sprite for the held lefthand for [item_path]. Expected icon state: '[held_icon_state]'")

		var/datum/greyscale_config/righthand = SSgreyscale.configurations["[initial(item_path.greyscale_config_inhand_right)]"]
		if(righthand && !righthand.icon_states[held_icon_state])
			TEST_FAIL("[righthand.DebugName()] is missing a sprite for the held righthand for [item_path]. Expected icon state: '[held_icon_state]'")

		var/datum/greyscale_config/worn = SSgreyscale.configurations["[initial(item_path.greyscale_config_worn)]"]
		var/worn_icon_state = initial(item_path.worn_icon_state) || initial(item_path.post_init_icon_state)
		if(worn && !worn.icon_states[worn_icon_state])
			TEST_FAIL("[worn.DebugName()] is missing a sprite for the worn overlay for [item_path]. Expected icon state: '[worn_icon_state]'")

		var/datum/greyscale_config/belt = SSgreyscale.configurations["[initial(item_path.greyscale_config_belt)]"]
		var/inside_belt_icon_state = initial(item_path.inside_belt_icon_state) || initial(item_path.icon_state)
		if(belt && !belt.icon_states[inside_belt_icon_state])
			TEST_FAIL("[belt.DebugName()] is missing a sprite for the belt overlay for [item_path]. Expected icon state: '[inside_belt_icon_state]'")

/// Makes sure objects using greyscale configs have, if any, the correct number of colors
/datum/unit_test/greyscale_color_count

/datum/unit_test/greyscale_color_count/Run()
	for(var/atom/thing as anything in subtypesof(/atom))
		var/datum/greyscale_config/config = SSgreyscale.configurations["[initial(thing.greyscale_config)]"]
		if(!config)
			continue
		var/list/colors = splittext(initial(thing.greyscale_colors), "#")
		if(!length(colors))
			continue
		var/number_of_colors = length(colors) - 1
		if(config.expected_colors != number_of_colors)
			TEST_FAIL("[thing] has the wrong amount of colors configured for [config.DebugName()]. Expected [config.expected_colors] colors but found [number_of_colors].")

/// Colored uniforms must render their own initialized state rather than an inherited jumpsuit state.
/datum/unit_test/colored_uniform_worn_states/Run()
	var/list/expected_states = list(
		/obj/item/clothing/under/color/jumpskirt/grey = "jumpskirt",
		/obj/item/clothing/under/color/rainbow = "rainbow",
	)
	for(var/uniform_type in expected_states)
		var/obj/item/clothing/under/uniform = allocate(uniform_type)
		var/mutable_appearance/worn = uniform.build_worn_icon(slot_id = ITEM_SLOT_ICLOTHING)
		TEST_ASSERT_EQUAL(worn.icon_state, expected_states[uniform_type], "[uniform_type] rendered the wrong uniform shape.")

/// Female uniform caching must keep distinct source images and cropping masks separate.
/datum/unit_test/female_uniform_icon_cache/Run()
	var/palette = "#123abc"
	var/colored_file = SSgreyscale.GetColoredIconByType(/datum/greyscale_config/jumpsuit/worn, palette)
	var/icon/template = wear_female_version("jumpsuit", 'icons/mob/clothing/under/color.dmi', FEMALE_UNIFORM_FULL, palette)
	var/icon/colored = wear_female_version("jumpsuit", colored_file, FEMALE_UNIFORM_FULL, palette)
	if(icon2base64(template) == icon2base64(colored))
		TEST_FAIL("A colored uniform reused the uncolored template from the female icon cache.")

	var/icon/full_mask = wear_female_version("jumpskirt", colored_file, FEMALE_UNIFORM_FULL, palette)
	var/full_pixels = icon2base64(full_mask)
	var/icon/top_mask = wear_female_version("jumpskirt", colored_file, FEMALE_UNIFORM_TOP_ONLY, palette)
	if(full_pixels == icon2base64(top_mask))
		TEST_FAIL("A top-only female mask reused an image cropped with the full mask.")
	var/icon/custom_mask = wear_female_version("jumpskirt", colored_file, FEMALE_UNIFORM_FULL, palette, /datum/female_uniform/turtleneck)
	if(full_pixels == icon2base64(custom_mask))
		TEST_FAIL("A custom female mask reused an image cropped with the default mask.")
