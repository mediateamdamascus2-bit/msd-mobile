/// Old Blazor homes and the React homes name the same station.
/// Mirrors [LoginRouting.ToReactPath] on the server.
String canonicalHome(String? raw) {
  var path = (raw ?? '').trim();
  if (path.isEmpty) return '';
  try {
    path = Uri.decodeComponent(path).trim();
  } catch (_) {}
  if (!path.startsWith('/')) path = '/$path';

  var lower = path.toLowerCase();
  if (lower == '/legacy') return '/';
  if (lower.startsWith('/legacy/')) {
    path = path.substring('/legacy'.length);
    lower = path.toLowerCase();
  }
  if (lower == '/admin') return '/dashboard';
  if (lower == '/f/harasta' || lower == '/stations/harasta') return '/hospitals/harasta';
  if (lower == '/f/hasia' || lower == '/stations/hasia') return '/prisons/hasia';
  if (lower == '/f/unit-homs-2') return '/field';

  const harasta = '/stations/harasta/';
  if (lower.startsWith(harasta)) {
    path = '/hospitals/harasta/station/${path.substring(harasta.length)}';
  } else {
    const hasia = '/stations/hasia/';
    if (lower.startsWith(hasia)) {
      path = '/prisons/hasia/station/${path.substring(hasia.length)}';
    }
  }

  if (path.toLowerCase() == '/hospitals/harasta/station/clinic-live') {
    return '/hospitals/harasta/station/clinics-live';
  }
  if (path.length > 1 && path.endsWith('/')) path = path.substring(0, path.length - 1);
  return path;
}

class HomeStation {
  const HomeStation(this.hospitalId, this.kind, [this.name]);

  final String hospitalId;
  final String kind;
  final String? name;
}

/// `/hospitals/{hid}/station/{kind}/{name}` after legacy `/stations/...` is rewritten.
HomeStation? hospitalStationFromHome(String? raw) {
  final match = RegExp(r'^/hospitals/([^/]+)/station/([^/]+)(?:/([^/]+))?$').firstMatch(canonicalHome(raw));
  if (match == null) return null;
  final name = match.group(3);
  return HomeStation(match.group(1)!, match.group(2)!, name == null || name.isEmpty ? null : name);
}

/// `/prisons/hasia/station/{station}` after legacy `/stations/hasia/...` is rewritten.
String? hasiaStationFromHome(String? raw) {
  final match = RegExp(r'^/prisons/hasia/station/([^/]+)$').firstMatch(canonicalHome(raw));
  return match?.group(1);
}

/// `/fleet/driver/{id}`.
String? driverIdFromHome(String? raw) {
  final match = RegExp(r'^/fleet/driver/([^/]+)$').firstMatch(canonicalHome(raw));
  return match?.group(1);
}

String? hospitalIdFromHome(String? raw) {
  final match = RegExp(r'^/hospitals/([^/]+)').firstMatch(canonicalHome(raw));
  return match?.group(1);
}

List<String> userRoles(Map<String, dynamic>? user) {
  final raw = user?['roles'];
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList();
}

bool isAdminUser(Map<String, dynamic>? user) => userRoles(user).contains('Admin');

bool isFacilityManagerUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (isAdminUser(user)) return false;
  final roles = userRoles(user);
  final homePath = canonicalHome(user['homePath']?.toString());
  final facilityId = user['facilityId']?.toString();
  return roles.contains('FacilityUser') &&
      facilityId == 'harasta' &&
      (homePath.isEmpty || homePath == '/hospitals/harasta');
}

bool isBookingClerkUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (isAdminUser(user)) return false;
  final roles = userRoles(user);
  final username = user['username']?.toString();
  final homePath = canonicalHome(user['homePath']?.toString());
  return roles.contains('BookingClerk') || username == 'booking' || homePath.contains('/station/booking');
}

bool isReceptionUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (isAdminUser(user) || isBookingClerkUser(user)) return false;
  final username = user['username']?.toString();
  final homePath = canonicalHome(user['homePath']?.toString());
  return username == 'reception' || homePath.contains('/station/reception');
}

bool isClinicLiveUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  final homePath = canonicalHome(user['homePath']?.toString());
  final username = user['username']?.toString();
  return username == 'clinic-live' || homePath.contains('clinics-live');
}

/// Assigned clinic name from station HomePath, e.g. `/hospitals/harasta/station/clinic/القلبية`.
String? clinicFromHomePath(Map<String, dynamic>? user) {
  final station = hospitalStationFromHome(user?['homePath']?.toString());
  if (station == null || station.kind != 'clinic') return null;
  final clinic = station.name?.trim() ?? '';
  if (clinic.isEmpty || clinic.startsWith('-')) return null;
  return clinic;
}

String? departmentFromHomePath(Map<String, dynamic>? user) {
  final station = hospitalStationFromHome(user?['homePath']?.toString());
  if (station == null || station.kind != 'dept') return null;
  final dept = station.name?.trim() ?? '';
  return dept.isEmpty ? null : dept;
}

bool isClinicStationUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (isAdminUser(user) || isBookingClerkUser(user) || isReceptionUser(user)) return false;
  return clinicFromHomePath(user) != null;
}

bool isDeptStationUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (isAdminUser(user) || isBookingClerkUser(user) || isReceptionUser(user)) return false;
  return departmentFromHomePath(user) != null;
}

bool isHasiaUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  if (isAdminUser(user)) return true;
  final facilityId = user['facilityId']?.toString() ?? '';
  final homePath = canonicalHome(user['homePath']?.toString());
  return facilityId == 'hasia' || homePath.contains('/prisons/hasia') || homePath.contains('/hasia');
}

bool isHarastaFacilityUser(Map<String, dynamic>? user) {
  if (user == null) return false;
  final facilityId = user['facilityId']?.toString() ?? '';
  final homePath = canonicalHome(user['homePath']?.toString());
  return facilityId == 'harasta' || homePath.contains('/harasta');
}
