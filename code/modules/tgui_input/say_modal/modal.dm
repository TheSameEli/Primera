/** Assigned say modal of the client */
/client/var/datum/tgui_say/tgui_say

/**
 * Creates a JSON encoded message to open TGUI say modals properly.
 *
 * Arguments:
 * channel - The channel to open the modal in.
 * Returns:
 * string - A JSON encoded message to open the modal.
 */
/client/proc/tgui_say_create_open_command(channel, dictation = FALSE)
	var/list/payload = list(channel = channel)
	if(dictation)
		payload["dictation"] = TRUE
	var/message = TGUI_CREATE_MESSAGE("open", payload)
	return "\".output tgui_say.browser:update [message]\""

/**
 * The tgui say modal. This initializes an input window which hides until
 * the user presses one of the speech hotkeys. Once something is entered, it will
 * delegate the speech to the proper channel.
 */
/datum/tgui_say
	/// The user who opened the window
	var/client/client
	/// Injury phrases to blurt out
	var/static/list/hurt_phrases = list("ГХА!", "ГРХ!", "УГХ!", "АРГХ!", "АУ!", "МГХ!", "АХХ!")
	/// Max message length
	var/max_length = MAX_MESSAGE_LEN
	/// The modal window
	var/datum/tgui_window/window
	/// Boolean for whether the tgui_say was opened by the user.
	var/window_open
	/// What text was present in the say box the last time save_text was called
	var/saved_text = ""
	/// What channel was in use in the say box the last time save_text was called
	var/saved_channel
	/// Speech suffuxes used for force_say after "-". Defaults to hurt_phrases
	var/list/alter_phrases

/** Creates the new input window to exist in the background. */
/datum/tgui_say/New(client/client, id)
	src.client = client
	window = new(client, id)
	winset(client, SKIN_TGUISAY, "size=1,1;is-visible=0;")
	window.subscribe(src, PROC_REF(on_message))
	window.is_browser = TRUE

/**
 * After a brief period, injects the scripts into
 * the window to listen for open commands.
 */
/datum/tgui_say/proc/initialize()
	set waitfor = FALSE
	// Sleep to defer initialization to after client constructor
	sleep(3 SECONDS)
	window.initialize(
			strict_mode = TRUE,
			inline_css = file("tgui/public/tgui-say.bundle.css"),
			inline_js = file("tgui/public/tgui-say.bundle.js"),
	);

/**
 * Ensures nothing funny is going on window load.
 * Minimizes the window, sets max length, closes all
 * typing and thinking indicators. This is triggered
 * as soon as the window sends the "ready" message.
 */
/datum/tgui_say/proc/load()
	window_open = FALSE

	winset(client, SKIN_TGUISAY, "pos=848,500;is-visible=0;")

	window.send_message("props", list(
		"lightMode" = client.prefs?.read_preference(/datum/preference/toggle/tgui_say_light_mode),
		"scale" = client.prefs?.read_preference(/datum/preference/toggle/ui_scale),
		"maxLength" = max_length,
		"speechEnabled" = CONFIG_GET(flag/tgui_say_speech),
		"speechKeys" = client.prefs?.key_bindings["Dictation"],
		"speechMicrophone" = client.prefs?.read_preference(/datum/preference/text/speech_microphone),
	))

	stop_thinking()
	return TRUE

/**
 * Sets the window as "opened" server side, though it is already
 * visible to the user. We do this to set local vars &
 * start typing (if enabled and in an IC channel). Logs the event.
 *
 * Arguments:
 * payload - A list containing the channel the window was opened in.
 */
/datum/tgui_say/proc/open(payload)
	if(!payload?["channel"])
		CRASH("No channel provided to an open TGUI-Say")
	window_open = TRUE
	// BANDASTATION ADDITION START - Mentors
	var/static/list/no_thinking_bubble_channels = list(
		OOC_CHANNEL,
		ADMIN_CHANNEL,
		MENTOR_CHANNEL,
		PRAY_CHANNEL,
	)
	// BANDASTATION ADDITION END - Mentors
	saved_text = ""
	if(!(payload["channel"] in no_thinking_bubble_channels)) // BANDASTATION EDIT - Mentors: (payload["channel"] in no_thinking_bubble_channels && payload["channel"] != PRAY_CHANNEL)
		start_thinking()
	if(!client.typing_indicators)
		log_speech_indicators("[key_name(client)] started typing at [loc_name(client.mob)], indicators DISABLED.")
	return TRUE

/**
 * Closes the window serverside. Closes any open chat bubbles
 * regardless of preference. Logs the event.
 */
/datum/tgui_say/proc/close()
	window_open = FALSE
	stop_thinking()
	if(!client.typing_indicators)
		log_speech_indicators("[key_name(client)] stopped typing at [loc_name(client.mob)], indicators DISABLED.")

/**
 * The equivalent of ui_act, this waits on messages from the window
 * and delegates actions.
 */
/datum/tgui_say/proc/on_message(type, payload)
	if(type == "speech-device" && istext(payload?["name"]))
		if(client.prefs.update_preference(GLOB.preference_entries[/datum/preference/text/speech_microphone], payload["name"]))
			client.prefs.save_preferences()
			SStgui.update_uis(client.prefs)
		return TRUE
	if(type == "speech-model" && CONFIG_GET(flag/tgui_say_speech))
		var/datum/asset/model = get_asset_datum(/datum/asset/simple/tgui_speech)
		model.send(client)
		var/list/mappings = model.get_url_mappings()
		window.send_message("speech-model", list("url" = mappings["vosk-ru.tar.gz"]))
		return TRUE
	if(type == "ready")
		load()
		return TRUE
	if (type == "open")
		open(payload)
		return TRUE
	if (type == "close")
		close()
		return TRUE
	if (type == "thinking")
		if(payload["visible"] == TRUE)
			start_thinking()
			return TRUE
		if(payload["visible"] == FALSE)
			stop_thinking()
			return TRUE
		return FALSE
	if (type == "typing")
		start_typing()
		return TRUE
	if (type == "entry" || type == "force" || type == "save")
		handle_entry(type, payload)
		return TRUE
	return FALSE

/datum/asset/simple/tgui_speech
	assets = list("vosk-ru.tar.gz" = 'html/speech/vosk-model-small-ru-0.22.tar.gz')

/datum/preference_middleware/offline_speech
	action_delegations = list("speech_settings" = PROC_REF(open_settings))

/datum/preference_middleware/offline_speech/proc/open_settings(list/params, mob/user)
	if(user.client?.prefs != preferences)
		return FALSE
	if(!CONFIG_GET(flag/tgui_say_speech))
		to_chat(user, span_warning("Диктовка отключена на этом сервере."))
		return FALSE
	user.client.tgui_say?.window.send_message("speech-settings")
	return FALSE
