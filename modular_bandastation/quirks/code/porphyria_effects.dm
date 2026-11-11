#define EYE_COLOR_PORPHYRIA_PRIORITY (EYE_COLOR_CULTLIKE_PRIORITY - 1)

/datum/quirk/porphyria
	/// Last applied hunger penalty, to avoid replacing mood events every processing tick.
	var/hunger_severity = 0
	/// Whether this quirk currently owns an eye color override.
	var/red_eyes = FALSE

/// Updates blood hunger effects using ordinary nutrition, as the vampire does.
/datum/quirk/porphyria/proc/update_effects()
	if(!is_active())
		clear_effects()
		return
	var/mob/living/carbon/human/holder = quirk_holder
	var/satiety_percent = clamp(holder.nutrition / NUTRITION_LEVEL_WELL_FED * 100, 0, 100)
	var/new_severity = satiety_percent <= 75 ? clamp(1 + floor((75 - satiety_percent) / 15), 1, 6) : 0
	if(new_severity != hunger_severity)
		holder.clear_mood_event("porphyria_hunger")
		if(new_severity)
			holder.add_mood_event("porphyria_hunger", /datum/mood_event/porphyria_hunger, new_severity)
		hunger_severity = new_severity
	var/should_have_red_eyes = satiety_percent <= 33 && holder.get_organ_slot(ORGAN_SLOT_EYES)
	if(should_have_red_eyes != red_eyes)
		red_eyes = should_have_red_eyes
		if(red_eyes)
			holder.add_eye_color(BLOODCULT_EYE, EYE_COLOR_PORPHYRIA_PRIORITY)
		else
			holder.remove_eye_color(EYE_COLOR_PORPHYRIA_PRIORITY)

/// Removes only the mood and eye color effects owned by this quirk.
/datum/quirk/porphyria/proc/clear_effects()
	var/mob/living/carbon/human/holder = quirk_holder
	if(!istype(holder))
		return
	holder.clear_mood_event("porphyria_hunger")
	holder.clear_mood_event("porphyria_fresh_blood")
	hunger_severity = 0
	if(red_eyes)
		holder.remove_eye_color(EYE_COLOR_PORPHYRIA_PRIORITY)
		red_eyes = FALSE

/// Only the affected character can estimate their own blood hunger by examining themselves.
/datum/quirk/porphyria/proc/on_examine(mob/living/carbon/human/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	if(user == source && is_active())
		examine_list += span_notice("Сытость: [round(clamp(source.nutrition / NUTRITION_LEVEL_WELL_FED * 100, 0, 100), 0.1)]%.")

/// A progressively stronger need for blood as ordinary nutrition decreases.
/datum/mood_event/porphyria_hunger
	description = "Мне не хватает крови."

/datum/mood_event/porphyria_hunger/add_effects(severity)
	mood_change = -clamp(severity, 1, 6)

/// Fresh blood drunk directly from a living humanoid briefly satisfies the craving.
/datum/mood_event/porphyria_fresh_blood
	description = "Как же приятна свежая кровь!"
	mood_change = 2
	timeout = 5 MINUTES

/// The victim remembers the bite well after the attacker has stopped drinking.
/datum/mood_event/porphyria_bitten
	description = "Меня только что укусили и высосали кровь!"
	mood_change = -6
	timeout = 10 MINUTES

#undef EYE_COLOR_PORPHYRIA_PRIORITY
