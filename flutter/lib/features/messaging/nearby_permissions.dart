// Runtime permission gate for [NearbyTransport].
//
// Port intent of ensurePermissions() in
// src/features/messaging/api/transport.ts: everything Nearby Connections
// needs granted before the radio is touched, requested together rather than
// piecemeal so a demo doesn't stall on a second prompt mid-handshake.
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Every permission Nearby needs on a modern Android build. permission_handler
/// already treats a permission the running SDK predates (e.g.
/// nearbyWifiDevices below API 33) as granted, so this list is safe to
/// request unconditionally rather than branching on `Platform.version` the
/// way the RN transport does.
const List<Permission> nearbyPermissions = [
  Permission.bluetoothScan,
  Permission.bluetoothAdvertise,
  Permission.bluetoothConnect,
  Permission.locationWhenInUse,
  Permission.nearbyWifiDevices,
];

class NearbyPermissionResult {
  const NearbyPermissionResult({required this.ok, this.missing = const []});

  final bool ok;
  final List<Permission> missing;
}

/// Requests every permission [NearbyTransport.start] needs. A no-op success
/// off Android, since this transport is Android-only.
Future<NearbyPermissionResult> ensureNearbyPermissions() async {
  if (!Platform.isAndroid) return const NearbyPermissionResult(ok: true);

  final statuses = await nearbyPermissions.request();
  final missing = [
    for (final p in nearbyPermissions)
      if (statuses[p] != PermissionStatus.granted) p,
  ];
  return NearbyPermissionResult(ok: missing.isEmpty, missing: missing);
}
