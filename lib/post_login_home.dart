import 'package:flutter/material.dart';

import 'api_client.dart';
import 'screens/booking_screen.dart';
import 'screens/clinic_live_screen.dart';
import 'screens/clinic_screen.dart';
import 'screens/dept_screen.dart';
import 'screens/driver_home_screen.dart';
import 'screens/facility_screen.dart';
import 'screens/harasta/harasta_pages.dart';
import 'screens/harasta_hub_screen.dart';
import 'screens/hasia_cases_screen.dart';
import 'screens/hasia_hub_screen.dart';
import 'screens/hasia_inmates_screen.dart';
import 'screens/hasia_pharmacy_screen.dart';
import 'screens/native_app_shell.dart';
import 'screens/reception_screen.dart';
import 'user_roles.dart';

/// Same idea as web LoginRouting: username/password → homePath station.
/// Accepts the React paths and, for now, the old `/stations/...` paths.
Widget buildPostLoginHome({
  required ApiClient api,
  required Map<String, dynamic> user,
  required Future<void> Function() onLogout,
}) {
  final home = canonicalHome(user['homePath']?.toString());
  final facilityId = user['facilityId']?.toString();

  final driverId = driverIdFromHome(home);
  if (driverId != null) {
    return DriverHomeScreen(api: api, user: user, driverId: driverId, onLogout: onLogout);
  }

  final station = hospitalStationFromHome(home);
  if (station != null) {
    final hospitalId = _facility(facilityId, station.hospitalId);
    final opened = _hospitalStation(api, station, hospitalId, onLogout);
    if (opened != null) return opened;
  }

  final hasiaStation = hasiaStationFromHome(home);
  if (hasiaStation != null) {
    return _hasiaStation(api, user, hasiaStation, onLogout);
  }

  if (home == '/prisons/hasia' || home.startsWith('/prisons/hasia/') || (facilityId == 'hasia' && !isAdminUser(user))) {
    return HasiaHubScreen(api: api, user: user, onLogout: onLogout);
  }

  final hospitalRoot = RegExp(r'^/hospitals/([^/]+)$').firstMatch(home);
  if (isFacilityManagerUser(user) || hospitalRoot != null) {
    final id = hospitalRoot?.group(1) ?? 'harasta';
    if (id == 'harasta') return HarastaHubScreen(api: api, user: user, onLogout: onLogout);
    return FacilityScreen(api: api, facilityId: id);
  }

  return NativeAppShell(api: api, user: user, onLogout: onLogout);
}

Widget? _hospitalStation(
  ApiClient api,
  HomeStation station,
  String hospitalId,
  Future<void> Function() onLogout,
) {
  switch (station.kind) {
    case 'booking':
      return BookingScreen(api: api, facilityId: hospitalId, onLogout: onLogout);
    case 'reception':
      return ReceptionScreen(api: api, facilityId: hospitalId, onLogout: onLogout);
    case 'clinics-live':
      return ClinicLiveScreen(api: api, facilityId: hospitalId, onLogout: onLogout);
    case 'assets':
      if (hospitalId == 'harasta') return HarastaAssetsOfficePage(api: api, onLogout: onLogout);
      return FacilityScreen(api: api, facilityId: hospitalId);
    case 'clinic':
      final clinic = station.name;
      if (clinic != null && clinic.isNotEmpty && !clinic.startsWith('-')) {
        return ClinicScreen(api: api, facilityId: hospitalId, clinic: clinic, onLogout: onLogout);
      }
      return null;
    case 'dept':
      final dept = station.name;
      if (dept != null && dept.isNotEmpty) {
        return DeptScreen(api: api, facilityId: hospitalId, department: dept, onLogout: onLogout);
      }
      return null;
    default:
      return null;
  }
}

String _facility(String? fromUser, String fromPath) {
  if (fromPath.isNotEmpty) return fromPath;
  if (fromUser != null && fromUser.isNotEmpty) return fromUser;
  return 'harasta';
}

Widget _hasiaStation(
  ApiClient api,
  Map<String, dynamic> user,
  String station,
  Future<void> Function() onLogout,
) {
  final (title, body) = switch (station) {
    'intake' => ('استقبال النزيل', HasiaInmatesScreen(api: api, user: user)),
    'triage' || 'cases' => ('الفرز والحالات', HasiaCasesScreen(api: api, user: user)),
    'ph-internal' => ('الصيدلية الداخلية', HasiaPharmacyScreen(api: api, pharmacy: 'internal')),
    'ph-external' => ('الصيدلية الخارجية', HasiaPharmacyScreen(api: api, pharmacy: 'external')),
    _ => ('سجن حسيا', HasiaHubScreen(api: api, user: user, onLogout: onLogout)),
  };
  if (station != 'intake' && station != 'triage' && station != 'cases' && station != 'ph-internal' && station != 'ph-external') {
    return body;
  }
  return Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        TextButton(onPressed: onLogout, child: const Text('خروج')),
      ],
    ),
    body: body,
  );
}
