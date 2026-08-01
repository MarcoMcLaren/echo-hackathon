// Manual mock for react-native-keychain, covering only what lock.ts uses.

export const ACCESS_CONTROL = {
  BIOMETRY_ANY_OR_DEVICE_PASSCODE: 'BIOMETRY_ANY_OR_DEVICE_PASSCODE',
} as const;

export const ACCESSIBLE = {
  WHEN_UNLOCKED_THIS_DEVICE_ONLY: 'WHEN_UNLOCKED_THIS_DEVICE_ONLY',
} as const;

export const getSupportedBiometryType = jest.fn().mockResolvedValue(null);
export const hasGenericPassword = jest.fn().mockResolvedValue(false);
export const setGenericPassword = jest.fn().mockResolvedValue(true);
export const getGenericPassword = jest.fn().mockResolvedValue(false);
export const resetGenericPassword = jest.fn().mockResolvedValue(true);

export function __reset() {
  getSupportedBiometryType.mockReset().mockResolvedValue(null);
  hasGenericPassword.mockReset().mockResolvedValue(false);
  setGenericPassword.mockReset().mockResolvedValue(true);
  getGenericPassword.mockReset().mockResolvedValue(false);
  resetGenericPassword.mockReset().mockResolvedValue(true);
}
