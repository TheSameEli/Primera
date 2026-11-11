import { type KaldiRecognizer, Model } from 'vosk-browser';
import { microphoneError } from './microphone';

type Callbacks = {
  open: () => void;
  typing: (text: string, status: string) => void;
  preview: (text: string, status: string) => void;
  submit: (text: string) => void;
  testResult?: (text: string) => void;
  level?: (level: number) => void;
};

/** One recognizer per utterance; late model/microphone callbacks cannot send. */
export class OfflineSpeech {
  private held = false;
  private active = false;
  private stopping = false;
  private generation = 0;
  private watchdog?: ReturnType<typeof setTimeout>;
  private model?: Model;
  private modelPromise?: Promise<Model>;
  private resolveModelUrl?: (url: string) => void;
  private recognizer?: KaldiRecognizer;
  private stream?: MediaStream;
  private context?: AudioContext;
  private processor?: ScriptProcessorNode;
  private source?: MediaStreamAudioSourceNode;
  private finalText = '';
  private partialText = '';
  private pendingChunks = 0;
  private disposed = false;
  private preparingModel = false;
  private testing = false;
  private microphone = '';
  private modelAbort?: AbortController;

  constructor(private callbacks: Callbacks) {}

  get busy() {
    return this.held || this.active;
  }

  get isTesting() {
    return this.testing;
  }
  get modelReady() {
    return !!this.model?.ready;
  }

  setMicrophone(name: string) {
    this.microphone = name;
  }

  startTest(): boolean {
    if (this.disposed) return false;
    // A test button explicitly starts a new attempt, even after interrupted preparation.
    this.cancelPreparation();
    this.held = this.testing = true;
    void this.start();
    return true;
  }

  startDictation() {
    if (this.busy || this.disposed) return;
    this.held = true;
    void this.start();
  }

  cancelPreparation() {
    this.cancel();
    if (!this.model?.ready) {
      this.modelAbort?.abort();
      this.modelAbort = undefined;
      this.model?.terminate();
      this.model = undefined;
      this.modelPromise = undefined;
    }
  }

  setModelUrl(url: string) {
    this.resolveModelUrl?.(new URL(url, window.location.href).href);
  }

  toggleDictation() {
    if (this.testing || this.stopping || this.disposed) return;
    if (this.busy) this.release();
    else this.startDictation();
  }

  release() {
    if (!this.held) return;
    this.held = false;
    if (this.preparingModel) return;
    if (this.recognizer) {
      this.stopping = true;
      this.stopAudio();
      this.callbacks.preview(this.text, 'Распознаю…');
      // The worker processes queued audio first, then emits this final result.
      this.recognizer.retrieveFinalResult();
      clearTimeout(this.watchdog);
      this.watchdog = setTimeout(
        () => this.fail('Распознавание не ответило.'),
        10000,
      );
    } else if (this.active) {
      this.cancel();
      this.callbacks.typing(
        '',
        'Подготовка прервана. После загрузки модели нажмите клавишу диктовки снова.',
      );
    }
  }

  cancel() {
    this.generation++;
    this.held = this.active = this.stopping = this.testing = false;
    this.preparingModel = false;
    clearTimeout(this.watchdog);
    this.watchdog = undefined;
    this.stopAudio();
    this.recognizer?.remove();
    this.recognizer = undefined;
    this.callbacks.level?.(0);
  }

  dispose() {
    this.disposed = true;
    this.cancelPreparation();
    this.model?.terminate();
  }

  private get text() {
    return [this.finalText, this.partialText].filter(Boolean).join(' ').trim();
  }

  private loadModel(): Promise<Model> {
    if (this.modelPromise) return this.modelPromise;
    const abort = new AbortController();
    this.modelAbort = abort;
    this.modelPromise = new Promise<string>((resolve, reject) => {
      const timeout = setTimeout(
        () => reject(new Error('Не удалось получить модель с сервера.')),
        120000,
      );
      this.resolveModelUrl = (url) => {
        clearTimeout(timeout);
        resolve(url);
      };
      this.callbacks.preview('', 'Запрашиваю русскую модель у сервера…');
      Byond.sendMessage('speech-model');
      abort.signal.addEventListener(
        'abort',
        () => {
          clearTimeout(timeout);
          reject(new Error('Подготовка отменена.'));
        },
        { once: true },
      );
    })
      .then(async (url) => {
        this.callbacks.preview('', 'Получаю модель с сервера: 44,1 МиБ…');
        // The model's browse_rsc transfer may finish after its URL arrives.
        const deadline = Date.now() + 120000;
        while (!this.disposed && !abort.signal.aborted) {
          try {
            const response = await fetch(url, { signal: abort.signal });
            const bytes = new Uint8Array(await response.arrayBuffer());
            if (
              response.ok &&
              bytes.length > 40000000 &&
              bytes[0] === 31 &&
              bytes[1] === 139
            )
              return url;
          } catch {
            /* Wait for BYOND's resource delivery. */
          }
          if (Date.now() >= deadline)
            throw new Error('Не удалось получить модель с игрового сервера.');
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
        throw new Error('Окно закрыто.');
      })
      .then(
        (url) =>
          new Promise<Model>((resolve, reject) => {
            if (this.disposed || abort.signal.aborted) {
              reject(new Error('Окно закрыто.'));
              return;
            }
            this.callbacks.preview(
              '',
              'Модель получена. Запускаю распознаватель…',
            );
            const model = new Model(url, -1);
            this.model = model;
            abort.signal.addEventListener(
              'abort',
              () => {
                clearTimeout(timeout);
                model.terminate();
                reject(new Error('Подготовка отменена.'));
              },
              { once: true },
            );
            const timeout = setTimeout(() => {
              model.terminate();
              reject(new Error('Истекло время загрузки модели.'));
            }, 120000);
            model.on('load', (message) => {
              clearTimeout(timeout);
              if (message.event === 'load' && message.result) resolve(model);
              else reject(new Error('Модель не загрузилась.'));
            });
            model.on('error', () => {
              clearTimeout(timeout);
              reject(new Error('Ошибка загрузки офлайн-модели.'));
              if (this.active) this.fail('Ошибка офлайн-распознавания.');
            });
          }),
      )
      .catch((error) => {
        if (this.modelAbort === abort) {
          this.model?.terminate();
          this.model = undefined;
          this.modelPromise = undefined;
        }
        throw error;
      });
    return this.modelPromise;
  }

  private async start() {
    this.active = true;
    const generation = ++this.generation;
    this.finalText = this.partialText = '';
    this.pendingChunks = 0;
    this.callbacks.open();
    this.callbacks.preview(
      '',
      this.model?.ready ? 'Подключаю микрофон…' : 'Загружаю офлайн-модель…',
    );
    try {
      // Start audio during the test button's gesture, before downloading the model.
      // Otherwise WebView may leave resume() pending after user activation expires.
      const context = new AudioContext();
      this.context = context;
      void context.resume().catch(() => {});
      this.preparingModel = true;
      const model = await this.loadModel();
      if (generation !== this.generation) return;
      this.preparingModel = false;
      if (!this.held) {
        this.active = this.testing = false;
        this.stopAudio();
        this.callbacks.typing(
          '',
          'Модель готова. Закройте это окно и нажмите клавишу диктовки для диктовки.',
        );
        return;
      }
      if (!navigator.mediaDevices?.getUserMedia)
        throw new Error('Микрофон недоступен в WebView2.');
      let deviceId: string | undefined;
      if (this.microphone) {
        const devices = await navigator.mediaDevices.enumerateDevices();
        deviceId = devices.find(
          (device) =>
            device.kind === 'audioinput' && device.label === this.microphone,
        )?.deviceId;
        if (!deviceId)
          throw new Error(
            'Выбранный микрофон не найден. Обновите список в настройках.',
          );
      }
      if (generation !== this.generation) return;
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          deviceId: deviceId ? { exact: deviceId } : undefined,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true,
        },
        video: false,
      });
      if (generation !== this.generation) {
        for (const track of stream.getTracks()) track.stop();
        return;
      }
      this.stream = stream;
      let resumeTimeout: ReturnType<typeof setTimeout> | undefined;
      try {
        await Promise.race([
          context.resume(),
          new Promise<never>((_, reject) => {
            resumeTimeout = setTimeout(
              () =>
                reject(
                  new Error(
                    'Звук не запустился. Закройте окно и повторите тест записи.',
                  ),
                ),
              8000,
            );
          }),
        ]);
      } finally {
        clearTimeout(resumeTimeout);
      }
      if (generation !== this.generation) return;
      const recognizer = new model.KaldiRecognizer(context.sampleRate);
      this.recognizer = recognizer;
      recognizer.on('result', (message) => {
        if (generation !== this.generation || message.event !== 'result')
          return;
        const final = this.stopping && this.pendingChunks === 0;
        if (this.pendingChunks) this.pendingChunks--;
        this.finalText = [this.finalText, message.result.text]
          .filter(Boolean)
          .join(' ');
        this.partialText = '';
        if (final) {
          const text = this.text;
          const testing = this.testing;
          this.cancel();
          if (testing) this.callbacks.testResult?.(text);
          else if (text) this.callbacks.submit(text);
          else
            this.callbacks.typing(
              '',
              'Речь не распознана. Можно напечатать сообщение.',
            );
        } else
          this.callbacks.preview(
            this.text,
            this.testing
              ? 'Идёт тест записи — говорите (10 секунд)'
              : 'Говорите — повторная клавиша диктовки отправит, Escape отменит',
          );
      });
      recognizer.on('partialresult', (message) => {
        if (generation !== this.generation || message.event !== 'partialresult')
          return;
        if (this.pendingChunks) this.pendingChunks--;
        this.partialText = message.result.partial;
        this.callbacks.preview(
          this.text,
          this.testing
            ? 'Идёт тест записи — говорите (10 секунд)'
            : 'Говорите — повторная клавиша диктовки отправит, Escape отменит',
        );
      });
      recognizer.on('error', () => {
        if (generation === this.generation) this.fail('Ошибка распознавания.');
      });
      this.source = context.createMediaStreamSource(stream);
      // Vosk accepts AudioBuffers; a muted output keeps the processing node alive.
      this.processor = context.createScriptProcessor(4096, 1, 1);
      this.processor.onaudioprocess = (event) => {
        try {
          if (this.callbacks.level) {
            const samples = event.inputBuffer.getChannelData(0);
            let sum = 0;
            for (const sample of samples) sum += sample * sample;
            this.callbacks.level(
              Math.min(1, Math.sqrt(sum / samples.length) * 5),
            );
          }
          this.pendingChunks++;
          recognizer.acceptWaveform(event.inputBuffer);
        } catch {
          this.fail('Не удалось обработать звук.');
        }
      };
      this.source.connect(this.processor);
      this.processor.connect(context.destination);
      this.callbacks.preview(
        '',
        this.testing
          ? 'Идёт тест записи — говорите (10 секунд)'
          : 'Говорите — повторная клавиша диктовки отправит, Escape отменит',
      );
      this.watchdog = setTimeout(
        () =>
          this.testing
            ? this.release()
            : this.fail('Диктовка отменена: превышен лимит записи 30 секунд.'),
        this.testing ? 10000 : 30000,
      );
    } catch (error) {
      if (generation === this.generation) this.fail(microphoneError(error));
    }
  }

  private stopAudio() {
    if (this.processor) this.processor.onaudioprocess = null;
    this.processor?.disconnect();
    this.source?.disconnect();
    for (const track of this.stream?.getTracks() ?? []) track.stop();
    void this.context?.close();
    this.processor = this.source = this.stream = this.context = undefined;
  }

  private fail(message: string) {
    const text = this.text;
    this.cancel();
    this.callbacks.typing(text, message);
  }
}
