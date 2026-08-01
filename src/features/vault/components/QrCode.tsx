// Pure-JS QR rendering — no react-native-svg, so no new dev-client APK.
// Consecutive dark modules in a row are merged into one View, which takes a
// 33x33 code from ~1000 views down to ~150.
import { useMemo } from 'react';
import { View } from 'react-native';
import qr from 'qrcode-generator';

/**
 * Always rendered dark-on-light, in both themes. The code is a physical thing
 * another phone's camera has to read — inverting it for dark mode would look
 * consistent and scan badly.
 */
export default function QrCode({
  value,
  size = 200,
  quiet = 2,
}: {
  value: string;
  size?: number;
  quiet?: number;
}) {
  const { rows, count } = useMemo(() => {
    const code = qr(0, 'M');
    code.addData(value);
    code.make();
    const n = code.getModuleCount();

    // run-length encode each row into [start, length] spans of dark modules
    const out: { x: number; len: number }[][] = [];
    for (let r = 0; r < n; r++) {
      const spans: { x: number; len: number }[] = [];
      let start = -1;
      for (let cIdx = 0; cIdx < n; cIdx++) {
        const on = code.isDark(r, cIdx);
        if (on && start < 0) start = cIdx;
        if ((!on || cIdx === n - 1) && start >= 0) {
          const end = on && cIdx === n - 1 ? cIdx + 1 : cIdx;
          spans.push({ x: start, len: end - start });
          start = -1;
        }
      }
      out.push(spans);
    }
    return { rows: out, count: n };
  }, [value]);

  const total = count + quiet * 2;
  const m = size / total; // module size in px

  return (
    <View
      style={{
        width: size,
        height: size,
        backgroundColor: '#FFFFFF',
        borderRadius: 8,
        overflow: 'hidden',
      }}
    >
      {rows.map((spans, r) => (
        <View key={r} style={{ position: 'absolute', top: (r + quiet) * m, left: 0, right: 0, height: m }}>
          {spans.map((sp, i) => (
            <View
              key={i}
              style={{
                position: 'absolute',
                left: (sp.x + quiet) * m,
                width: sp.len * m,
                height: m,
                backgroundColor: '#0D1A16',
              }}
            />
          ))}
        </View>
      ))}
    </View>
  );
}
