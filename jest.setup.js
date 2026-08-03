// Pin the platform so tests behave the same on every machine/CI runner,
// regardless of jest-expo's default. Most store/transport tests care about
// the Nearby/relay logic, not Android's runtime-permission dance.
import { Platform } from 'react-native';
Platform.OS = 'ios';
