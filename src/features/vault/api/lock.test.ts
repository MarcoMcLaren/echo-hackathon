import * as Keychain from 'react-native-keychain';
import {
  enableLock,
  forgetLock,
  hasBiometricHardware,
  isLockEnabled,
  unlock,
} from './lock';

const keychain = Keychain as unknown as {
  getSupportedBiometryType: jest.Mock;
  hasGenericPassword: jest.Mock;
  setGenericPassword: jest.Mock;
  getGenericPassword: jest.Mock;
  resetGenericPassword: jest.Mock;
  __reset: () => void;
};

beforeEach(() => {
  keychain.__reset();
});

describe('hasBiometricHardware', () => {
  it('is true when the device reports a supported biometry type', async () => {
    keychain.getSupportedBiometryType.mockResolvedValue('FaceID');
    expect(await hasBiometricHardware()).toBe(true);
  });

  it('is false when there is no biometry type', async () => {
    keychain.getSupportedBiometryType.mockResolvedValue(null);
    expect(await hasBiometricHardware()).toBe(false);
  });

  it('is false if the check throws rather than propagating the error', async () => {
    keychain.getSupportedBiometryType.mockRejectedValue(new Error('boom'));
    expect(await hasBiometricHardware()).toBe(false);
  });
});

describe('isLockEnabled', () => {
  it('reflects whether a lock secret is already stored', async () => {
    keychain.hasGenericPassword.mockResolvedValue(true);
    expect(await isLockEnabled()).toBe(true);
  });

  it('is false if the check throws', async () => {
    keychain.hasGenericPassword.mockRejectedValue(new Error('boom'));
    expect(await isLockEnabled()).toBe(false);
  });
});

describe('enableLock', () => {
  it('succeeds when the Keystore accepts the guarded secret', async () => {
    keychain.setGenericPassword.mockResolvedValue(true);
    expect(await enableLock()).toEqual({ ok: true });
  });

  it('reports "cancelled" when the user backs out of the prompt', async () => {
    keychain.setGenericPassword.mockRejectedValue(new Error('User cancelled the operation'));
    expect(await enableLock()).toEqual({ ok: false, reason: 'cancelled' });
  });

  it('reports "cancelled" for Android error code 13 (also a user cancel)', async () => {
    keychain.setGenericPassword.mockRejectedValue(new Error('code: 13'));
    expect(await enableLock()).toEqual({ ok: false, reason: 'cancelled' });
  });

  it('reports "error" with the message for anything else', async () => {
    keychain.setGenericPassword.mockRejectedValue(new Error('Keystore unavailable'));
    expect(await enableLock()).toEqual({
      ok: false,
      reason: 'error',
      message: 'Keystore unavailable',
    });
  });
});

describe('unlock', () => {
  it('succeeds when the stored secret is retrieved', async () => {
    keychain.getGenericPassword.mockResolvedValue({ username: 'echo', password: 'unlocked' });
    expect(await unlock()).toEqual({ ok: true });
  });

  it('reports "cancelled" when nothing is retrieved (no throw)', async () => {
    keychain.getGenericPassword.mockResolvedValue(false);
    expect(await unlock()).toEqual({ ok: false, reason: 'cancelled' });
  });

  it('reports "cancelled" when the user backs out of the biometric prompt', async () => {
    keychain.getGenericPassword.mockRejectedValue(new Error('User cancelled the operation'));
    expect(await unlock()).toEqual({ ok: false, reason: 'cancelled' });
  });

  it('reports "error" with the message for anything else', async () => {
    keychain.getGenericPassword.mockRejectedValue(new Error('Sensor failure'));
    expect(await unlock()).toEqual({ ok: false, reason: 'error', message: 'Sensor failure' });
  });
});

describe('forgetLock', () => {
  it('resets the stored secret', async () => {
    await forgetLock();
    expect(keychain.resetGenericPassword).toHaveBeenCalled();
  });

  it('never throws, even if there was nothing stored', async () => {
    keychain.resetGenericPassword.mockRejectedValue(new Error('nothing to reset'));
    await expect(forgetLock()).resolves.toBeUndefined();
  });
});
