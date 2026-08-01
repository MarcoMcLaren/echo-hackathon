// Makes react-native-audio-api's `downloadPrebuiltBinaries` task work on Windows.
//
// The task shells out to a bash script to fetch prebuilt native libs:
//   commandLine 'C:\Program Files\Git\usr\bin\bash.exe', '../scripts/download-prebuilt-binaries.sh', ...
// Invoking that bash.exe DIRECTLY (rather than through git-bash.exe) skips the
// MSYS profile, so /usr/bin never lands on PATH. The script's `mkdir -p` for its
// temp dir then fails silently, every `curl -o` into that missing dir dies with
// "(23) client returned ERROR on write", and the task exits 127 on
// "rm: command not found". Net effect: common/cpp/audioapi/external/android is
// never populated and the Android build fails at :react-native-audio-api:preBuild.
//
// Upstream: software-mansion/react-native-audio-api#1012 (closed, no fix shipped).
//
// The fix wraps the call in `bash -c` and exports PATH inside the shell itself.
// Setting it through Gradle's `environment` does NOT work: on Windows the task's
// environment map is seeded from System.getenv(), whose key is `Path`, so adding
// `PATH` just leaves two entries and the child keeps the original.
//
// Idempotent (guarded by a sentinel), no-op if the package or the expected line
// is absent. Remove once upstream ships a fix.
const fs = require('fs');
const path = require('path');

const SENTINEL = 'echo-fix: export PATH inside the shell';
const STALE = [
  'echo-fix: MSYS coreutils on PATH',
  "download script's mkdir/rm/unzip resolve to nothing",
  "environment 'PATH'",
];

const gradle = path.join(
  __dirname,
  '..',
  'node_modules',
  'react-native-audio-api',
  'android',
  'build.gradle'
);

if (!fs.existsSync(gradle)) {
  // react-native-audio-api not installed — nothing to fix.
  process.exit(0);
}

try {
  const before = fs.readFileSync(gradle, 'utf8');

  if (before.includes(SENTINEL)) {
    process.exit(0);
  }

  // Drop the first attempt at this fix (a Gradle `environment 'PATH'` line) so
  // upgrading from it does not leave a dead line behind.
  const lines = before
    .split(/\r?\n/)
    .filter((line) => !STALE.some((stale) => line.includes(stale)));

  // Match the Windows branch's invocation by content rather than by regex —
  // the hardcoded path is a thicket of backslashes in any pattern.
  const at = lines.findIndex(
    (line) =>
      line.includes('commandLine') &&
      line.includes('bash.exe') &&
      line.includes('download-prebuilt-binaries.sh')
  );

  if (at === -1) {
    console.warn(
      '[fix-audio-api-bash-path] skipped: expected bash.exe commandLine not found (upstream may have fixed this)'
    );
    process.exit(0);
  }

  const indent = lines[at].match(/^[ \t]*/)[0];
  const bash = lines[at].slice(
    lines[at].indexOf("'"),
    lines[at].indexOf("'", lines[at].indexOf("'") + 1) + 1
  );

  // Keep the script's own ffmpeg argument logic; only the shell changes.
  lines.splice(
    at,
    1,
    `${indent}// ${SENTINEL} — bash.exe launched directly has no /usr/bin, so`,
    `${indent}// the script's mkdir/rm/unzip resolve to nothing and it exits 127.`,
    `${indent}commandLine ${bash}, '-c', 'export PATH=/usr/bin:$PATH; ` +
      `exec bash ../scripts/download-prebuilt-binaries.sh android ' + ` +
      `(isFFmpegDisabled() ? 'skipffmpeg' : '')`
  );

  fs.writeFileSync(gradle, lines.join('\n'), 'utf8');
  console.log(
    '[fix-audio-api-bash-path] patched react-native-audio-api/android/build.gradle'
  );
} catch (e) {
  console.warn('[fix-audio-api-bash-path] skipped:', e.message);
}
