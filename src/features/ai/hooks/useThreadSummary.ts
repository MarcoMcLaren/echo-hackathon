// "Catch me up" — summarise a backlog with a small model running on this phone.
//
// Nothing leaves the device, which is the whole point: the mesh carries
// ciphertext between phones, so shipping the plaintext to a server to summarise
// it would undo the thing the app is for.
import { useCallback, useEffect, useRef, useState } from 'react';
import { useLLM, QWEN2_5_0_5B_QUANTIZED } from 'react-native-executorch';
import type { Thread } from '../../../store/mock';

/** Shown on the sheet. The claim of "on device" is worth nothing if the UI
 *  doesn't say which model ran and where. */
export const SUMMARY_MODEL = 'Qwen 2.5 0.5B · on this phone';

/** A 0.5B model will happily write an essay. Stop it once it has said enough. */
const MAX_LINES = 4;

/** Keeps the prompt inside a small model's context window. */
const MAX_MESSAGES = 40;

const SYSTEM_PROMPT = [
  'You summarise a group chat backlog for someone who was away.',
  `Reply with at most ${MAX_LINES} short lines.`,
  'Each line is one fact the reader must act on or know.',
  'Prefer times, places, amounts, and who owes what.',
  'End with any question that was asked and never answered.',
  'No greeting, no preamble, no markdown, no bullet characters.',
  'One fact per line, plain sentences.',
].join(' ');

const transcript = (thread: Thread, unread: number) => {
  const recent = thread.messages.slice(-Math.min(unread || MAX_MESSAGES, MAX_MESSAGES));
  return recent
    .map((m) => {
      const who = m.from === 'me' ? 'Me' : m.from;
      const body = m.text ?? `sent ${m.coin?.toFixed(2)} echocoin`;
      return `${who}: ${body}`;
    })
    .join('\n');
};

/** Strip anything the model added despite being told not to. */
export const toLines = (raw: string): string[] =>
  raw
    .split('\n')
    .map((l) => l.replace(/^\s*(?:[-*•]|\d+[.)])\s*/, '').trim())
    .filter((l) => l.length > 1)
    .slice(0, MAX_LINES);

export function useThreadSummary({ enabled }: { enabled: boolean }) {
  // preventLoad keeps the ~400 MB model out of RAM until someone asks for a
  // summary, so opening a chat stays cheap.
  const llm = useLLM({ model: QWEN2_5_0_5B_QUANTIZED, preventLoad: !enabled });

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
          chatConfig: { systemPrompt: SYSTEM_PROMPT },
          // Low temperature: this is extraction, not writing.
          generationConfig: { temperature: 0.3, repetitionPenalty: 1.15 },
        });
        await llm.generate([
          { role: 'user', content: transcript(thread, unread) },
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
