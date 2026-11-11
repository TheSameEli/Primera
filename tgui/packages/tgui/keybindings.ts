import { isEscape, KEY } from 'tgui-core/keys';

export function isStandardKey(event: KeyboardEvent): boolean {
  return (
    event.key !== KEY.Alt &&
    event.key !== KEY.Control &&
    event.key !== KEY.Shift &&
    !isEscape(event.key)
  );
}

const KEY_CODE_TO_BYOND: Record<string, string> = {
  DEL: 'Delete',
  DOWN: 'South',
  END: 'Southwest',
  HOME: 'Northwest',
  INSERT: 'Insert',
  LEFT: 'West',
  PAGEDOWN: 'Southeast',
  PAGEUP: 'Northeast',
  RIGHT: 'East',
  UP: 'North',
  ' ': 'Space',
};

/**
 * So, as it turns out, KeyboardEvent seems to be broken with IE 11, the
 * DOM_KEY_LOCATION_X codes are all undefined. See this to see why it's 3:
 * https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/location
 */
const DOM_KEY_LOCATION_NUMPAD = 3;
export function formatKeyboardEvent(event: KeyboardEvent): string {
  let text = '';

  if (event.altKey) {
    text += 'Alt';
  }

  if (event.ctrlKey) {
    text += 'Ctrl';
  }

  if (event.shiftKey) {
    text += 'Shift';
  }

  if (event.location === DOM_KEY_LOCATION_NUMPAD) {
    text += 'Numpad';
  }

  if (isStandardKey(event)) {
    // Seperately pull out digits, otherwise SHIFT+1 turns into '!' and
    // the keybinding is unusable
    const digit = event.code?.match(/^Digit(\d)$/)?.[1];
    const key = digit ?? event.key.toUpperCase();
    text += KEY_CODE_TO_BYOND[key] || key;
  }

  return text;
}
