/datum/outfit/job/explorer
	name = "Explorer"

	jobtype = /datum/job/explorer
	uniform = /obj/item/clothing/under/color/orange
	gloves = /obj/item/clothing/gloves/color/black
	shoes = /obj/item/clothing/shoes/workboots
	id_trim = /datum/id_trim/job/explorer
	// AI EDIT START - Use the right ear slot for existing equipment
	ear_right = /obj/item/radio/headset/headset_cargo
	// AI EDIT END

	backpack = /obj/item/storage/backpack/explorer
	satchel = /obj/item/storage/backpack/satchel/explorer
	duffelbag = /obj/item/storage/backpack/duffelbag/explorer

	box = /obj/item/storage/box/survival/mining
	belt = /obj/item/modular_computer/pda/crew/explorer

/datum/outfit/plasmaman/explorer
	name = "Explorer Plasmaman"
	head = /obj/item/clothing/head/helmet/space/plasmaman/cargo
	uniform = /obj/item/clothing/under/plasmaman/cargo
