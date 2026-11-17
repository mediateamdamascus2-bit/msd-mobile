import 'package:flutter_test/flutter_test.dart';
import 'package:msd_mobile/config.dart';
import 'package:msd_mobile/post_login_home.dart';
import 'package:msd_mobile/user_roles.dart';

Map<String, dynamic> _user({
  String? homePath,
  String? facilityId,
  List<String> roles = const [],
  String? username,
}) =>
    {
      if (homePath != null) 'homePath': homePath,
      if (facilityId != null) 'facilityId': facilityId,
      'roles': roles,
      if (username != null) 'username': username,
    };

void main() {
  test('canonicalHome keeps the new station paths and rewrites the old ones', () {
    expect(canonicalHome('/hospitals/harasta/station/clinic/القلبية'), '/hospitals/harasta/station/clinic/القلبية');
    expect(canonicalHome('/hospitals/mujtahed/station/reception'), '/hospitals/mujtahed/station/reception');
    expect(canonicalHome('/prisons/hasia/station/ph-internal'), '/prisons/hasia/station/ph-internal');
    expect(canonicalHome('/fleet/driver/DRV-01'), '/fleet/driver/DRV-01');
    expect(canonicalHome('/stations/harasta/booking'), '/hospitals/harasta/station/booking');
    expect(canonicalHome('/stations/harasta/clinic-live'), '/hospitals/harasta/station/clinics-live');
    expect(canonicalHome('/stations/hasia/intake'), '/prisons/hasia/station/intake');
    expect(canonicalHome('/f/harasta'), '/hospitals/harasta');
    expect(canonicalHome('/f/hasia'), '/prisons/hasia');
  });

  test('home helpers pick the hospital, the hasia station, and the driver', () {
    final clinic = hospitalStationFromHome('/stations/harasta/clinic/القلبية');
    expect(clinic?.hospitalId, 'harasta');
    expect(clinic?.kind, 'clinic');
    expect(clinic?.name, 'القلبية');
    expect(clinicFromHomePath(<String, dynamic>{'homePath': '/hospitals/mujtahed/station/clinic/العينية'}), 'العينية');
    expect(departmentFromHomePath(<String, dynamic>{'homePath': '/stations/harasta/dept/المخبر'}), 'المخبر');
    expect(hasiaStationFromHome('/stations/hasia/triage'), 'triage');
    expect(driverIdFromHome('/fleet/driver/DRV-01'), 'DRV-01');
    expect(isBookingClerkUser(<String, dynamic>{'homePath': '/stations/harasta/booking', 'roles': const []}), isTrue);
    expect(isReceptionUser(<String, dynamic>{'homePath': '/hospitals/harasta/station/reception', 'roles': const []}), isTrue);
  });

  test('debug HTTP is limited to local-network hosts', () {
    expect(AppConfig.isLocalNetworkHost('localhost'), isTrue);
    expect(AppConfig.isLocalNetworkHost('10.0.2.2'), isTrue);
    expect(AppConfig.isLocalNetworkHost('192.168.1.20'), isTrue);
    expect(AppConfig.isLocalNetworkHost('10.1.2.3'), isTrue);
    expect(AppConfig.isLocalNetworkHost('172.16.0.4'), isTrue);
    expect(AppConfig.isLocalNetworkHost('8.8.8.8'), isFalse);
    expect(AppConfig.isLocalNetworkHost('example.com'), isFalse);
    expect(AppConfig.isAllowedBase('http://10.0.2.2:5148'), isTrue);
    expect(AppConfig.isAllowedBase('http://example.com'), isFalse);
    expect(AppConfig.isAllowedBase('https://example.com'), isTrue);
  });

  test('display station lands on the display-only message', () {
    expect(
      resolveMobileLanding(_user(homePath: '/hospitals/harasta/station/display')),
      MobileLanding.displayStation,
    );
    expect(
      resolveMobileLanding(_user(homePath: '/hospitals/mujtahed/station/display')),
      MobileLanding.displayStation,
    );
  });

  test('events home lands on the events desk', () {
    expect(resolveMobileLanding(_user(homePath: '/events')), MobileLanding.eventsDesk);
    expect(resolveMobileLanding(_user(homePath: '/events/desk')), MobileLanding.eventsDesk);
    expect(resolveMobileLanding(_user(homePath: '/events/register')), MobileLanding.eventsDesk);
  });

  test('fleet desk home lands on the fleet desk', () {
    expect(resolveMobileLanding(_user(homePath: '/fleet/desk')), MobileLanding.fleetDesk);
    expect(resolveMobileLanding(_user(homePath: '/fleet/desk/main')), MobileLanding.fleetDesk);
  });

  test('field and update homes land on the field unit', () {
    expect(resolveMobileLanding(_user(homePath: '/field')), MobileLanding.fieldUnit);
    expect(resolveMobileLanding(_user(homePath: '/update')), MobileLanding.fieldUnit);
    expect(resolveMobileLanding(_user(homePath: '/f/unit-homs-2')), MobileLanding.fieldUnit);
  });

  test('Admin alone gets NativeAppShell; unknown paths are unsupported', () {
    expect(
      resolveMobileLanding(_user(homePath: '/dashboard', roles: const ['Admin'])),
      MobileLanding.adminShell,
    );
    expect(
      resolveMobileLanding(_user(homePath: '/dashboard', roles: const ['FacilityUser'])),
      MobileLanding.unsupported,
    );
    expect(
      resolveMobileLanding(_user(homePath: '/somewhere-else')),
      MobileLanding.unsupported,
    );
  });

  test('known hospital stations still resolve before the unsupported fallback', () {
    expect(
      resolveMobileLanding(_user(homePath: '/hospitals/harasta/station/booking')),
      MobileLanding.booking,
    );
    expect(
      resolveMobileLanding(_user(homePath: '/fleet/driver/DRV-01')),
      MobileLanding.driver,
    );
  });
}
