import 'dart:async';

import '../api_client.dart';

typedef JsonRow = Map<String, dynamic>;

/// Snapshot of the command dashboard, built only from existing server endpoints.
/// A per-facility list is `null` when that endpoint failed or is not accessible.
class CommandData {
  CommandData({
    required this.facilities,
    required this.events,
    required this.needs,
    required this.fleet,
    required this.stores,
    required this.inmates,
    required this.fetchedAt,
    this.summary,
    this.boardPrisons = const [],
    this.boardPoints = const [],
    this.boardHospitals = const [],
    this.boardWarehouses = const [],
    this.boardCourses = const [],
    this.boardStaff = const [],
    this.boardMarkers = const [],
    this.boardEvents = const [],
    this.boardVehicles = const [],
    this.boardAdmissions = const [],
  });

  final List<JsonRow> facilities;
  final Map<String, List<JsonRow>?> events;
  final Map<String, List<JsonRow>?> needs;
  final Map<String, List<JsonRow>?> fleet;
  final Map<String, List<JsonRow>?> stores;
  final int? inmates;
  final DateTime fetchedAt;
  final Map<String, dynamic>? summary;
  final List<JsonRow> boardPrisons;
  final List<JsonRow> boardPoints;
  final List<JsonRow> boardHospitals;
  final List<JsonRow> boardWarehouses;
  final List<JsonRow> boardCourses;
  final List<JsonRow> boardStaff;
  final List<JsonRow> boardMarkers;
  final List<JsonRow> boardEvents;
  final List<JsonRow> boardVehicles;
  final List<JsonRow> boardAdmissions;

  static const hospital = 'Hospital';
  static const prison = 'PrisonClinic';
  static const unit = 'MedicalUnit';
  static const center = 'MedicalCenter';
  static const warehouse = 'Warehouse';

  List<JsonRow> ofType(String type) => facilities.where((f) => f['type'] == type).toList();

  String nameOf(String? id) {
    for (final f in facilities) {
      if (f['id'] == id) return f['nameAr']?.toString() ?? id ?? '';
    }
    return id ?? '';
  }

  String provinceOf(String? id) {
    for (final f in facilities) {
      if (f['id'] == id) return f['provinceAr']?.toString() ?? '';
    }
    return '';
  }

  int? summaryValue(String section, String label) {
    final sections = summary?['sections'];
    if (sections is! List) return null;
    for (final raw in sections) {
      if (raw is! Map || raw['title']?.toString() != section) continue;
      final stats = raw['stats'];
      if (stats is! List) return null;
      for (final st in stats) {
        if (st is Map && st['label']?.toString() == label && st['value'] is num) {
          return (st['value'] as num).round();
        }
      }
    }
    return null;
  }

  /// Every event from every facility that answered, newest first.
  /// Directorate events win when the account can read them.
  List<JsonRow> get allEvents {
    if (boardEvents.isNotEmpty) return boardEvents;
    final out = <JsonRow>[];
    for (final e in events.entries) {
      for (final r in e.value ?? const <JsonRow>[]) {
        out.add({...r, 'facilityId': r['facilityId'] ?? e.key});
      }
    }
    out.sort((a, b) => (b['createdAt']?.toString() ?? '').compareTo(a['createdAt']?.toString() ?? ''));
    return out;
  }

  bool get hasEvents => boardEvents.isNotEmpty || events.values.any((v) => v != null);
  bool get hasNeeds => needs.values.any((v) => v != null);
  bool get hasFleet => boardVehicles.isNotEmpty || fleet.values.any((v) => v != null && v.isNotEmpty);
  bool get hasStores => stores.values.any((v) => v != null && v.isNotEmpty);

  List<JsonRow> get allVehicles => boardVehicles.isNotEmpty
      ? boardVehicles
      : [
          for (final e in fleet.entries)
            for (final v in e.value ?? const <JsonRow>[]) {...v, 'facilityId': e.key},
        ];

  List<JsonRow> openNeedsOf(String id) => needs[id] ?? const [];

  static bool isOpen(JsonRow e) => e['closedAt'] == null && (e['status']?.toString() ?? '') != 'مغلق';

  /// Severity bucket: 0 = urgent, 1 = high/medium, 2 = normal/low.
  static int severityRank(JsonRow e) {
    final s = e['severity']?.toString() ?? '';
    if (s.contains('عاجل') || s.contains('حرج') || s.contains('إسعافي')) return 0;
    if (s.contains('مرتفع') || s.contains('متوسط') || s.contains('عال')) return 1;
    return 2;
  }

  static DateTime? parseTime(Object? v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}

class CommandRepository {
  CommandRepository._();

  static CommandData? cached;
  static Future<CommandData>? _inflight;

  /// Loads (or joins an in-flight load of) the dashboard snapshot.
  static Future<CommandData> load(ApiClient api) {
    return _inflight ??= _load(api).whenComplete(() => _inflight = null);
  }

  static Future<CommandData> _load(ApiClient api) async {
    final list = (await api.facilities()).whereType<Map>().map((m) => JsonRow.from(m)).toList();
    final ids = [for (final f in list) f['id']?.toString() ?? ''].where((s) => s.isNotEmpty).toList();

    Future<List<JsonRow>?> safe(Future<List<dynamic>> Function() f) async {
      try {
        return (await f()).whereType<Map>().map((m) => JsonRow.from(m)).toList();
      } catch (e) {
        if (e.toString().contains(ApiClient.sessionExpiredMessage)) rethrow;
        return null;
      }
    }

    Future<Map<String, List<JsonRow>?>> each(Future<List<dynamic>> Function(String id) f) async {
      final rows = await Future.wait([for (final id in ids) safe(() => f(id))]);
      return {for (var i = 0; i < ids.length; i++) ids[i]: rows[i]};
    }

    final hasHasia = ids.contains('hasia');
    final results = await Future.wait<Object?>([
      each((id) => api.facilityEvents(id, openOnly: false)),
      each((id) => api.facilityNeeds(id, openOnly: true)),
      each(api.fleet),
      each(api.stores),
      hasHasia ? safe(api.hasiaInmates) : Future.value(null),
      api.directorateState().then<Object?>((v) => v),
      api.directorateSummary().then<Object?>((v) => v),
    ]);

    final inmates = results[4] as List<JsonRow>?;
    final state = results[5] as Map<String, dynamic>?;
    final summary = results[6] as Map<String, dynamic>?;
    List<JsonRow> board(String key) {
      final node = state?[key];
      if (node is! List) return const [];
      return [
        for (final item in node)
          if (item is Map) (JsonRow.from(item)..remove('password')),
      ];
    }

    final fleetNode = state?['fleet'];
    final vehicles = fleetNode is Map ? boardList(fleetNode['vehicles']) : const <JsonRow>[];
    final data = CommandData(
      facilities: list,
      events: results[0] as Map<String, List<JsonRow>?>,
      needs: results[1] as Map<String, List<JsonRow>?>,
      fleet: results[2] as Map<String, List<JsonRow>?>,
      stores: results[3] as Map<String, List<JsonRow>?>,
      inmates: inmates?.length,
      fetchedAt: DateTime.now(),
      summary: summary,
      boardPrisons: board('prisons'),
      boardPoints: board('points'),
      boardHospitals: board('hospitals'),
      boardWarehouses: board('warehouses'),
      boardCourses: board('courses'),
      boardStaff: board('staff'),
      boardMarkers: board('markers'),
      boardEvents: [for (final e in board('events')) _eventRow(e)],
      boardVehicles: [for (final v in vehicles) _vehicleRow(v)],
      boardAdmissions: board('admissions'),
    );
    cached = data;
    return data;
  }
}

List<JsonRow> boardList(Object? node) {
  if (node is! List) return const [];
  return [
    for (final item in node)
      if (item is Map) (JsonRow.from(item)..remove('password')),
  ];
}

JsonRow _eventRow(JsonRow e) {
  if (e.containsKey('title') || e.containsKey('severity')) return e;
  return {
    ...e,
    'title': e['type'] ?? e['location'] ?? 'حدث',
    'kind': e['type'],
    'severity': e['sev'] ?? 'عادي',
  };
}

JsonRow _vehicleRow(JsonRow v) {
  if (v.containsKey('vehicleType')) return v;
  return {
    ...v,
    'code': v['code'] ?? v['id'],
    'vehicleType': v['type'],
    'statusAr': v['status'],
    'odometerKm': v['odo'],
  };
}

String hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String agoAr(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'قبل ${d.inMinutes} د';
  if (d.inHours < 24) return 'قبل ${d.inHours} س';
  return 'قبل ${d.inDays} يوم';
}
