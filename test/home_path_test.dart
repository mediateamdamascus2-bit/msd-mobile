import 'package:flutter_test/flutter_test.dart';
import 'package:msd_mobile/config.dart';
import 'package:msd_mobile/user_roles.dart';

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
}
