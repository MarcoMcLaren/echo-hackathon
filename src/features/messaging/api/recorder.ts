// The microphone, and nothing else.
//
// Every `react-native-audio-api` import in the app lives here, so the pure
// helpers in `utils/dictation.ts` and everything above this file stay testable
// under plain node. File output is never enabled: a dictation take is PCM we
// transcribe and throw away, not a voice note we keep.
import { AudioManager, AudioRecorder } from 'react-native-audio-api';
import { BUFFER_LENGTH, MAX_SAMPLES, SAMPLE_RATE, concatChunks } from '../../../utils/dictation';

/**
 * `blocked` means the system dialog will not come back — the only way in is
 * Android Settings, so the UI has to say so instead of asking again.
 */
export type MicPermission = 'granted' | 'denied' | 'blocked';

export type RecorderStart =
  | { status: 'recording' }
  | { status: 'denied'; blocked: boolean }
  | { status: 'failed'; message: string };

export type RecorderEvents = {
  /** The 29 s ceiling landed. The mic is already closed; collect the take. */
  onCeiling?: () => void;
  /** The take died on its own — a call stole the mic, the route changed. */
  onError?: (message: string) => void;
};

/**
 * The library's two permission calls do not share a mapping, which is the whole
 * reason this reads the state twice.
 *
 * `requestRecordingPermissions()` resolves a flat 'Denied' for any refusal
 * (`PermissionRequestListener.kt:28`), so it cannot tell "not now" from "never
 * again". `checkRecordingPermissions()` can: it returns 'Denied' *only* while
 * `shouldShowRequestPermissionRationale` is true — meaning the dialog will come
 * back — and 'Undetermined' for never-asked **or** "Don't ask again"
 * (`MediaSessionManager.kt:121-143`). Having just asked, never-asked is
 * impossible, so 'Undetermined' on the second read means the dialog is gone for
 * good and the user has to be sent to Settings.
 */
async function ensurePermission(): Promise<MicPermission> {
  if ((await AudioManager.checkRecordingPermissions()) === 'Granted') return 'granted';
  if ((await AudioManager.requestRecordingPermissions()) === 'Granted') return 'granted';

  return (await AudioManager.checkRecordingPermissions()) === 'Denied' ? 'denied' : 'blocked';
}

const errText = (e: unknown): string => (e instanceof Error ? e.message : String(e));

/**
 * One hold-to-talk take. Owns its `AudioRecorder` for the length of the take
 * and drops it after, so a phone that never dictates never opens the mic.
 */
export class DictationRecorder {
  private rec: AudioRecorder | null = null;
  private chunks: Float32Array[] = [];
  private samples = 0;
  private events: RecorderEvents = {};

  /** Guards the callback against buffers that arrive while we are tearing down. */
  private capturing = false;

  /**
   * True between claiming audio focus and handing it back. Teardown keys off
   * this rather than off `rec`, because a start that claimed the session and
   * then failed has no recorder to close but is still ducking every other app.
   */
  private session = false;

  /** stop()/abort() can land while start() is still waiting on the permission
   *  dialog. They wait on this, so a take can never outlive its gesture. */
  private starting: Promise<unknown> | null = null;

  /**
   * Which take is live. Teardown queued behind an await belongs to the take
   * that asked for it — a cancel from a take the user already abandoned must do
   * nothing rather than close the microphone they are speaking into now. That
   * misfire costs a real recording and then blames the user for it.
   */
  private epoch = 0;

  isRecording(): boolean {
    return this.capturing;
  }

  start(events: RecorderEvents = {}): Promise<RecorderStart> {
    this.epoch += 1;
    const running = this.begin(events, this.epoch);
    this.starting = running;
    return running;
  }

  /** Ends the take and hands back everything captured. Never throws. */
  async stop(): Promise<Float32Array> {
    // Read before the await, so this stop belongs to the take the caller ended.
    const epoch = this.epoch;
    await this.starting;
    await this.halt(epoch);
    if (epoch !== this.epoch) return new Float32Array(0);

    const waveform = concatChunks(this.chunks);
    this.reset(epoch);
    return waveform;
  }

  /** Ends the take and drops it. Never throws. */
  async abort(): Promise<void> {
    const epoch = this.epoch;
    await this.starting;
    await this.halt(epoch);
    this.reset(epoch);
  }

  private async begin(events: RecorderEvents, epoch: number): Promise<RecorderStart> {
    if (this.capturing) return { status: 'recording' };

    try {
      const permission = await ensurePermission();
      if (permission !== 'granted') {
        return { status: 'denied', blocked: permission === 'blocked' };
      }

      this.reset(epoch);
      this.events = events;

      const rec = new AudioRecorder();
      // Errors are returned here, not thrown — an unchecked Result is a mic
      // that looks live and delivers silence.
      const attached = rec.onAudioReady(
        { sampleRate: SAMPLE_RATE, bufferLength: BUFFER_LENGTH, channelCount: 1 },
        (event) => this.take(event.buffer.getChannelData(0), event.buffer.sampleRate)
      );
      if (attached.status === 'error') {
        rec.clearOnAudioReady();
        return { status: 'failed', message: attached.message };
      }

      rec.onError((e) => {
        this.events.onError?.(e.message);
        void this.abort();
      });

      // Rejects rather than returning a Result. Failing to claim the session is
      // not fatal on Android, so it must not take the take down with it.
      try {
        await AudioManager.setAudioSessionActivity(true);
        this.session = true;
      } catch {
        // The recorder itself reports anything that actually blocks recording.
      }

      // Published before start() resolves, not after. A rejected start can
      // still leave a live native recorder behind, and holding the handle back
      // until success would strand the microphone with nothing able to close it.
      this.rec = rec;
      this.capturing = true;

      const started = await rec.start();
      if (started.status === 'error') {
        await this.halt(epoch);
        return { status: 'failed', message: started.message };
      }
      return { status: 'recording' };
    } catch (e) {
      // Covers the throwing calls above — halt() is what hands back audio focus
      // we may already have claimed.
      await this.halt(epoch);
      return { status: 'failed', message: errText(e) };
    }
  }

  private take(frame: Float32Array, rate: number): void {
    if (!this.capturing || this.samples >= MAX_SAMPLES) return;

    // The rate handed to onAudioReady is a preference; the device picks the real
    // one. Whisper does not resample, and MIN/MAX_SAMPLES count 16 kHz frames,
    // so anything else transcribes as a chipmunk against bounds that are wrong
    // by the same factor. A plausible-looking wrong transcript is worse than an
    // error, so fail the take and say why.
    if (rate !== SAMPLE_RATE) {
      // Stop counting immediately: every following buffer arrives at the same
      // wrong rate and would report the same failure again.
      this.capturing = false;

      const epoch = this.epoch;
      const message = `This phone recorded at ${Math.round(rate)} Hz, not ${SAMPLE_RATE} Hz`;
      void this.halt(epoch).then(() => {
        this.reset(epoch);
        this.events.onError?.(message);
      });
      return;
    }

    // The native buffer is recycled between callbacks, so holding the view
    // would leave us with whatever was recorded last, repeated. slice() copies.
    this.chunks.push(frame.slice());
    this.samples += frame.length;
    if (this.samples < MAX_SAMPLES) return;

    // Whisper cannot see past 29 s, so holding the mic open past it only costs
    // battery. Close it here and let the owner collect what we have.
    const epoch = this.epoch;
    void this.halt(epoch).then(() => this.events.onCeiling?.());
  }

  private async halt(epoch: number): Promise<void> {
    // A teardown belonging to a take that has already been replaced would close
    // the microphone the user is speaking into right now.
    if (epoch !== this.epoch) return;

    const rec = this.rec;
    this.rec = null;

    // `capturing` deliberately stays true across stop(): the native side hands
    // over one last partial buffer as it winds down, and clearing the callback
    // first clips the tail of the final word.
    const stopped = rec ? await rec.stop() : null;
    this.capturing = false;

    if (rec) {
      rec.clearOnAudioReady();
      rec.clearOnError();
      // A failed teardown is not a failed take: every sample already arrived
      // through onAudioReady, so there is nothing left to lose here.
      if (stopped?.status === 'error') this.events.onError?.(stopped.message);
    }

    // Outside the `rec` branch on purpose. This is the path a failed start takes
    // too, and never handing audio focus back leaves every other app ducked for
    // the life of the process.
    if (this.session) {
      this.session = false;
      try {
        await AudioManager.setAudioSessionActivity(false);
      } catch {
        // Handing the session back is a courtesy to other apps, not a result.
      }
    }
  }

  private reset(epoch: number): void {
    if (epoch !== this.epoch) return;
    this.chunks = [];
    this.samples = 0;
  }
}
