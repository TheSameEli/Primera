export class MicrophoneMonitor {
  private generation = 0;
  private stream?: MediaStream;
  private context?: AudioContext;
  private source?: MediaStreamAudioSourceNode;
  private frame?: number;

  constructor(private update: (percent: number, decibels: number) => void) {}

  async start(name: string) {
    this.stop();
    const generation = this.generation;
    let deviceId: string | undefined;
    if (name) {
      const devices = await navigator.mediaDevices.enumerateDevices();
      if (generation !== this.generation) return;
      deviceId = devices.find(
        (device) => device.kind === 'audioinput' && device.label === name,
      )?.deviceId;
      if (!deviceId)
        throw new Error(
          'Выбранный микрофон не найден. Выберите системный или обновите список.',
        );
    }
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: {
        deviceId: deviceId ? { exact: deviceId } : undefined,
        channelCount: 1,
      },
      video: false,
    });
    if (generation !== this.generation) {
      for (const track of stream.getTracks()) track.stop();
      return;
    }
    this.stream = stream;
    const context = new AudioContext();
    this.context = context;
    await context.resume();
    if (generation !== this.generation) return;
    const analyser = context.createAnalyser();
    analyser.fftSize = 2048;
    this.source = context.createMediaStreamSource(stream);
    this.source.connect(analyser);
    const samples = new Float32Array(analyser.fftSize);
    let previous = -Infinity;
    const tick = (time: number) => {
      if (generation !== this.generation) return;
      if (time - previous >= 40) {
        previous = time;
        analyser.getFloatTimeDomainData(samples);
        let sum = 0;
        for (const value of samples) sum += value * value;
        const db = Math.max(
          -100,
          20 * Math.log10(Math.sqrt(sum / samples.length) || 0.00001),
        );
        this.update(Math.max(0, Math.min(100, ((db + 60) / 60) * 100)), db);
      }
      this.frame = requestAnimationFrame(tick);
    };
    this.frame = requestAnimationFrame(tick);
  }

  stop() {
    this.generation++;
    if (this.frame !== undefined) cancelAnimationFrame(this.frame);
    this.frame = undefined;
    this.source?.disconnect();
    for (const track of this.stream?.getTracks() ?? []) track.stop();
    void this.context?.close();
    this.source = this.stream = this.context = undefined;
  }
}
