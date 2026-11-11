#define SPACEPOD_ALERT_BATTERY_LOW (1<<0)
#define SPACEPOD_ALERT_BATTERY_CRITICAL (1<<1)
#define SPACEPOD_ALERT_OXYGEN_LOW (1<<2)
#define SPACEPOD_ALERT_OXYGEN_CRITICAL (1<<3)
#define SPACEPOD_ALERT_RESERVE_LOW (1<<4)
#define SPACEPOD_ALERT_HULL_LOW (1<<5)
#define SPACEPOD_ALERT_HULL_CRITICAL (1<<6)

/obj/vehicle/sealed/spacepod
	var/cabin_alert_flags = NONE
	var/list/cabin_alert_heard = list()
	var/cabin_alert_channel
	COOLDOWN_DECLARE(cabin_alert_cooldown)

/// Separate recovery thresholds keep a reading near the boundary from repeating an alert.
/obj/vehicle/sealed/spacepod/proc/update_cabin_alert_threshold(flag, value, threshold, recovery, inclusive = TRUE)
	if(value >= recovery)
		cabin_alert_flags &= ~flag
	else if(inclusive ? value <= threshold : value < threshold)
		cabin_alert_flags |= flag

/obj/vehicle/sealed/spacepod/proc/process_cabin_alerts()
	if(QDELETED(src) || melting_down)
		return
	var/list/status = get_status_data()
	var/charge = status["charge_percent"]
	if(!isnum(charge))
		charge = 0
	var/oxygen = status["active_oxygen_kpa"]
	if(!isnum(oxygen))
		oxygen = 0
	var/integrity = status["integrity_percent"]
	update_cabin_alert_threshold(SPACEPOD_ALERT_BATTERY_LOW, charge, 20, 25)
	update_cabin_alert_threshold(SPACEPOD_ALERT_BATTERY_CRITICAL, charge, 5, 10)
	update_cabin_alert_threshold(SPACEPOD_ALERT_HULL_LOW, integrity, 50, 55)
	update_cabin_alert_threshold(SPACEPOD_ALERT_HULL_CRITICAL, integrity, 25, 30)
	update_cabin_alert_threshold(SPACEPOD_ALERT_OXYGEN_LOW, oxygen, 18, 20, inclusive = FALSE)
	update_cabin_alert_threshold(SPACEPOD_ALERT_OXYGEN_CRITICAL, oxygen, 16, 18, inclusive = FALSE)
	if(use_internal_tank)
		var/reserve_oxygen = 0
		var/datum/gas_mixture/tank_air = internal_tank?.return_air()
		if(!QDELETED(tank_air) && tank_air.volume > 0 && tank_air.temperature > 0)
			reserve_oxygen = tank_air.moles[/datum/gas/oxygen] * R_IDEAL_GAS_EQUATION * T20C / ONE_ATMOSPHERE
		update_cabin_alert_threshold(SPACEPOD_ALERT_RESERVE_LOW, reserve_oxygen, 400, 600)
	else
		cabin_alert_flags &= ~SPACEPOD_ALERT_RESERVE_LOW

	for(var/mob/listener as anything in cabin_alert_heard.Copy())
		if(QDELETED(listener) || listener.loc != src || !is_occupant(listener) || !GET_CLIENT(listener))
			stop_cabin_alert_for(listener)
			if(QDELETED(src))
				return
		else
			cabin_alert_heard[listener] &= cabin_alert_flags
	if(!cabin_alert_flags)
		stop_cabin_alerts()
		return

	var/list/listeners = list()
	var/pending_flags = NONE
	for(var/mob/listener as anything in occupants)
		if(QDELETED(listener) || listener.loc != src || !is_occupant(listener) || !GET_CLIENT(listener))
			continue
		listeners += listener
		pending_flags |= cabin_alert_flags & ~cabin_alert_heard[listener]
	if(!length(listeners))
		stop_cabin_alerts()
		return
	if(!pending_flags || !COOLDOWN_FINISHED(src, cabin_alert_cooldown))
		return

	var/static/list/priority = list(
		SPACEPOD_ALERT_OXYGEN_CRITICAL,
		SPACEPOD_ALERT_HULL_CRITICAL,
		SPACEPOD_ALERT_BATTERY_CRITICAL,
		SPACEPOD_ALERT_OXYGEN_LOW,
		SPACEPOD_ALERT_RESERVE_LOW,
		SPACEPOD_ALERT_HULL_LOW,
		SPACEPOD_ALERT_BATTERY_LOW,
	)
	var/selected_flag
	for(var/flag in priority)
		if(pending_flags & flag)
			selected_flag = flag
			break
	var/heard_flags = selected_flag
	var/voice_file
	var/message
	switch(selected_flag)
		if(SPACEPOD_ALERT_OXYGEN_CRITICAL)
			heard_flags |= SPACEPOD_ALERT_OXYGEN_LOW
			voice_file = 'modular_bandastation/spacepods/sound/alerts/oxygen_critical.ogg'
			message = "Опасный уровень кислорода. Проверьте подачу воздуха."
		if(SPACEPOD_ALERT_HULL_CRITICAL)
			heard_flags |= SPACEPOD_ALERT_HULL_LOW
			voice_file = 'modular_bandastation/spacepods/sound/alerts/hull_critical.ogg'
			message = "Внимание. Критические повреждения корпуса."
		if(SPACEPOD_ALERT_BATTERY_CRITICAL)
			heard_flags |= SPACEPOD_ALERT_BATTERY_LOW
			voice_file = 'modular_bandastation/spacepods/sound/alerts/battery_critical.ogg'
			message = "Критический уровень электропитания. Проверьте батарею."
		if(SPACEPOD_ALERT_OXYGEN_LOW)
			voice_file = 'modular_bandastation/spacepods/sound/alerts/oxygen_low.ogg'
			message = "Внимание. Снижается уровень кислорода."
		if(SPACEPOD_ALERT_RESERVE_LOW)
			voice_file = 'modular_bandastation/spacepods/sound/alerts/reserve_low.ogg'
			message = "Низкий запас кислорода в резервном баллоне."
		if(SPACEPOD_ALERT_HULL_LOW)
			voice_file = 'modular_bandastation/spacepods/sound/alerts/hull_low.ogg'
			message = "Корпус повреждён. Требуется ремонт."
		if(SPACEPOD_ALERT_BATTERY_LOW)
			voice_file = 'modular_bandastation/spacepods/sound/alerts/battery_low.ogg'
			message = "Внимание. Низкий заряд батареи."

	var/list/recipients = list()
	for(var/mob/listener as anything in listeners)
		if(!(cabin_alert_heard[listener] & selected_flag))
			recipients += listener
			cabin_alert_heard[listener] |= heard_flags
	if(!cabin_alert_channel)
		cabin_alert_channel = SSsounds.reserve_sound_channel_for_datum(src)
	var/channel = cabin_alert_channel
	COOLDOWN_START(src, cabin_alert_cooldown, 6 SECONDS)
	for(var/mob/listener as anything in recipients)
		if(QDELETED(src) || melting_down || cabin_alert_channel != channel)
			return
		if(QDELETED(listener) || listener.loc != src || !is_occupant(listener) || !GET_CLIENT(listener))
			continue
		to_chat(listener, span_warning("Бортовой компьютер: [message]"))
		if(QDELETED(src) || melting_down || cabin_alert_channel != channel)
			return
		if(QDELETED(listener) || listener.loc != src || !is_occupant(listener) || !GET_CLIENT(listener))
			continue
		listener.playsound_local(null, voice_file, 55, FALSE, channel = channel, pressure_affected = FALSE, use_reverb = FALSE, volume_preference = /datum/preference/numeric/volume/sound_tts_volume_announcement)
		if(QDELETED(src))
			return

/obj/vehicle/sealed/spacepod/proc/stop_cabin_alert_for(mob/listener)
	var/channel = cabin_alert_channel
	cabin_alert_heard -= listener
	if(channel && !QDELETED(listener))
		listener.stop_sound_channel(channel)
		if(QDELETED(src))
			return
	if(!length(cabin_alert_heard))
		stop_cabin_alerts()

/// Runs before SSsounds releases the pod's managed channel during deletion.
/obj/vehicle/sealed/spacepod/proc/stop_cabin_alerts(datum/source)
	SIGNAL_HANDLER
	var/channel = cabin_alert_channel
	cabin_alert_channel = null
	var/list/listeners = cabin_alert_heard.Copy()
	cabin_alert_heard.Cut()
	if(!channel)
		return
	for(var/mob/listener as anything in listeners)
		if(!QDELETED(listener))
			listener.stop_sound_channel(channel)
	if(SSsounds.using_channels[num2text(channel)] == src)
		SSsounds.free_sound_channel(channel)

#undef SPACEPOD_ALERT_BATTERY_LOW
#undef SPACEPOD_ALERT_BATTERY_CRITICAL
#undef SPACEPOD_ALERT_OXYGEN_LOW
#undef SPACEPOD_ALERT_OXYGEN_CRITICAL
#undef SPACEPOD_ALERT_RESERVE_LOW
#undef SPACEPOD_ALERT_HULL_LOW
#undef SPACEPOD_ALERT_HULL_CRITICAL
