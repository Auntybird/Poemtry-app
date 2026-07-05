import 'dart:convert';

import 'quota_reset.dart';

/// Thrown when Gemini returns HTTP 429, carrying the raw response body so
/// callers can inspect *why* (per-minute burst vs daily quota) instead of
/// just knowing "it was rate limited."
class GeminiRateLimitException implements Exception {
  final String responseBody;
  const GeminiRateLimitException(this.responseBody);

  @override
  String toString() => 'Rate Limit';
}

/// Thrown when Gemini returns HTTP 503, meaning the model is temporarily
/// overloaded on Google's side — unrelated to the caller's quota or key.
class GeminiOverloadedException implements Exception {
  const GeminiOverloadedException();
  @override
  String toString() => 'Model Overloaded';
}

class RateLimitInfo {
  /// Exact wait time Google suggests, when it tells us (usually only for
  /// short per-minute/per-second limits, not daily quota exhaustion).
  final Duration? retryDelay;

  /// True if the violation we found looks like a per-day quota rather than
  /// a short per-minute/per-second burst limit.
  final bool isDailyQuota;

  const RateLimitInfo({this.retryDelay, required this.isDailyQuota});
}

/// Best-effort parse of a Gemini 429 error body. Falls back to assuming a
/// daily quota hit if the body doesn't parse or doesn't contain the fields
/// we're looking for — that's the safer default since it's the far more
/// common cause of a *sustained* rate limit for free-tier keys.
RateLimitInfo parseRateLimitInfo(String responseBody) {
  try {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final error = data['error'] as Map<String, dynamic>?;
    final details = (error?['details'] as List<dynamic>?) ?? const [];

    Duration? retryDelay;
    bool isDaily = false;
    bool sawQuotaFailure = false;

    for (final entry in details) {
      final detail = entry as Map<String, dynamic>;
      final type = (detail['@type'] as String?) ?? '';

      if (type.contains('RetryInfo')) {
        final delayStr = detail['retryDelay'] as String?; // e.g. "34s"
        if (delayStr != null) {
          final seconds =
              int.tryParse(delayStr.replaceAll(RegExp(r'[^0-9]'), ''));
          if (seconds != null) retryDelay = Duration(seconds: seconds);
        }
      }

      if (type.contains('QuotaFailure')) {
        sawQuotaFailure = true;
        final violations = (detail['violations'] as List<dynamic>?) ?? const [];
        for (final v in violations) {
          final quotaId = ((v['quotaId'] as String?) ?? '').toLowerCase();
          if (quotaId.contains('perday')) {
            isDaily = true;
          }
        }
      }
    }

    // If we saw a QuotaFailure but couldn't confirm it's "PerDay", and there's
    // no short retryDelay either, assume daily — a bare rate limit with no
    // quick retry hint is almost always the daily cap for free-tier keys.
    if (sawQuotaFailure && !isDaily && retryDelay == null) {
      isDaily = true;
    }

    return RateLimitInfo(retryDelay: retryDelay, isDailyQuota: isDaily);
  } catch (_) {
    return const RateLimitInfo(isDailyQuota: true);
  }
}

/// Builds the user-facing message from parsed rate limit info.
String formatRateLimitMessage(RateLimitInfo info) {
  if (!info.isDailyQuota && info.retryDelay != null) {
    final secs = info.retryDelay!.inSeconds;
    final unit = secs == 1 ? 'second' : 'seconds';
    return 'The AI hit a brief rate limit. Try again in about $secs $unit.';
  }

  if (!info.isDailyQuota) {
    return 'The AI hit a brief rate limit. Please wait a moment and try again.';
  }

  return 'The AI is exhausted for the day (Rate Limit). Quota resets around '
      '${quotaResetTimeLabel()}, or you can provide a new API key.';
}