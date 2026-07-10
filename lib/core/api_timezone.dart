/// Resolves an IANA timezone name for API headers (e.g. X-Timezone).
String resolveApiTimezone() {
  final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

  if (offsetMinutes == 330) return 'Asia/Kolkata';
  if (offsetMinutes == 300) return 'Asia/Karachi';
  if (offsetMinutes == 480) return 'Asia/Singapore';
  if (offsetMinutes == 540) return 'Asia/Tokyo';
  if (offsetMinutes == 0) return 'UTC';
  if (offsetMinutes == -300) return 'America/New_York';
  if (offsetMinutes == -360) return 'America/Chicago';
  if (offsetMinutes == -420) return 'America/Denver';
  if (offsetMinutes == -480) return 'America/Los_Angeles';
  if (offsetMinutes == 60) return 'Europe/Paris';
  if (offsetMinutes == 120) return 'Europe/Berlin';
  return 'UTC';
}

Map<String, String> apiAuthHeaders(String accessToken) => {
      'Authorization': 'Bearer $accessToken',
      'X-Timezone': resolveApiTimezone(),
    };
