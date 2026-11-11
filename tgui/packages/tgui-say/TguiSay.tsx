import './styles/main.scss';

import { useEffect, useRef, useState } from 'react';
import { dragStartHandler } from 'tgui/drag';
import { formatKeyboardEvent } from 'tgui/keybindings';
import { isEscape, KEY } from 'tgui-core/keys';
import { type BooleanLike, classes } from 'tgui-core/react';

import { type Channel, ChannelIterator } from './ChannelIterator';
import { ChatHistory } from './ChatHistory';
import { LineLength, RADIO_PREFIXES, WindowSize } from './constants';
import { getPrefix, windowClose, windowOpen, windowSet } from './helpers';
import { OfflineSpeech } from './OfflineSpeech';
import { SpeechSettings } from './SpeechSettings';
import { byondMessages } from './timers';

type ByondOpen = {
  channel: Channel;
  dictation?: BooleanLike;
};

type ByondProps = {
  maxLength: number;
  lightMode: BooleanLike;
  scale: BooleanLike;
  speechMicrophone?: string;
  speechEnabled?: BooleanLike;
  speechKeys?: string[];
};

export function TguiSay() {
  const innerRef = useRef<HTMLTextAreaElement>(null);
  const channelIterator = useRef(new ChannelIterator());
  const chatHistory = useRef(new ChatHistory());
  const messages = useRef(byondMessages);
  const scale = useRef(true);
  const currentPrefix = useRef<keyof typeof RADIO_PREFIXES | null>(null);

  // I initially wanted to make these an object or a reducer, but it's not really worth it.
  // You lose the granulatity and add a lot of boilerplate.
  const [buttonContent, setButtonContent] = useState('');
  const [lightMode, setLightMode] = useState(false);
  const [maxLength, setMaxLength] = useState(1024);
  const [size, setSize] = useState(WindowSize.Small);
  const [value, setValue] = useState('');
  const speech = useRef<OfflineSpeech | null>(null);
  const speechEnabled = useRef(false);
  const speechKeys = useRef<string[]>(['ShiftT']);
  const [speechShortcut, setSpeechShortcut] = useState('ShiftT');
  const pendingDictation = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined,
  );
  const speechMaxLength = useRef(1024);
  const [speechStatus, setSpeechStatus] = useState('');
  const [dictating, setDictating] = useState(false);
  const [speechPanel, setSpeechPanel] = useState<'settings' | null>(null);
  const panel = useRef<'settings' | null>(null);
  const [microphone, setMicrophone] = useState('');
  const [speechLevel, setSpeechLevel] = useState(0);
  function showSpeechPanel(value: 'settings' | null) {
    panel.current = value;
    setSpeechPanel(value);
  }

  const position = useRef([window.screenX, window.screenY]);
  const isDragging = useRef(false);

  function setCurrentPrefix(prefix: keyof typeof RADIO_PREFIXES | null): void {
    currentPrefix.current = prefix;
  }

  function handleArrowKeys(direction: KEY.Up | KEY.Down): void {
    const chat = chatHistory.current;
    const iterator = channelIterator.current;

    if (direction === KEY.Up) {
      if (chat.isAtLatest() && value) {
        // Save current message to temp history if at the most recent message
        chat.saveTemp(value);
      }
      // Try to get the previous message, fall back to the current value if none
      const prevMessage = chat.getOlderMessage();

      if (prevMessage) {
        setButtonContent(chat.getIndex().toString());
        setValue(prevMessage);
      }
    } else {
      const nextMessage = chat.getNewerMessage() || chat.getTemp() || '';

      const newContent = chat.isAtLatest()
        ? iterator.current()
        : chat.getIndex().toString();

      setButtonContent(newContent);
      setValue(nextMessage);
    }
  }

  function handleBackspaceDelete(): void {
    const chat = chatHistory.current;
    const iterator = channelIterator.current;

    // User is on a chat history message
    if (!chat.isAtLatest()) {
      chat.reset();
      setButtonContent(currentPrefix.current ?? iterator.current());

      // Empty input, resets the channel
    } else if (
      currentPrefix.current &&
      iterator.isSay() &&
      value?.length === 0
    ) {
      setCurrentPrefix(null);
      setButtonContent(iterator.current());
    }
  }

  function handleButtonClick(event: React.MouseEvent<HTMLButtonElement>): void {
    isDragging.current = true;

    setTimeout(() => {
      // So the button doesn't jump around accidentally
      if (isDragging.current) {
        dragStartHandler(event.nativeEvent);
      }
    }, 50);
  }

  // Prevents the button from changing channels if it's dragged
  function handleButtonRelease(): void {
    isDragging.current = false;
    const currentPosition = [window.screenX, window.screenY];

    if (JSON.stringify(position.current) !== JSON.stringify(currentPosition)) {
      position.current = currentPosition;
      return;
    }

    handleIncrementChannel();
  }

  function handleClose(): void {
    clearTimeout(pendingDictation.current);
    pendingDictation.current = undefined;
    speech.current?.cancelPreparation();
    showSpeechPanel(null);
    setDictating(false);
    setSpeechStatus('');
    setValue('');
    innerRef.current?.blur();
    windowClose(scale.current);

    setTimeout(() => {
      chatHistory.current.reset();
      channelIterator.current.reset();
      unloadChat();
    }, 25);
  }

  function handleEnter(): void {
    const iterator = channelIterator.current;
    const prefix = currentPrefix.current ?? '';

    if (value?.length && value.length < maxLength) {
      chatHistory.current.add(value);
      Byond.sendMessage('entry', {
        channel: iterator.current(),
        entry: iterator.isSay() ? prefix + value : value,
      });
    }

    handleClose();
  }

  function handleForceSay(): void {
    const iterator = channelIterator.current;
    const currentValue = innerRef.current?.value;

    // Only force say if we're on a visible channel and have typed something
    if (!currentValue || !iterator.isVisible()) return;

    const prefix = currentPrefix.current ?? '';
    const grunt = iterator.isSay() ? prefix + currentValue : currentValue;

    messages.current.forceSayMsg(grunt, iterator.current());
    handleClose();
  }

  function handleSaveText(): void {
    const iterator = channelIterator.current;
    const currentValue = innerRef.current?.value;

    if (!currentValue || !iterator.isVisible()) return;

    messages.current.saveText(currentValue, iterator.current());
  }

  function handleIncrementChannel(): void {
    const iterator = channelIterator.current;

    iterator.next();
    setButtonContent(iterator.current());
    setCurrentPrefix(null);
    messages.current.channelIncrementMsg(iterator.isVisible());
  }

  function handleInput(event: React.FormEvent<HTMLTextAreaElement>): void {
    const iterator = channelIterator.current;
    let newValue = event.currentTarget.value;

    const newPrefix = getPrefix(newValue) || currentPrefix.current;
    // Handles switching prefixes
    if (newPrefix && newPrefix !== currentPrefix.current) {
      setButtonContent(RADIO_PREFIXES[newPrefix]);
      setCurrentPrefix(newPrefix);
      newValue = newValue.slice(3);
      iterator.set('Say');

      if (newPrefix === ':b ' || newPrefix === ':и ') {
        Byond.sendMessage('thinking', { visible: false });
      }
    }

    // Handles typing indicators
    if (
      channelIterator.current.isVisible() &&
      newPrefix !== ':b ' &&
      newPrefix !== ':и '
    ) {
      messages.current.typingMsg();
      messages.current.saveText(newValue, iterator.current());
    }

    setValue(newValue);
  }

  function handleKeyDown(
    event: React.KeyboardEvent<HTMLTextAreaElement>,
  ): void {
    if (speech.current?.busy) {
      event.preventDefault();
      if (isEscape(event.key)) handleClose();
      return;
    }
    if (event.getModifierState('AltGraph')) return;

    switch (event.key) {
      case KEY.Up:
      case KEY.Down:
        event.preventDefault();
        handleArrowKeys(event.key);
        break;

      case KEY.Delete:
      case KEY.Backspace:
        handleBackspaceDelete();
        break;

      case KEY.Enter:
        event.preventDefault();
        handleEnter();
        break;

      case KEY.Tab:
        event.preventDefault();
        handleIncrementChannel();
        break;

      default:
        if (isEscape(event.key)) {
          handleClose();
        }
    }
  }

  function handleOpen(data: ByondOpen): void {
    channelIterator.current.set(data.channel);

    setCurrentPrefix(null);
    setButtonContent(channelIterator.current.current());

    windowOpen(channelIterator.current.current(), scale.current);

    innerRef.current?.focus();
  }

  function handleProps(data: ByondProps): void {
    speechEnabled.current = !!data.speechEnabled;
    speechKeys.current = data.speechKeys || [];
    setSpeechShortcut(speechKeys.current[0] || 'клавиша диктовки');
    setMaxLength(data.maxLength);
    speechMaxLength.current = data.maxLength;
    speech.current?.setMicrophone(data.speechMicrophone || '');
    setMicrophone(data.speechMicrophone || '');
    setLightMode(!!data.lightMode);
    scale.current = !!data.scale;
  }

  function unloadChat(): void {
    setCurrentPrefix(null);
    setButtonContent(channelIterator.current.current());
    setValue('');
  }

  /** Subscribe to Byond messages */
  useEffect(() => {
    const controller = new OfflineSpeech({
      open: () => {
        if (panel.current === 'settings') return;
        showSpeechPanel(null);
        channelIterator.current.set('Say');
        setCurrentPrefix(null);
        setButtonContent('Говор');
        // Shift+T and Escape are handled in this same input window.
        innerRef.current?.focus();
      },
      typing: (text, status) => {
        if (!panel.current || !status) handleOpen({ channel: 'Say' });
        setDictating(false);
        setValue(text.slice(0, speechMaxLength.current));
        setSpeechStatus(status);
      },
      preview: (text, status) => {
        setDictating(true);
        setValue(text.slice(0, speechMaxLength.current));
        setSpeechStatus(status);
      },
      submit: (text) => {
        const entry = text.slice(0, speechMaxLength.current).trim();
        if (entry) {
          chatHistory.current.add(entry);
          Byond.sendMessage('entry', { channel: 'Say', entry });
        }
        handleClose();
      },
      level: setSpeechLevel,
      testResult: (text) => {
        setDictating(false);
        setValue(text);
        setSpeechStatus(
          text
            ? 'Тест завершён. Сообщение в чат не отправлено.'
            : 'Речь не распознана. Проверьте уровень звука и выбранный микрофон.',
        );
      },
    });
    speech.current = controller;
    const keyDown = (event: KeyboardEvent) => {
      if (
        speechKeys.current.includes(formatKeyboardEvent(event)) &&
        speechEnabled.current &&
        panel.current !== 'settings'
      ) {
        event.preventDefault();
        event.stopPropagation();
        if (!event.repeat) controller.toggleDictation();
      } else if (isEscape(event.key) && (controller.busy || panel.current)) {
        event.preventDefault();
        event.stopPropagation();
        handleClose();
      }
    };
    document.addEventListener('keydown', keyDown, true);
    Byond.subscribeTo('speech-cancel', handleClose);
    Byond.subscribeTo('speech-keys', (data: { keys: string[] }) => {
      speechKeys.current = data.keys || [];
      setSpeechShortcut(speechKeys.current[0] || 'клавиша диктовки');
    });
    Byond.subscribeTo('speech-device', (data: { name: string }) => {
      controller.setMicrophone(data.name);
      setMicrophone(data.name);
    });
    Byond.subscribeTo('speech-settings', () => {
      controller.cancelPreparation();
      setDictating(false);
      setSpeechStatus('');
      setValue('');
      showSpeechPanel('settings');
      windowOpen('Say', scale.current);
      Byond.sendMessage('thinking', { visible: false });
      Byond.winset('tgui_say.browser', { focus: true });
    });
    Byond.subscribeTo('speech-model', (data: { url: string }) =>
      controller.setModelUrl(data.url),
    );
    // Native byond:// calls can raise beforeunload without destroying this page.
    // Dispose only in the React cleanup below, not on a native API navigation.
    Byond.subscribeTo('props', handleProps);
    Byond.subscribeTo('force', handleForceSay);
    Byond.subscribeTo('open', (data: ByondOpen) => {
      clearTimeout(pendingDictation.current);
      pendingDictation.current = undefined;
      if (data.dictation && controller.busy) {
        controller.toggleDictation();
        return;
      }
      controller.cancelPreparation();
      showSpeechPanel(null);
      setDictating(false);
      setSpeechStatus('');
      // Exactly the original T handler first, including showing the normal field.
      handleOpen(data);
      if (data.dictation) {
        // BYOND's native navigation calls must finish before requesting the model.
        pendingDictation.current = setTimeout(() => {
          pendingDictation.current = undefined;
          controller.startDictation();
        }, 100);
      }
    });
    Byond.subscribeTo('save', handleSaveText);
    Byond.subscribeTo('close', handleClose);
    return () => {
      clearTimeout(pendingDictation.current);
      document.removeEventListener('keydown', keyDown, true);
      controller.dispose();
    };
  }, []);

  /** Value has changed, we need to check if the size of the window is ok */
  useEffect(() => {
    if (speechPanel) {
      const ratio = scale.current ? window.devicePixelRatio : 1;
      const dimensions = `${540 * ratio}x${540 * ratio}`;
      Byond.winset(null, {
        'tgui_say.size': dimensions,
        'tgui_say.browser.size': dimensions,
      });
      return;
    }
    if (dictating) {
      const ratio = scale.current ? window.devicePixelRatio : 1;
      const dimensions = `${480 * ratio}x${160 * ratio}`;
      Byond.winset(null, {
        'tgui_say.size': dimensions,
        'tgui_say.browser.size': dimensions,
      });
      setSize(WindowSize.Large);
      return;
    }
    const len = value?.length || 0;

    let newSize: WindowSize;
    if (len > LineLength.Medium) {
      newSize = WindowSize.Large;
    } else if (len <= LineLength.Medium && len > LineLength.Small) {
      newSize = WindowSize.Medium;
    } else {
      newSize = WindowSize.Small;
    }

    windowSet(newSize, scale.current);
    setSize(newSize);
  }, [value, speechPanel, dictating]);

  const TRANSLATE_ITTERATOR: Record<string, string> = {
    Say: 'Говор',
    Whis: 'Шёпот',
    Radio: 'Радио',
    Me: 'Эмоц',
    Admin: 'Админ',
    Mentor: `Мент`,
  };

  const theme =
    (currentPrefix.current && RADIO_PREFIXES[currentPrefix.current]) ||
    TRANSLATE_ITTERATOR[channelIterator.current.current()] ||
    channelIterator.current.current();

  useEffect(() => {
    setButtonContent(TRANSLATE_ITTERATOR[buttonContent] || buttonContent);
  }, [buttonContent]);

  return (
    <div
      className={classes([
        'window',
        `window-${theme}`,
        lightMode && 'window-light',
      ])}
      style={{
        zoom: scale.current ? '' : `${100 / window.devicePixelRatio}%`,
      }}
    >
      {speechPanel === 'settings' ? (
        <SpeechSettings
          startTest={() => speech.current?.startTest() ?? false}
          stopTest={() => speech.current?.release()}
          microphone={microphone}
          status={speechStatus}
          text={value}
          level={speechLevel}
          recording={dictating}
          close={handleClose}
          select={(name) => {
            speech.current?.setMicrophone(name);
            setMicrophone(name);
            Byond.sendMessage('speech-device', { name });
          }}
        />
      ) : (
        <div className={classes(['content', dictating && 'content-speech'])}>
          <button
            disabled={dictating}
            className="button"
            onMouseDown={handleButtonClick}
            onMouseUp={handleButtonRelease}
            type="button"
          >
            {buttonContent}
          </button>
          <textarea
            rows={dictating ? 5 : undefined}
            placeholder={speechStatus}
            readOnly={dictating}
            title={speechStatus}
            autoCorrect="off"
            className="textarea"
            maxLength={maxLength}
            onInput={handleInput}
            onKeyDown={handleKeyDown}
            ref={innerRef}
            spellCheck={false}
            value={value}
          />
          {dictating && (
            <div className="speech-hint">
              {speechShortcut} — отправить · Escape — отменить.
              <br />
              Запись до 30 секунд. По лимиту — отмена без отправки.
            </div>
          )}
        </div>
      )}
    </div>
  );
}
