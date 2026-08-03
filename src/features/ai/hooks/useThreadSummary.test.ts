// Covers only `toLines`, the pure parser that turns the LLM's raw text
// response into the bullet lines the "catch me up" sheet displays. Actually
// driving the hook (model loading/generation) needs a physical device.
import { toLines } from './useThreadSummary';

describe('toLines', () => {
  it('splits on newlines and trims whitespace', () => {
    expect(toLines('First fact.\nSecond fact.  \n  Third fact.')).toEqual([
      'First fact.',
      'Second fact.',
      'Third fact.',
    ]);
  });

  it('strips leading bullet characters and a dotted numbered-list marker', () => {
    expect(toLines('- First\n* Second\n• Third\n1. Fourth')).toEqual([
      'First',
      'Second',
      'Third',
      'Fourth',
    ]);
  });

  it('strips a parenthesised numbered-list marker', () => {
    expect(toLines('2) Fifth')).toEqual(['Fifth']);
  });

  it('drops blank or near-empty lines', () => {
    expect(toLines('First fact.\n\n \n-\nSecond fact.')).toEqual(['First fact.', 'Second fact.']);
  });

  it('caps output at MAX_LINES (4) even when the model rambles', () => {
    const raw = ['One', 'Two', 'Three', 'Four', 'Five', 'Six'].join('\n');
    expect(toLines(raw)).toEqual(['One', 'Two', 'Three', 'Four']);
  });

  it('returns an empty array for an empty response', () => {
    expect(toLines('')).toEqual([]);
  });
});
