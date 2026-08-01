// "Catch me up" — summarise a backlog with a small model running on this phone.
//
// Nothing leaves the device, which is the whole point: the mesh carries
// ciphertext between phones, so shipping the plaintext to a server to summarise
// it would undo the thing the app is for.
import { useCallback, useEffect, useRef, useState } from 'react';
import { useLLM, QWEN2_5_1_5B_QUANTIZED } from 'react-native-executorch';
import type { Thread } from '../../../store/types';

/** Shown on the sheet. The claim of "on device" is worth nothing if the UI
 *  doesn't say which model ran and where. */
export const SUMMARY_MODEL = 'Qwen 2.5 1.5B · on this phone';

/** A 0.5B model will happily write an essay. Stop it once it has said enough. */
const MAX_LINES = 4;

/** Keeps the prompt inside a small model's context window. */
const MAX_MESSAGES = 40;

const SYSTEM_PROMPT = [
  'You are a summariser, not a participant.',
  'You are shown a transcript of messages someone missed.',
  'You never reply to those messages and you never ask questions of your own.',
].join(' ');

const transcript = (thread: Thread, unread: number) => {
  const recent = thread.messages.slice(-Math.min(unread || MAX_MESSAGES, MAX_MESSAGES));
  return recent
    .map((m) => {
      // `from` is a device id. Naming the sender matters here — a 0.5B model
      // given "f5ofbmm4: come earlier" has to guess what it is even reading.
      const who = m.from === 'me' ? 'Me' : (m.fromName ?? thread.title);
      const body = m.text ?? `sent ${m.coin?.toFixed(2)} echocoin`;
      return `${who}: ${body}`;
    })
    .join('\n');
};

/**
 * The instruction rides with the transcript rather than sitting only in the
 * system prompt. A 0.5B model handed a chat log will carry on the chat — the
 * first version of this answered the last message ("Yes, I am still here to
 * help") instead of summarising anything. Fencing the log and ending on a
 * "Summary:" cue makes the task unambiguous at the point it matters.
 */
const EXAMPLE_IN = [
  'Thabo: Meeting moved to Thursday 9am',
  'Thabo: Room 2 not the boardroom',
  'Me: ok',
  'Thabo: Lerato still owes 300 for the printer',
  'Thabo: Did anyone book the projector',
].join('\n');

const EXAMPLE_OUT = [
  'Meeting is Thursday 9am in Room 2.',
  'Lerato owes 300 for the printer.',
  'Nobody answered whether the projector was booked.',
].join('\n');

const RULES = [
  `Write at most ${MAX_LINES} short lines. One fact per line.`,
  'Copy names, times and amounts exactly as written. Never invent one.',
  'If something was changed later, state only the final version.',
  'If a question was asked and never answered, make it the last line.',
  'Plain sentences only. No greeting, no preamble, no bullets, no markdown.',
  'Do not reply to the messages and do not ask anything yourself.',
].join('\n');

/**
 * One worked example. A 0.5B model will not hold a format from instructions
 * alone — told only in prose to summarise, it kept answering the backlog as a
 * chatbot ("Surely, I can assist with this request") and invented amounts.
 * Showing it one transcript-in / summary-out pair is what actually pins the
 * shape down.
 */
const userPrompt = (thread: Thread, unread: number) =>
  [
    'Summarise a chat transcript for someone who was away.',
    '',
    RULES,
    '',
    'TRANSCRIPT:',
    EXAMPLE_IN,
    'SUMMARY:',
    EXAMPLE_OUT,
    '',
    'TRANSCRIPT:',
    transcript(thread, unread),
    'SUMMARY:',
  ].join('\n');

/** Strip anything the model added despite being told not to. */
export const toLines = (raw: string): string[] =>
  raw
    .split('\n')
    .map((l) =>
      l
        .replace(/^\s*(?:[-*•]|\d+[.)])\s*/, '')
        // A small model reaches for bold headings however firmly you ask it not
        // to; strip the markers rather than show "**Payment**:" on the sheet.
        .replace(/\*\*/g, '')
        .trim()
    )
    // Drop the label if it echoes the prompt's own cue back at us.
    .filter((l) => l.length > 1 && !/^summary:?$/i.test(l))
    .slice(0, MAX_LINES);

export function useThreadSummary({ enabled }: { enabled: boolean }) {
  // preventLoad keeps the ~400 MB model out of RAM until someone asks for a
  // summary, so opening a chat stays cheap.
  const llm = useLLM({ model: QWEN2_5_1_5B_QUANTIZED, preventLoad: !enabled });

  const [failed, setFailed] = useState<string | null>(null);
  const [tookMs, setTookMs] = useState<number | null>(null);
  const [done, setDone] = useState(false);
  const startedAt = useRef(0);
  const capped = useRef(false);

  const lines = toLines(llm.response ?? '');

  // Cut generation off once we have what we asked for.
  useEffect(() => {
    if (!llm.isGenerating || capped.current) return;
    const complete = (llm.response ?? '').split('\n').filter((l) => l.trim().length > 1);
    if (complete.length > MAX_LINES) {
      capped.current = true;
      llm.interrupt();
    }
  }, [llm.response, llm.isGenerating, llm]);

  const summarise = useCallback(
    async (thread: Thread, unread: number) => {
      setFailed(null);
      setDone(false);
      setTookMs(null);
      capped.current = false;
      startedAt.current = Date.now();

      try {
        llm.configure({
          // No systemPrompt here — see below, it does not reach generate().
          // Low temperature: this is extraction, not writing.
          generationConfig: { temperature: 0.1, repetitionPenalty: 1.15 },
        });
        // The system prompt has to ride in the message array. Passing it via
        // configure({ chatConfig }) is silently ignored for an explicit
        // generate([...]) — the library logs "You are not providing system
        // prompt ... otherwise prompt from your model's chat template will be
        // used", and Qwen's default template is a helpful assistant. That is
        // why this used to answer the backlog ("Of course I can help with this
        // request") instead of summarising it.
        await llm.generate([
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userPrompt(thread, unread) },
        ]);
        setTookMs(Date.now() - startedAt.current);
        setDone(true);
      } catch (e) {
        // An interrupt is us stopping it deliberately, not a failure.
        if (capped.current) {
          setTookMs(Date.now() - startedAt.current);
          setDone(true);
          return;
        }
        setFailed(e instanceof Error ? e.message : String(e));
      }
    },
    [llm]
  );

  return {
    lines,
    summarise,
    /** Model is in RAM and can generate. */
    isReady: llm.isReady,
    isGenerating: llm.isGenerating,
    /** 0..1 while the model downloads on first use. */
    downloadProgress: llm.downloadProgress,
    done,
    tookMs,
    error: failed ?? (llm.error ? String(llm.error) : null),
  };
}
