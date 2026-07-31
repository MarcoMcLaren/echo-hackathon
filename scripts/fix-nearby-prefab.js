// Restores `fix-prefab.gradle` for expo-nearby-connections@1.1.0.
//
// That version's android/build.gradle does `apply from: './fix-prefab.gradle'`,
// but the file was NOT included in the published npm tarball (packaging bug).
// Without it the Android build fails:
//   "Could not read script '.../fix-prefab.gradle' as it does not exist"
// which also cascades into ":expo > SoftwareComponent 'release' not found".
//
// This postinstall copies the file (vendored at scripts/nearby-fix-prefab.gradle,
// taken verbatim from the library's GitHub repo) back into node_modules.
// Idempotent; safe no-op if the package isn't installed. Remove once upstream
// ships the file.
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, 'nearby-fix-prefab.gradle');
const destDir = path.join(
  __dirname,
  '..',
  'node_modules',
  'expo-nearby-connections',
  'android'
);
const dest = path.join(destDir, 'fix-prefab.gradle');

if (!fs.existsSync(destDir)) {
  // expo-nearby-connections not installed — nothing to fix.
  process.exit(0);
}
try {
  fs.copyFileSync(src, dest);
  console.log('[fix-nearby-prefab] restored expo-nearby-connections/android/fix-prefab.gradle');
} catch (e) {
  console.warn('[fix-nearby-prefab] skipped:', e.message);
}
