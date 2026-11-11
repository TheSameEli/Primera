/datum/hud/human
	/// Underclothing is folded away independently of the main inventory.
	var/underclothing_shown = FALSE

/datum/hud/human/proc/toggle_underclothing()
	underclothing_shown = !underclothing_shown
	update_underclothing_panel()

/// Keep the button beside shoes, leaving suit storage clear on narrower viewports.
/datum/hud/human/proc/update_underclothing_panel(view)
	var/list/view_size = getviewsize(view || mymob?.canon_client?.view || WIDESCREEN_VIEWPORT_SIZE)
	var/atom/movable/screen/toggle = screen_objects["human_underclothing_toggle"]
	if(toggle)
		toggle.screen_loc = view_size[1] >= 19 ? "WEST+2:10,SOUTH:5" : "WEST+3:12,SOUTH+4:13"
		toggle.update_appearance()
	var/row = 1
	for(var/slot_id in list(ITEM_SLOT_SOCKS, ITEM_SLOT_UNDERWEAR, ITEM_SLOT_UNDERSHIRT))
		var/datum/inventory_slot/slot = inventory_slots[slot_id]
		var/atom/movable/screen/inventory/slot_box = slot?.get_screen_slot(src)
		if(slot_box)
			slot_box.screen_loc = underclothing_shown ? "WEST+3:12,SOUTH+[row]:[5 + 2 * row]" : null
		row++

/datum/hud/human/on_viewdata_update(datum/source, view)
	. = ..()
	update_underclothing_panel(view)

/atom/movable/screen/human/underclothing_toggle
	name = "Нижнее бельё"
	desc = "Показать или скрыть слоты майки, нижнего белья и носков."
	icon_state = "template"
	base_icon_state = "template"
	mouse_over_pointer = MOUSE_HAND_POINTER

/atom/movable/screen/human/underclothing_toggle/Click()
	var/datum/hud/human/owner_hud = hud
	if(!istype(owner_hud) || usr != owner_hud.mymob || !usr.client || !owner_hud.hud_shown)
		return
	owner_hud.toggle_underclothing()

/atom/movable/screen/human/underclothing_toggle/update_icon_state()
	var/datum/hud/human/owner_hud = hud
	icon_state = "[base_icon_state][owner_hud?.underclothing_shown ? "_active" : ""]"
	return ..()

/atom/movable/screen/human/underclothing_toggle/update_overlays()
	. = ..()
	var/static/icon/underwear_symbol
	if(!underwear_symbol)
		underwear_symbol = icon('icons/mob/clothing/underwear.dmi', "male_briefs", SOUTH)
		underwear_symbol.Crop(12, 9, 20, 12)
		underwear_symbol.Scale(18, 8)
	var/mutable_appearance/symbol = mutable_appearance(underwear_symbol)
	symbol.pixel_x = 7
	symbol.pixel_y = 12
	symbol.color = COLOR_PALE_BLUE_GRAY
	. += symbol
