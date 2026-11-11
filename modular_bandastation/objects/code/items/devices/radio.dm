// Blueshield
/obj/item/encryptionkey/heads/blueshield
	name = "blueshield's encryption key"
	icon_state = "cypherkey_centcom"
	channels = list(RADIO_CHANNEL_COMMAND = 1, RADIO_CHANNEL_SECURITY = 1, RADIO_CHANNEL_JUSTICE = 1)
	greyscale_config = /datum/greyscale_config/encryptionkey_centcom
	greyscale_colors = "#1d2657#dca01b"

/obj/item/radio/headset/blueshield
	name = "blueshield's headset"
	desc = "The headset of the guy who keeps the administration alive."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/blueshield

/obj/item/radio/headset/blueshield/alt
	name = "blueshield's bowman headset"
	desc = "The headset of the guy who keeps the administration alive. Protects your ears from flashbangs."
	icon_state = "com_headset_alt"
	worn_icon_state = "com_headset_alt"

/obj/item/radio/headset/blueshield/alt/Initialize(mapload)
	. = ..()
	// AI EDIT START - Support independent ear inventory slots
	AddComponent(/datum/component/wearertargeting/earprotection)
	// AI EDIT END
	// AI EDIT START - Reserve both ear slots for protected earpieces
	AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
	// AI EDIT END

// Nanotrasen Representative
/obj/item/encryptionkey/heads/nanotrasen_representative
	name = "nanotrasen representative's encryption key"
	icon_state = "cypherkey_centcom"
	channels = list(RADIO_CHANNEL_COMMAND = 1, RADIO_CHANNEL_JUSTICE = 1, RADIO_CHANNEL_SECURITY = 1, RADIO_CHANNEL_ENGINEERING = 0, RADIO_CHANNEL_SCIENCE = 0, RADIO_CHANNEL_MEDICAL = 0, RADIO_CHANNEL_SUPPLY = 0, RADIO_CHANNEL_SERVICE = 0)
	greyscale_config = /datum/greyscale_config/encryptionkey_centcom
	greyscale_colors = "#1d2657#dca01b"

/obj/item/radio/headset/heads/nanotrasen_representative
	name = "nanotrasen representative's headset"
	desc = "The headset of the guy who keeps the administration alive."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/nanotrasen_representative

/obj/item/radio/headset/heads/nanotrasen_representative/alt
	name = "nanotrasen representative's bowman headset"
	desc = "The headset of the guy who keeps the administration alive. Protects your ears from flashbangs."
	icon_state = "com_headset_alt"
	worn_icon_state = "com_headset_alt"

/obj/item/radio/headset/heads/nanotrasen_representative/alt/Initialize(mapload)
	. = ..()
	// AI EDIT START - Support independent ear inventory slots
	AddComponent(/datum/component/wearertargeting/earprotection)
	// AI EDIT END
	// AI EDIT START - Reserve both ear slots for protected earpieces
	AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
	// AI EDIT END

// Magistrate
/obj/item/encryptionkey/heads/magistrate
	name = "magistrate's encryption key"
	channels = list(RADIO_CHANNEL_COMMAND = 1, RADIO_CHANNEL_SECURITY = 1, RADIO_CHANNEL_JUSTICE = 1)

/obj/item/radio/headset/heads/magistrate
	name = "magistrate's headset"
	desc = "Я веселое описание."
	icon_state = "com_headset"
	worn_icon_state = "com_headset"
	keyslot = /obj/item/encryptionkey/heads/magistrate

/obj/item/radio/headset/heads/magistrate/alt
	name = "magistrate's bowman headset"
	desc = "Я веселое описание. Защищает уши от громкого шума."
	icon_state = "com_headset_alt"
	worn_icon_state = "com_headset_alt"

/obj/item/radio/headset/heads/magistrate/alt/Initialize(mapload)
	. = ..()
	// AI EDIT START - Support independent ear inventory slots
	AddComponent(/datum/component/wearertargeting/earprotection)
	// AI EDIT END
	// AI EDIT START - Reserve both ear slots for protected earpieces
	AddComponent(/datum/component/occupies_slots, ITEM_SLOT_EARS)
	// AI EDIT END

// Lawyer
/obj/item/encryptionkey/lawyer
	name = "lawyer's encryption key"
	channels = list(RADIO_CHANNEL_SECURITY = 1, RADIO_CHANNEL_JUSTICE = 1)

/obj/item/radio/headset/lawyer
	name = "lawyer's headset"
	desc = "Простой наушник юриста, имеющий доступ к юридическому и каналу безопасности."
	icon_state = "justice_headset"
	worn_icon_state = "justice_headset"
	keyslot = /obj/item/encryptionkey/lawyer

/obj/item/radio/headset/blueshield/get_worn_icon_state_by_slot()
	return alist(
		ITEM_SLOT_EAR_RIGHT = "com_headset_right",
		ITEM_SLOT_EAR_LEFT = "com_headset_left",
	)

/obj/item/radio/headset/heads/nanotrasen_representative/get_worn_icon_state_by_slot()
	return alist(
		ITEM_SLOT_EAR_RIGHT = "com_headset_right",
		ITEM_SLOT_EAR_LEFT = "com_headset_left",
	)

/obj/item/radio/headset/heads/magistrate/get_worn_icon_state_by_slot()
	return alist(
		ITEM_SLOT_EAR_RIGHT = "com_headset_right",
		ITEM_SLOT_EAR_LEFT = "com_headset_left",
	)

/obj/item/radio/headset/lawyer/get_worn_icon_state_by_slot()
	return alist(
		ITEM_SLOT_EAR_RIGHT = "justice_headset_right",
		ITEM_SLOT_EAR_LEFT = "justice_headset_left",
	)

/obj/item/radio/headset/blueshield/alt/get_worn_icon_state_by_slot()
	return null

/obj/item/radio/headset/heads/nanotrasen_representative/alt/get_worn_icon_state_by_slot()
	return null

/obj/item/radio/headset/heads/magistrate/alt/get_worn_icon_state_by_slot()
	return null
