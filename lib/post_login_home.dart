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
import 'screens/ops/ops_events_screen.dart';
import 'screens/ops/ops_fleet_screen.dart';
import 'screens/reception_screen.dart';
import 'user_roles.dart';

/// Landing surface after login — used by [buildPostLoginHome] and unit tests.
enum MobileLanding {
  driver,
  booking,
  reception,
  clinicsLive,
  assets,
  clinic,
  dept,
  displayStation,
  hasiaStation,
  hasiaHub,
  hospitalHub,
  eventsDesk,
  fleetDesk,
  fieldUnit,
  adminShell,
  unsupported,
}

/// Resolves where a signed-in user should land on mobile (after [canonicalHome]).
MobileLanding resolveMobileLanding(Map<String, dynamic> user) {
  final home = canonicalHome(user['homePath']?.toString());
  final facilityId = user['facilityId']?.toString();

  if (driverIdFromHome(home) != null) return MobileLanding.driver;

  if (_isDisplayStation(home)) return MobileLanding.displayStation;
  if (_isEventsHome(home)) return MobileLanding.eventsDesk;
  if (_isFleetDeskHome(home)) return MobileLanding.fleetDesk;
  if (_isFieldHome(home)) return MobileLanding.fieldUnit;

  final station = hospitalStationFromHome(home);
  if (station != null) {
    return switch (station.kind) {
      'booking' => MobileLanding.booking,
      'reception' => MobileLanding.reception,
      'clinics-live' => MobileLanding.clinicsLive,
      'assets' => MobileLanding.assets,
      'clinic' => (station.name != null &&
              station.name!.isNotEmpty &&
              !station.name!.startsWith('-'))
          ? MobileLanding.clinic
          : MobileLanding.unsupported,
      'dept' => (station.name != null && station.name!.isNotEmpty)
          ? MobileLanding.dept
          : MobileLanding.unsupported,
      'display' => MobileLanding.displayStation,
      _ => MobileLanding.unsupported,
    };
  }

  if (hasiaStationFromHome(home) != null) return MobileLanding.hasiaStation;

  if (home == '/prisons/hasia' ||
      home.startsWith('/prisons/hasia/') ||
      (facilityId == 'hasia' && !isAdminUser(user))) {
    return MobileLanding.hasiaHub;
  }

  final hospitalRoot = RegExp(r'^/hospitals/([^/]+)$').firstMatch(home);
  if (isFacilityManagerUser(user) || hospitalRoot != null) {
    return MobileLanding.hospitalHub;
  }

  if (isAdminUser(user)) return MobileLanding.adminShell;
  return MobileLanding.unsupported;
}

bool _isDisplayStation(String home) =>
    RegExp(r'^/hospitals/[^/]+/station/display(?:/.*)?$').hasMatch(home);

bool _isEventsHome(String home) =>
    home == '/events' || home.startsWith('/events/');

bool _isFleetDeskHome(String home) =>
    home == '/fleet/desk' || home.startsWith('/fleet/desk/');

bool _isFieldHome(String home) =>
    home == '/field' ||
    home == '/update' ||
    home.startsWith('/field/') ||
    home.startsWith('/update/');

/// Same idea as web LoginRouting: username/password → homePath station.
/// Accepts the React paths and, for now, the old `/stations/...` paths.
Widget buildPostLoginHome({
  required ApiClient api,
  required Map<String, dynamic> user,
  required Future<void> Function() onLogout,
}) {
  final home = canonicalHome(user['homePath']?.toString());
  final facilityId = user['facilityId']?.toString();
  final landing = resolveMobileLanding(user);

  switch (landing) {
    case MobileLanding.driver:
      return DriverHomeScreen(
        api: api,
        user: user,
        driverId: driverIdFromHome(home)!,
        onLogout: onLogout,
      );
    case MobileLanding.displayStation:
      return _StationMessageScreen(
        message: 'هذه المحطة تعمل على شاشة العرض',
        onLogout: onLogout,
      );
    case MobileLanding.eventsDesk:
      return _OpsScaffold(
        title: 'الأحداث الطبية',
        onLogout: onLogout,
        child: OpsEventsScreen(api: api, user: user),
      );
    case MobileLanding.fleetDesk:
      return _OpsScaffold(
        title: 'مكتب الأسطول',
        onLogout: onLogout,
        child: OpsFleetScreen(api: api),
      );
    case MobileLanding.fieldUnit:
      return _StationMessageScreen(
        title: 'الميدان',
        message: 'الشاشة الميدانية',
        onLogout: onLogout,
      );
    case MobileLanding.booking:
    case MobileLanding.reception:
    case MobileLanding.clinicsLive:
    case MobileLanding.assets:
    case MobileLanding.clinic:
    case MobileLanding.dept:
      final station = hospitalStationFromHome(home)!;
      final hospitalId = _facility(facilityId, station.hospitalId);
      return _hospitalStation(api, station, hospitalId, onLogout)!;
    case MobileLanding.hasiaStation:
      return _hasiaStation(api, user, hasiaStationFromHome(home)!, onLogout);
    case MobileLanding.hasiaHub:
      return HasiaHubScreen(api: api, user: user, onLogout: onLogout);
    case MobileLanding.hospitalHub:
      final hospitalRoot = RegExp(r'^/hospitals/([^/]+)$').firstMatch(home);
      final id = hospitalRoot?.group(1) ?? 'harasta';
      if (id == 'harasta') return HarastaHubScreen(api: api, user: user, onLogout: onLogout);
      return FacilityScreen(api: api, facilityId: id);
    case MobileLanding.adminShell:
      return NativeAppShell(api: api, user: user, onLogout: onLogout);
    case MobileLanding.unsupported:
      return _StationMessageScreen(
        message: 'لا توجد محطة لهذا الحساب على الجوال',
        onLogout: onLogout,
      );
  }
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
    case 'display':
      return _StationMessageScreen(
        message: 'هذه المحطة تعمل على شاشة العرض',
        onLogout: onLogout,
      );
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
  if (station != 'intake' &&
      station != 'triage' &&
      station != 'cases' &&
      station != 'ph-internal' &&
      station != 'ph-external') {
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

class _StationMessageScreen extends StatelessWidget {
  const _StationMessageScreen({
    required this.message,
    required this.onLogout,
    this.title,
  });

  final String message;
  final String? title;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'محطة الجوال'),
        actions: [
          TextButton(onPressed: onLogout, child: const Text('خروج')),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

class _OpsScaffold extends StatelessWidget {
  const _OpsScaffold({
    required this.title,
    required this.child,
    required this.onLogout,
  });

  final String title;
  final Widget child;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(onPressed: onLogout, child: const Text('خروج')),
        ],
      ),
      body: child,
    );
  }
}
