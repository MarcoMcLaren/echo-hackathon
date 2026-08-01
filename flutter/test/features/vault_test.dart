import 'package:flutter_test/flutter_test.dart';

import 'package:echo/features/vault/vault.dart';

void main() {
  group('MockSecureVault', () {
    test('starts locked and unlocks after setUp', () async {
      final vault = MockSecureVault();
      expect(await vault.status(), VaultStatus.locked);

      final publicKey = await vault.setUp();
      expect(publicKey, isNotEmpty);
      expect(await vault.status(), VaultStatus.unlocked);
    });

    test('encrypt before setUp throws', () async {
      final vault = MockSecureVault();
      expect(
        () => vault.encrypt('hi', recipientPublicKey: 'pk'),
        throwsStateError,
      );
    });

    test('round-trips a message addressed to the recipient', () async {
      final sender = MockSecureVault();
      await sender.setUp();
      final recipient = MockSecureVault();
      final recipientKey = await recipient.setUp();

      final sealed = await sender.encrypt(
        'meet at the gate',
        recipientPublicKey: recipientKey,
      );
      expect(
        sealed.ciphertext,
        isNot(contains('meet at the gate')),
      ); // opaque to relays

      final plaintext = await recipient.decrypt(sealed);
      expect(plaintext, 'meet at the gate');
    });

    test('refuses to decrypt a payload addressed to someone else', () async {
      final sender = MockSecureVault();
      await sender.setUp();
      final recipient = MockSecureVault();
      await recipient.setUp();
      final eavesdropper = MockSecureVault();
      await eavesdropper.setUp();

      final sealed = await sender.encrypt(
        'secret',
        recipientPublicKey: await recipient.setUp(),
      );
      expect(await eavesdropper.decrypt(sealed), isNull);
    });

    test('never throws on a malformed ciphertext', () async {
      final vault = MockSecureVault();
      await vault.setUp();
      final garbage = SealedPayload(
        ciphertext: 'not-base64!!',
        senderPublicKey: 'x',
      );
      expect(await vault.decrypt(garbage), isNull);
    });
  });
}
