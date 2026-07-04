/// Helpers for telling the user when Gemini's free-tier daily quota resets.
///
/// Google's Gemini API free tier resets daily at midnight Pacific Time.
/// We don't pull in a full timezone database just for this, so the
/// Pacific Daylight/Standard Time switch below is a reasonable approximation
/// (actual US DST transitions happen on the second Sunday of March and the
/// first Sunday of November) — it's accurate to within a day around those
/// two transition dates, which is fine for a "come back around this time"
/// message.
library;

String quotaResetTimeLabel() {
  final nowUtc = DateTime.now().toUtc();
  final pacificOffsetHours = _isPacificDaylightTime(nowUtc) ? -7 : -8;

  final pacificNow = nowUtc.add(Duration(hours: pacificOffsetHours));
  final pacificMidnightToday =
      DateTime.utc(pacificNow.year, pacificNow.month, pacificNow.day);
  var nextResetUtc =
      pacificMidnightToday.subtract(Duration(hours: pacificOffsetHours));

  if (!nextResetUtc.isAfter(nowUtc)) {
    nextResetUtc = nextResetUtc.add(const Duration(days: 1));
  }

  final localReset = nextResetUtc.toLocal();
  final now = DateTime.now();
  final isToday = localReset.year == now.year &&
      localReset.month == now.month &&
      localReset.day == now.day;

  final hour12 = localReset.hour % 12 == 0 ? 12 : localReset.hour % 12;
  final minute = localReset.minute.toString().padLeft(2, '0');
  final amPm = localReset.hour >= 12 ? 'PM' : 'AM';
  final dayLabel = isToday ? 'today' : 'tomorrow';

  return '$hour12:$minute $amPm $dayLabel';
}

bool _isPacificDaylightTime(DateTime utcNow) {
  final month = utcNow.month;
  if (month > 3 && month < 11) return true;
  if (month == 3 && utcNow.day >= 8) return true;
  return false;
}