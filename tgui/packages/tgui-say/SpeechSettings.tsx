import { useEffect, useRef, useState } from 'react';
import { MicrophoneMonitor } from './MicrophoneMonitor';
import { microphoneError } from './microphone';

export function SpeechSettings(props: {
  startTest: () => boolean;
  stopTest: () => void;
  microphone: string;
  status: string;
  text: string;
  level: number;
  recording: boolean;
  select: (name: string) => void;
  close: () => void;
}) {
  const [devices, setDevices] = useState<MediaDeviceInfo[]>([]);
  const [error, setError] = useState('');
  const [testFeedback, setTestFeedback] = useState('');
  const [detecting, setDetecting] = useState(false);
  const [accessGranted, setAccessGranted] = useState(false);
  const [monitorEnabled, setMonitorEnabled] = useState(false);
  const [monitorReady, setMonitorReady] = useState(false);
  const [refresh, setRefresh] = useState(0);
  const [level, setLevel] = useState(0);
  const [decibels, setDecibels] = useState(-100);
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    void navigator.mediaDevices
      ?.enumerateDevices()
      .then((list) =>
        setDevices(list.filter((item) => item.kind === 'audioinput')),
      )
      .catch(() => {});
    void navigator.permissions
      ?.query({ name: 'microphone' as PermissionName })
      .then((permission) => {
        if (permission.state === 'granted') setAccessGranted(true);
      })
      .catch(() => {});
    return () => {
      mounted.current = false;
    };
  }, []);

  useEffect(() => {
    if (!monitorEnabled) return;
    let current = true;
    const monitor = new MicrophoneMonitor((percent, db) => {
      if (!current) return;
      setLevel(percent);
      setDecibels(db);
    });
    setDetecting(true);
    setMonitorReady(false);
    setLevel(0);
    setDecibels(-100);
    setError('');
    void monitor
      .start(props.microphone)
      .then(async () => {
        if (!current) return;

        setMonitorReady(true);
        const list = await navigator.mediaDevices.enumerateDevices();
        if (current)
          setDevices(list.filter((item) => item.kind === 'audioinput'));
      })
      .catch((error) => {
        if (!current) return;
        monitor.stop();

        setError(microphoneError(error));
      })
      .finally(() => {
        if (current) setDetecting(false);
      });
    return () => {
      current = false;
      monitor.stop();
    };
  }, [monitorEnabled, props.microphone, refresh]);

  async function detect() {
    setMonitorEnabled(false);
    setDetecting(true);
    setError('');
    // Request from the button's user gesture, before resolving any saved device.
    let permissionStream: MediaStream | undefined;
    try {
      permissionStream = await navigator.mediaDevices.getUserMedia({
        audio: true,
        video: false,
      });
      const list = (await navigator.mediaDevices.enumerateDevices()).filter(
        (device) => device.kind === 'audioinput',
      );
      if (!mounted.current) return;
      setDevices(list);
      setAccessGranted(true);

      if (
        props.microphone &&
        !list.some((device) => device.label === props.microphone)
      )
        props.select('');
      setMonitorEnabled(true);
      setRefresh((value) => value + 1);
    } catch (error) {
      if (!mounted.current) return;
      setAccessGranted(false);

      setError(microphoneError(error));
    } finally {
      for (const track of permissionStream?.getTracks() ?? []) track.stop();
      if (mounted.current) setDetecting(false);
    }
  }

  return (
    <section className="speech-panel">
      <button
        type="button"
        aria-label="Закрыть настройки диктовки"
        onClick={props.close}
        style={{ float: 'right' }}
      >
        ×
      </button>
      <h2>Микрофон и диктовка</h2>
      <p>
        Распознавание работает на этом компьютере. Проверка ничего не отправляет
        в игровой чат.
      </p>
      <p>
        Обычный BYOND 516 пока не предоставляет разрешение микрофона для TGUI.
        При отказе клиента обычный ввод по T продолжает работать.
      </p>
      <label>
        Микрофон
        <select
          value={props.microphone}
          disabled={!accessGranted || detecting || props.recording}
          onChange={(event) => props.select(event.currentTarget.value)}
        >
          <option value="">Системный по умолчанию</option>
          {props.microphone &&
            !devices.some((device) => device.label === props.microphone) && (
              <option value={props.microphone}>
                Сохранённый: {props.microphone} — сначала разрешите доступ
              </option>
            )}
          {devices
            .filter(
              (device) =>
                device.label &&
                device.deviceId !== 'default' &&
                device.deviceId !== 'communications',
            )
            .map((device) => (
              <option key={device.deviceId} value={device.label}>
                {device.label}
              </option>
            ))}
        </select>
      </label>
      <div className="speech-actions">
        <button
          type="button"
          disabled={detecting || props.recording}
          onClick={() => void detect()}
        >
          {accessGranted ? 'Обновить список микрофонов' : 'Разрешить микрофон'}
        </button>
        <button
          type="button"
          onClick={() => {
            setError('');
            if (props.recording) {
              props.stopTest();
              return;
            }
            setTestFeedback('Подготавливаю тест распознавания…');
            if (!props.startTest()) {
              setTestFeedback(
                'Распознаватель не готов. Закройте настройки и откройте снова.',
              );
            }
          }}
        >
          {props.recording ? 'Стоп и результат' : 'Тест на 10 секунд'}
        </button>
      </div>
      <div className="speech-level">
        <div>
          Уровень звука:{' '}
          <strong>
            {Math.round(monitorEnabled ? level : props.level * 100)}%
          </strong>
          {monitorReady && ` · ${Math.round(decibels)} дБFS`}
        </div>
        <div
          className="speech-level-track"
          role="progressbar"
          aria-label="Уровень микрофона"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(level)}
        >
          <div
            className="speech-level-fill"
            style={{ width: `${monitorEnabled ? level : props.level * 100}%` }}
          />
        </div>
        <small>
          {monitorReady
            ? 'Микрофон подключён. Говорите — шкала должна двигаться.'
            : detecting
              ? 'Подключаю микрофон…'
              : 'Нажмите «Разрешить микрофон» для доступа и списка устройств.'}
        </small>
      </div>
      <p role="status">
        {props.status ||
          testFeedback ||
          error ||
          'Выберите микрофон и запустите тест.'}
      </p>
      <textarea
        aria-label="Результат теста"
        value={props.text}
        readOnly
        placeholder="Здесь появится распознанная речь"
      />
      <button type="button" onClick={props.close}>
        Закрыть / отменить
      </button>
    </section>
  );
}
