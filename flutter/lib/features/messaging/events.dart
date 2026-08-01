// Calendar events as messages. Ported from src/features/messaging/api/events.ts.
//
// An event sent over the mesh is just structured text — small, so it never
// needs chunking. Saving it to the phone's own calendar is a separate,
// deliberate act, because writing to someone's calendar is not something a
// received message should do on its own.
import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
// timezone is a transitive dependency (device_calendar depends on it) rather
// than one this app declares directly — adding it to pubspec.yaml is out of
// scope here, so the lint that would ask for that is suppressed.
// ignore: depend_on_referenced_packages
import 'package:timezone/timezone.dart' as tz;

class MeshEvent {
  final String title;
  /// Epoch ms. Sent as a number so both builds agree without parsing dates.
  final int startsAt;
  /// Defaults to an hour after the start when absent.
  final int? endsAt;
  final String? location;

  const MeshEvent({required this.title, required this.startsAt, this.endsAt, this.location});

  Map<String, dynamic> toJson() => {
        'title': title,
        'startsAt': startsAt,
        if (endsAt != null) 'endsAt': endsAt,
        if (location != null) 'location': location,
      };
}

const _hour = 60 * 60 * 1000;

String encodeEvent(MeshEvent e) => jsonEncode(e.toJson());

/// Never throws — a malformed event from another build must not break a thread.
MeshEvent? decodeEvent(String body) {
  try {
    final e = jsonDecode(body);
    if (e is! Map || e['title'] is! String || e['startsAt'] is! num) return null;
    return MeshEvent(
      title: e['title'] as String,
      startsAt: (e['startsAt'] as num).toInt(),
      endsAt: e['endsAt'] is num ? (e['endsAt'] as num).toInt() : null,
      location: e['location'] is String ? e['location'] as String : null,
    );
  } catch (_) {
    return null;
  }
}

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Short date/time string, shaped like RN's `en-ZA` locale format
/// (`{weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit',
/// minute: '2-digit', hour12: false}` → e.g. "Sat, 2 Aug, 14:00"). Hand-built
/// rather than pulling in `intl` for one string — `intl` is only a transitive
/// dependency here (via other plugins), not one this app already imports.
String formatWhen(MeshEvent e) {
  final d = DateTime.fromMillisecondsSinceEpoch(e.startsAt);
  final wd = _weekdayShort[d.weekday - 1];
  final mo = _monthShort[d.month - 1];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$wd, ${d.day} $mo, $hh:$mm';
}

class SaveOutcome {
  final bool ok;
  final String? reason; // 'denied' | 'no-calendar' | 'error', when !ok
  final String? message;
  const SaveOutcome._(this.ok, {this.reason, this.message});

  factory SaveOutcome.success() => const SaveOutcome._(true, message: 'Added to your calendar');

  factory SaveOutcome.failure(String reason, {String? message}) =>
      SaveOutcome._(false, reason: reason, message: message);
}

/// The calendar Android will actually let us write to.
Future<Calendar?> _writableCalendar(DeviceCalendarPlugin plugin) async {
  final result = await plugin.retrieveCalendars();
  final calendars = result.data;
  if (calendars == null) return null;
  for (final calendar in calendars) {
    if (calendar.isReadOnly != true) return calendar;
  }
  return null;
}

/// Save to the device calendar. Asks for permission at the moment of use.
Future<SaveOutcome> saveToCalendar(MeshEvent e) async {
  try {
    final plugin = DeviceCalendarPlugin();

    var permission = await plugin.hasPermissions();
    if (permission.data != true) {
      permission = await plugin.requestPermissions();
    }
    if (permission.data != true) {
      return SaveOutcome.failure('denied', message: 'Echo needs calendar permission to add it');
    }

    final calendar = await _writableCalendar(plugin);
    final calendarId = calendar?.id;
    if (calendarId == null) {
      return SaveOutcome.failure('no-calendar', message: 'No calendar on this phone can be written to');
    }

    // device_calendar needs an explicit, non-null TZDateTime location or
    // Android rejects the event outright (same note RN's Intl-based timeZone
    // makes). There is no device-timezone-name plugin in this app's
    // dependencies (that would mean a new native dep), so — per the
    // package's own README guidance for exactly this case — we tag the event
    // with the UTC location instead. `TZDateTime.from` preserves the actual
    // instant regardless of which location it's tagged with, and Android's
    // calendar always renders dtstart/dtend (absolute instants) converted to
    // the device's current zone, so the event still shows at the right
    // wall-clock time; only the (cosmetic) stored zone id differs from RN's.
    final start = tz.TZDateTime.from(DateTime.fromMillisecondsSinceEpoch(e.startsAt), tz.UTC);
    final end = tz.TZDateTime.from(DateTime.fromMillisecondsSinceEpoch(e.endsAt ?? e.startsAt + _hour), tz.UTC);

    final event = Event(
      calendarId,
      title: e.title,
      start: start,
      end: end,
      location: e.location,
      description: 'Shared over Echo',
    );

    final createResult = await plugin.createOrUpdateEvent(event);
    if (createResult?.isSuccess == true) return SaveOutcome.success();
    return SaveOutcome.failure('error', message: 'Could not add it to the calendar');
  } catch (err) {
    return SaveOutcome.failure('error', message: 'Could not add it to the calendar');
  }
}
