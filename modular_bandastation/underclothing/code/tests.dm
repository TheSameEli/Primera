/datum/unit_test/underclothing_lifecycle/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.underwear_color = "#34ab56"
	wearer.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
	wearer.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
	wearer.update_body()
	var/obj/item/clothing/underwear/garment = wearer.w_underwear
	TEST_ASSERT_NOTNULL(garment, "The existing underwear preference must produce a physical item.")
	TEST_ASSERT_NOTNULL(wearer.w_undershirt, "Undershirts must also be removable.")
	TEST_ASSERT_NOTNULL(wearer.w_socks, "Socks must also be removable.")
	TEST_ASSERT_EQUAL(wearer.get_slot_by_item(garment), ITEM_SLOT_UNDERWEAR, "Underclothing regression.")
	TEST_ASSERT(garment in wearer.get_equipped_items(), "Underwear must participate in normal inventory cleanup.")
	wearer.update_body()
	TEST_ASSERT_EQUAL(wearer.w_underwear, garment, "Redrawing must preserve item identity.")
	TEST_ASSERT(wearer.dropItemToGround(garment), "Underwear must be removable.")
	TEST_ASSERT_NULL(wearer.w_underwear, "Underclothing regression.")
	TEST_ASSERT_EQUAL(wearer.underwear, "Nude", "Underclothing regression.")
	TEST_ASSERT_EQUAL(garment.loc, wearer.loc, "Underclothing regression.")
	wearer.update_body()
	TEST_ASSERT_NULL(wearer.w_underwear, "Redrawing must not regenerate removed underwear.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(garment, ITEM_SLOT_UNDERWEAR), "Loose underwear must be wearable again.")
	TEST_ASSERT_EQUAL(wearer.w_underwear, garment, "Underclothing regression.")
	TEST_ASSERT_EQUAL(wearer.underwear_color, "#34ab56", "Removing and putting back must preserve color.")
	for(var/slot_id in list(ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS))
		var/obj/item/clothing/underwear/other_garment = wearer.get_item_by_slot(slot_id)
		TEST_ASSERT(wearer.dropItemToGround(other_garment), "Shirts and socks must be removable too.")
		TEST_ASSERT_EQUAL(wearer.vars[other_garment.appearance_key], "Nude", "Removing must clear the corresponding appearance field.")
		TEST_ASSERT(wearer.equip_to_slot_if_possible(other_garment, slot_id), "Shirts and socks must be wearable again.")
		TEST_ASSERT_EQUAL(wearer.get_item_by_slot(slot_id), other_garment, "Re-equipping must preserve item identity.")

/datum/unit_test/underclothing_transfer/Run()
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	first.underwear = /datum/sprite_accessory/clothing/underwear/male_hearts::name
	first.underwear_color = "#123456"
	first.update_body()
	second.underwear = "Nude"
	second.update_body()
	var/obj/item/clothing/underwear/garment = first.w_underwear
	TEST_ASSERT(first.dropItemToGround(garment), "Underclothing regression.")
	TEST_ASSERT(second.put_in_hands(garment), "Underclothing regression.")
	garment.attack_self(second)
	TEST_ASSERT_EQUAL(second.w_underwear, garment, "The recipient must wear the same physical item.")
	TEST_ASSERT_EQUAL(second.underwear, /datum/sprite_accessory/clothing/underwear/male_hearts::name, "Underclothing regression.")
	TEST_ASSERT_EQUAL(second.underwear_color, "#123456", "Underclothing regression.")
	TEST_ASSERT(!second.is_holding(garment), "A worn item must leave the hand.")
	TEST_ASSERT_NULL(first.w_underwear, "Underclothing regression.")
	qdel(garment)
	TEST_ASSERT_NULL(second.w_underwear, "Deleting an equipped item must clear its slot.")
	TEST_ASSERT_EQUAL(second.underwear, "Nude", "Deleting an equipped item must clear its overlay.")

/datum/unit_test/underclothing_covering/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.update_body()
	var/obj/item/clothing/underwear/garment = wearer.w_underwear
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Underclothing regression.")
	TEST_ASSERT(wearer.underclothing_hidden(ITEM_SLOT_UNDERWEAR), "Underclothing regression.")
	TEST_ASSERT(!garment.can_mob_unequip(wearer), "Self removal must respect covering clothes.")
	TEST_ASSERT(!(garment in wearer.get_visible_items()), "Covered underwear must not be exposed by visibility queries.")
	var/datum/strippable_item/slot = GLOB.strippable_human_items["underwear"]
	TEST_ASSERT_EQUAL(slot.get_obscuring(wearer), STRIPPABLE_OBSCURING_COMPLETELY, "Underclothing regression.")
	TEST_ASSERT(!slot.finish_unequip(wearer, other), "Putting on covering clothes during stripping must prevent removal.")
	TEST_ASSERT_EQUAL(wearer.w_underwear, garment, "Underclothing regression.")
	TEST_ASSERT(wearer.dropItemToGround(uniform), "Underclothing regression.")
	TEST_ASSERT(garment.can_mob_unequip(wearer), "Underclothing regression.")
	TEST_ASSERT_EQUAL(slot.get_obscuring(wearer), STRIPPABLE_OBSCURING_NONE, "Underclothing regression.")
	ADD_TRAIT(garment, TRAIT_NO_STRIP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!slot.finish_unequip(wearer, other), "A strip lock applied during the delay must prevent removal.")
	TEST_ASSERT_EQUAL(wearer.w_underwear, garment, "Locked underwear must remain equipped.")
	REMOVE_TRAIT(garment, TRAIT_NO_STRIP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(wearer.dropItemToGround(garment), "Underclothing regression.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Underclothing regression.")
	TEST_ASSERT(!wearer.equip_to_slot_if_possible(garment, ITEM_SLOT_UNDERWEAR, disable_warning = TRUE), "Cannot put underwear through a jumpsuit.")
	TEST_ASSERT(other.put_in_hands(garment), "The dresser must hold the item.")
	TEST_ASSERT(other.temporarilyRemoveItemFromInventory(garment), "Simulate the completion of the dressing delay.")
	TEST_ASSERT(!slot.finish_equip(wearer, garment, other), "A jumpsuit put on during the delay must prevent dressing.")
	TEST_ASSERT(other.is_holding(garment), "Failed dressing must return the garment to the actor.")

/datum/unit_test/underclothing_appearance/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.update_body()
	var/obj/item/clothing/underwear/garment = wearer.w_underwear
	// Existing dressers, outfits and appearance changes assign these fields directly.
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_hearts::name
	wearer.underwear_color = "#abcdef"
	wearer.update_body()
	TEST_ASSERT_EQUAL(wearer.w_underwear, garment, "Underclothing regression.")
	TEST_ASSERT_EQUAL(garment.accessory, SSaccessories.underwear_list[wearer.underwear], "Underclothing regression.")
	TEST_ASSERT_EQUAL(garment.garment_color, "#abcdef", "Underclothing regression.")
	TEST_ASSERT_NOTNULL(garment.icon, "Static-pattern underwear must have a loose-item sprite.")
	wearer.underwear = "Nude"
	wearer.update_body()
	TEST_ASSERT_NULL(wearer.w_underwear, "Underclothing regression.")
	TEST_ASSERT(QDELETED(garment), "Appearance replacement must not leak orphaned items.")
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.update_body()
	garment = wearer.w_underwear
	ADD_TRAIT(wearer, TRAIT_NO_UNDERWEAR, TRAIT_SOURCE_UNIT_TESTS)
	wearer.update_body()
	TEST_ASSERT_NULL(wearer.w_underwear, "Underclothing regression.")
	TEST_ASSERT(!QDELETED(garment), "Changing to an incompatible species must drop physical clothing.")
	TEST_ASSERT_EQUAL(garment.loc, wearer.loc, "Underclothing regression.")
	TEST_ASSERT(!wearer.equip_to_slot_if_possible(garment, ITEM_SLOT_UNDERWEAR, disable_warning = TRUE), "Underclothing regression.")

/// Every sock style must fit inside an inventory frame without losing its pattern.
/datum/unit_test/underclothing_socks_icon/Run()
	var/obj/item/clothing/underwear/socks/socks = allocate(/obj/item/clothing/underwear/socks)
	for(var/style_name in SSaccessories.socks_list)
		var/datum/sprite_accessory/clothing/style = SSaccessories.socks_list[style_name]
		if(!style?.icon_state)
			continue
		socks.set_style(style, COLOR_WHITE)
		var/icon/loose = icon(socks.icon, socks.icon_state)
		var/mutable_appearance/worn = style.make_appearance(COLOR_WHITE)
		var/icon/on_body = icon(worn.icon, worn.icon_state)
		for(var/direction in GLOB.cardinals)
			var/list/loose_colors = list()
			var/list/worn_colors = list()
			var/min_y = ICON_SIZE_Y
			var/max_y = 0
			for(var/x in 1 to ICON_SIZE_X)
				for(var/y in 1 to ICON_SIZE_Y)
					var/loose_pixel = loose.GetPixel(x, y, "", direction)
					if(loose_pixel)
						loose_colors[loose_pixel] = (loose_colors[loose_pixel] || 0) + 1
						min_y = min(min_y, y)
						max_y = max(max_y, y)
					var/worn_pixel = on_body.GetPixel(x, y, "", direction)
					if(worn_pixel)
						worn_colors[worn_pixel] = (worn_colors[worn_pixel] || 0) + 1
			TEST_ASSERT(length(loose_colors), "[style_name] has no loose-item pixels in [dir2text(direction)].")
			TEST_ASSERT(min_y > 4 && max_y < ICON_SIZE_Y - 4, "[style_name] overlaps the inventory frame in [dir2text(direction)].")
			TEST_ASSERT(abs((min_y + max_y) / 2 - (ICON_SIZE_Y + 1) / 2) <= 4, "[style_name] is not centered vertically in [dir2text(direction)].")
			TEST_ASSERT_EQUAL(length(loose_colors), length(worn_colors), "[style_name] lost pattern colors.")
			for(var/pixel_color in worn_colors)
				TEST_ASSERT_EQUAL(loose_colors[pixel_color], worn_colors[pixel_color], "[style_name] lost or recolored pixels in [dir2text(direction)].")

/datum/unit_test/underclothing_hud/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/datum/hud/human/player_hud = allocate(/datum/hud/human, wearer)
	var/atom/movable/screen/toggle = player_hud.screen_objects["human_underclothing_toggle"]
	TEST_ASSERT_NOTNULL(toggle, "The separate underclothing toggle must exist.")
	TEST_ASSERT(toggle in player_hud.screen_groups[HUD_GROUP_TOGGLEABLE_INVENTORY], "The backpack toggle must hide the underclothing button.")
	TEST_ASSERT_EQUAL(toggle.screen_loc, "WEST+2:10,SOUTH:5", "The button must sit beside shoes at the requested location.")
	TEST_ASSERT_EQUAL(toggle.icon_state, "template", "The button must use a plain frame instead of a backpack.")
	TEST_ASSERT(length(toggle.overlays), "The button must show an underwear symbol.")
	TEST_ASSERT(!player_hud.underclothing_shown, "Underclothing must start folded away.")
	for(var/slot_id in list(ITEM_SLOT_UNDERWEAR, ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS))
		var/datum/inventory_slot/slot = player_hud.inventory_slots[slot_id]
		var/atom/movable/screen/slot_box = slot.get_screen_slot(player_hud)
		TEST_ASSERT_NULL(slot_box.screen_loc, "Folded underclothing must not occupy screen space.")
		TEST_ASSERT(slot_box in player_hud.screen_groups[HUD_GROUP_TOGGLEABLE_INVENTORY], "The backpack toggle must hide all underclothing slots.")
		TEST_ASSERT(!(slot_box in player_hud.screen_groups[HUD_GROUP_STATIC]), "Underclothing slots must not remain in the always-visible HUD group.")
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.update_body()
	var/obj/item/clothing/underwear/garment = wearer.w_underwear
	player_hud.inventory_shown = TRUE
	player_hud.toggle_underclothing()
	TEST_ASSERT(player_hud.underclothing_shown, "The separate toggle must open the panel.")
	TEST_ASSERT(player_hud.inventory_shown, "Opening underclothing must preserve the main inventory state.")
	var/list/positions = list(toggle.screen_loc)
	for(var/slot_id in list(ITEM_SLOT_UNDERWEAR, ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS))
		var/datum/inventory_slot/slot = player_hud.inventory_slots[slot_id]
		var/atom/movable/screen/slot_box = slot.get_screen_slot(player_hud)
		TEST_ASSERT_NOTNULL(slot_box.screen_loc, "The open panel must show all three slots.")
		TEST_ASSERT(!(slot_box.screen_loc in positions), "The button and slots must not overlap.")
		positions += slot_box.screen_loc
	player_hud.on_viewdata_update(wearer, SQUARE_VIEWPORT_SIZE)
	TEST_ASSERT_EQUAL(toggle.screen_loc, "WEST+3:12,SOUTH+4:13", "The narrow HUD must keep suit storage clear.")
	var/list/button_position = screen_loc_to_offset(toggle.screen_loc, SQUARE_VIEWPORT_SIZE)
	var/list/storage_position = screen_loc_to_offset(ui_sstore1, SQUARE_VIEWPORT_SIZE)
	TEST_ASSERT(abs(button_position[1] - storage_position[1]) >= ICON_SIZE_X || abs(button_position[2] - storage_position[2]) >= ICON_SIZE_Y, "The button must not overlap suit storage in square view.")
	player_hud.on_viewdata_update(wearer, WIDESCREEN_VIEWPORT_SIZE)
	TEST_ASSERT_EQUAL(toggle.screen_loc, "WEST+2:10,SOUTH:5", "Returning to widescreen must restore the requested position.")
	player_hud.toggle_underclothing()
	player_hud.inventory_update()
	for(var/slot_id in list(ITEM_SLOT_UNDERWEAR, ITEM_SLOT_UNDERSHIRT, ITEM_SLOT_SOCKS))
		var/datum/inventory_slot/slot = player_hud.inventory_slots[slot_id]
		var/atom/movable/screen/inventory/slot_box = slot.get_screen_slot(player_hud)
		TEST_ASSERT_NULL(slot_box.screen_loc, "Inventory refresh must not reopen the folded panel.")
	TEST_ASSERT_EQUAL(wearer.w_underwear, garment, "Folding the panel must preserve the equipped garment.")

/datum/unit_test/underclothing_fire/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
	wearer.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
	wearer.update_body()
	wearer.burn_clothing(1, 10)
	for(var/obj/item/clothing/underwear/garment in list(wearer.w_underwear, wearer.w_undershirt, wearer.w_socks))
		TEST_ASSERT(garment.resistance_flags & ON_FIRE, "Exposed [garment.type] must ignite when its wearer burns.")
		TEST_ASSERT(garment.get_integrity() < garment.max_integrity, "Exposed underclothing must take fire damage.")
		var/slot = garment.slot_flags
		var/key = garment.appearance_key
		var/datum/component/burning/flames = garment.GetComponent(/datum/component/burning)
		TEST_ASSERT_NOTNULL(flames, "Ignited underclothing must use the normal burning component.")
		flames.process(100)
		TEST_ASSERT(QDELETED(garment), "Underclothing must eventually burn away.")
		TEST_ASSERT_NULL(wearer.get_item_by_slot(slot), "Burned underclothing must leave its inventory slot.")
		TEST_ASSERT_EQUAL(wearer.vars[key], "Nude", "Burned underclothing must clear its appearance selection.")
		wearer.update_body()
		TEST_ASSERT_NULL(wearer.get_item_by_slot(slot), "Burned underclothing must not reappear on a redraw.")

/datum/unit_test/underclothing_fire_layers/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	wearer.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	wearer.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
	wearer.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
	wearer.update_body()
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/clothing/shoes/shoes = allocate(/obj/item/clothing/shoes/sneakers/black)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Cannot equip the covering uniform.")
	TEST_ASSERT(wearer.equip_to_slot_if_possible(shoes, ITEM_SLOT_FEET), "Cannot equip covering shoes.")
	wearer.burn_clothing(1, 10)
	TEST_ASSERT(uniform.resistance_flags & ON_FIRE, "The exposed uniform must burn.")
	TEST_ASSERT(shoes.resistance_flags & ON_FIRE, "Exposed shoes must burn.")
	for(var/obj/item/clothing/underwear/garment in list(wearer.w_underwear, wearer.w_undershirt, wearer.w_socks))
		TEST_ASSERT(!(garment.resistance_flags & ON_FIRE), "Covering clothing must shield [garment.type] from ignition.")
		TEST_ASSERT_EQUAL(garment.get_integrity(), garment.max_integrity, "Covered underclothing must remain undamaged.")
	uniform.adjust_to_alt()
	wearer.burn_clothing(1, 10)
	TEST_ASSERT(wearer.w_undershirt.resistance_flags & ON_FIRE, "Rolling the uniform down must expose the undershirt to fire.")
	TEST_ASSERT(!(wearer.w_underwear.resistance_flags & ON_FIRE), "A rolled-down uniform must still cover the briefs.")
	TEST_ASSERT(!(wearer.w_socks.resistance_flags & ON_FIRE), "Shoes must still cover socks.")
	wearer.w_undershirt.extinguish()
	uniform.adjust_to_normal()
	wearer.burn_clothing(1, 10)
	TEST_ASSERT(!(wearer.w_undershirt.resistance_flags & ON_FIRE), "Pulling the uniform back up must shield the undershirt again.")
	var/datum/component/burning/uniform_flames = uniform.GetComponent(/datum/component/burning)
	var/datum/component/burning/shoe_flames = shoes.GetComponent(/datum/component/burning)
	TEST_ASSERT_NOTNULL(uniform_flames, "The covering uniform must have caught fire.")
	TEST_ASSERT_NOTNULL(shoe_flames, "The covering shoes must have caught fire.")
	uniform_flames.process(100)
	shoe_flames.process(100)
	TEST_ASSERT(QDELETED(uniform) && QDELETED(shoes), "Covering clothing must burn away for this probe.")
	wearer.burn_clothing(1, 10)
	for(var/obj/item/clothing/underwear/garment in list(wearer.w_underwear, wearer.w_undershirt, wearer.w_socks))
		TEST_ASSERT(garment.resistance_flags & ON_FIRE, "Underclothing must ignite after the covering layer burns away.")
		garment.extinguish()
