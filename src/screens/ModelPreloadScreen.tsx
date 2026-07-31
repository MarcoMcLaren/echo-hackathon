// First-run screen: pre-download the on-device AI models over wifi so the app
// runs fully offline afterward. Vision models auto-download (small); the LLM is
// opt-in (large). This is also our proof that the ExecuTorch fetch pipeline works.
import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  VISION_MODELS,
  LANGUAGE_MODEL,
  downloadGroup,
  type ModelGroup,
} from '../services/models';

type Status = 'idle' | 'downloading' | 'ready' | 'error';

function GroupRow({ group, auto }: { group: ModelGroup; auto: boolean }) {
  const [status, setStatus] = useState<Status>('idle');
  const [progress, setProgress] = useState(0);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const start = useCallback(async () => {
    setStatus('downloading');
    setProgress(0);
    setErrorMsg(null);
    try {
      await downloadGroup(group, setProgress);
      setStatus('ready');
    } catch (e) {
      setErrorMsg(e instanceof Error ? e.message : String(e));
      setStatus('error');
    }
  }, [group]);

  useEffect(() => {
    if (auto) start();
  }, [auto, start]);

  return (
    <View style={styles.row}>
      <View style={styles.rowHead}>
        <Text style={styles.rowLabel}>{group.label}</Text>
        <Text style={styles.rowSize}>{group.sizeLabel}</Text>
      </View>
      {status === 'idle' && (
        <Pressable style={styles.btn} onPress={start}>
          <Text style={styles.btnText}>Download</Text>
        </Pressable>
      )}
      {status === 'downloading' && (
        <View style={styles.progressRow}>
          <ActivityIndicator />
          <Text style={styles.progressText}>{Math.round(progress * 100)}%</Text>
        </View>
      )}
      {status === 'ready' && <Text style={styles.ready}>✓ Ready — offline</Text>}
      {status === 'error' && (
        <View>
          <Text style={styles.error}>Failed: {errorMsg}</Text>
          <Pressable style={styles.btn} onPress={start}>
            <Text style={styles.btnText}>Retry</Text>
          </Pressable>
        </View>
      )}
    </View>
  );
}

export default function ModelPreloadScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Echo</Text>
      <Text style={styles.subtitle}>Preload AI models</Text>
      <Text style={styles.note}>
        Models download from Hugging Face on first use, then run 100% offline. Do
        this once on wifi before an offline demo.
      </Text>
      <GroupRow group={VISION_MODELS} auto={true} />
      <GroupRow group={LANGUAGE_MODEL} auto={false} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    paddingHorizontal: 24,
    paddingTop: 96,
  },
  title: { fontSize: 40, fontWeight: '700' },
  subtitle: { marginTop: 4, fontSize: 16, color: '#333' },
  note: { marginTop: 12, marginBottom: 24, fontSize: 13, color: '#666', lineHeight: 18 },
  row: {
    borderWidth: 1,
    borderColor: '#e2e2e2',
    borderRadius: 12,
    padding: 16,
    marginBottom: 14,
  },
  rowHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  rowLabel: { flex: 1, fontSize: 15, fontWeight: '600' },
  rowSize: { fontSize: 13, color: '#888', marginLeft: 8 },
  btn: {
    marginTop: 12,
    alignSelf: 'flex-start',
    backgroundColor: '#2b6cff',
    paddingHorizontal: 18,
    paddingVertical: 9,
    borderRadius: 8,
  },
  btnText: { color: '#fff', fontWeight: '600' },
  progressRow: { flexDirection: 'row', alignItems: 'center', marginTop: 12 },
  progressText: { marginLeft: 10, fontSize: 14, color: '#333' },
  ready: { marginTop: 12, color: '#137a2b', fontWeight: '600' },
  error: { marginTop: 12, color: '#c0392b' },
});
