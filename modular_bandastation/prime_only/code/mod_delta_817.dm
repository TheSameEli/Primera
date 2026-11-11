// AI EDIT START - Delta-817 MODsuit theme and equipment.
/**
 * Apocryphal-based theme with Delta-817 sprites and an open helmet that leaves hair visible.
 */
/datum/mod_theme/apocryphal/delta_817
	name = "Delta-817 standard"
	desc = "A standard-issue MODsuit for Delta-817 operators."
	extended_desc = "An Apocryphal-based MODsuit issued as standard equipment to Delta-817 operators."
	default_skin = "apocryphal"
	slowdown_deployed = 0.25

/** Configures Delta-817 sprites and helmet visibility while preserving inherited part settings. */
/datum/mod_theme/apocryphal/delta_817/New()
	// Keep the Apocryphal part configuration while using Delta-817 sprites.
	variants = deep_copy_list_alt(variants)
	variants["apocryphal"][/obj/item/clothing/head/mod][UNSEALED_INVISIBILITY] &= ~HIDEHAIR
	variants["apocryphal"][/obj/item/clothing/head/mod][SEALED_INVISIBILITY] |= HIDEHAIR
	variants["apocryphal"][MOD_ICON_OVERRIDE] = 'modular_bandastation/prime_only/icons/centcom/mod_delta.dmi'
	variants["apocryphal"][MOD_WORN_ICON_OVERRIDE] = 'modular_bandastation/prime_only/icons/centcom/mod_delta.dmi'
	return ..()

/**
 * Applies the separate inventory and worn states in the Delta-817 sprite sheet.
 *
 * Arguments:
 * * mod - Control unit owning the part and its seal state.
 * * part - Control unit or clothing part to update.
 */
/datum/mod_theme/apocryphal/delta_817/proc/apply_delta_icon_states(obj/item/mod/control/mod, obj/item/part)
	var/static/list/icon_states_by_part = list(
		"control" = "backpack",
		"helmet" = "helmet_icon",
		"chestplate" = "armor_icon",
		"gauntlets" = "gloves_icon",
		"boots" = "boots_icon",
	)
	var/item_icon_state = icon_states_by_part[part.base_icon_state]
	if(!item_icon_state)
		return
	var/datum/mod_part/part_datum = mod.get_part_datum(part)
	part.icon_state = item_icon_state
	part.worn_icon_state = "[mod.skin]-[part.base_icon_state][part_datum.sealed ? "-sealed" : ""]"

/datum/mod_theme/apocryphal/delta_817/set_skin(obj/item/mod/control/mod, skin)
	. = ..()
	for(var/obj/item/part as anything in mod.get_parts() + mod)
		apply_delta_icon_states(mod, part)
		mod.wearer?.update_clothing(part.slot_flags)

/obj/item/mod/control/pre_equipped/apocryphal/delta_817/update_icon_state()
	. = ..()
	icon_state = "backpack"

/obj/item/mod/control/pre_equipped/apocryphal/delta_817/seal_part(obj/item/clothing/part, is_sealed)
	. = ..()
	var/datum/mod_theme/apocryphal/delta_817/delta_theme = theme
	delta_theme?.apply_delta_icon_states(src, part)
	wearer?.update_clothing(part.slot_flags)

/** Pre-equipped Delta-817 MODsuit retaining Apocryphal modules and access requirements. */
/obj/item/mod/control/pre_equipped/apocryphal/delta_817
	theme = /datum/mod_theme/apocryphal/delta_817
// AI EDIT END
