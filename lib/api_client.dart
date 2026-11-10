import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'services/settings_store.dart';

class ApiClient {
  ApiClient();

  static const requestTimeout = Duration(seconds: 15);
  static const networkErrorMessage = 'تعذر الاتصال بالخادم — تحقق من الشبكة';
  static const sessionExpiredMessage = 'انتهت الجلسة';
  static const accountDisabledMessage = 'هذا الحساب معطّل. راجع مسؤول النظام.';

  /// Set by the app shell. The message is [sessionExpiredMessage] or [accountDisabledMessage].
  static void Function(String message)? onSessionExpired;

  static const _tokenKey = 'msd_access_token';
  static const _refreshKey = 'msd_refresh_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  String? _token;
  String? _refresh;
  Future<_RefreshResult>? _refreshFlight;

  /// Live base URL from Settings (falls back to platform default).
  String get _base => SettingsStore.instance.apiBaseUrl;

  Future<void> loadToken() async {
    _token = await _storage.read(key: _tokenKey);
    _refresh = await _storage.read(key: _refreshKey);
    if (_token != null && _token!.isNotEmpty) return;

    // One-time migration from older plaintext SharedPreferences storage.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _tokenKey, value: legacy);
      await prefs.remove(_tokenKey);
      _token = legacy;
    }
  }

  Future<void> _saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    if (token == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _post(
      Uri.parse('$_base/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (res.statusCode == 401) {
      throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    if (_isAccountDisabled(res)) {
      throw Exception(accountDisabledMessage);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر تسجيل الدخول (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _saveToken(data['accessToken'] as String);
    await _saveRefresh(data['refreshToken'] as String?);
    final user = data['user'];
    if (user is Map) {
      final roles = user['roles'];
      if (roles is List) {
        user['roles'] = roles.map((e) => e.toString()).toList();
      }
    }
    return data;
  }

  Future<void> logout() async {
    final access = _token;
    await _saveToken(null);
    await _saveRefresh(null);
    if (access == null || access.isEmpty) return;
    try {
      await _send(() => http.post(
            Uri.parse('$_base/api/auth/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $access',
            },
          ));
    } catch (_) {}
  }

  Future<void> _saveRefresh(String? token) async {
    _refresh = token;
    if (token == null || token.isEmpty) {
      await _storage.delete(key: _refreshKey);
    } else {
      await _storage.write(key: _refreshKey, value: token);
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _get(
      Uri.parse('$_base/api/auth/me'),
      headers: _headers,
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الحساب (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final roles = data['roles'];
    if (roles is List) {
      data['roles'] = roles.map((e) => e.toString()).toList();
    }
    return data;
  }

  Future<Map<String, dynamic>?> directorateState() async {
    final res = await _get(Uri.parse('$_base/api/directorate/state'), headers: _headers);
    if (res.statusCode == 401) await _expire();
    if (res.statusCode == 403) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : null;
  }

  Future<Map<String, dynamic>?> directorateSummary() async {
    final res = await _get(Uri.parse('$_base/api/directorate/summary'), headers: _headers);
    if (res.statusCode == 401) await _expire();
    if (res.statusCode == 403) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : null;
  }

  Future<List<dynamic>> facilities() async {
    final res = await _get(
      Uri.parse('$_base/api/facilities'),
      headers: _headers,
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب المنشآت (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> facilityEvents(String facilityId, {bool openOnly = true}) async {
    final q = openOnly ? '?openOnly=true' : '';
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/events$q'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية لأحداث هذه المنشأة');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الأحداث (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> pingHealth() async {
    final res = await _get(Uri.parse('$_base/health')).timeout(const Duration(seconds: 6));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('الخادم غير متاح (${res.statusCode})');
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'status': 'ok', 'raw': res.body};
    }
  }

  Future<Map<String, dynamic>> facility(String id) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$id'),
      headers: _headers,
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب المنشأة (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTodayAdmissions(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/admissions/today'),
      headers: _headers,
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الإشغالات (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> putTodayAdmissions(
    String facilityId, {
    required int admissionsCount,
    required int occupiedBeds,
    required int availableBeds,
    required int transfersCount,
    String? notes,
  }) async {
    final res = await _put(
      Uri.parse('$_base/api/facilities/$facilityId/admissions/today'),
      headers: _headers,
      body: jsonEncode({
        'admissionsCount': admissionsCount,
        'occupiedBeds': occupiedBeds,
        'availableBeds': availableBeds,
        'transfersCount': transfersCount,
        'notes': notes,
      }),
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر حفظ الإشغالات (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> receptionQueue(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/reception/queue'),
      headers: _headers,
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب طابور الاستقبال (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> clinicQueue(String facilityId, String clinic) async {
    final encoded = Uri.encodeComponent(clinic);
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/$encoded/queue'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية لهذه العيادة');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب طابور العيادة (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> callClinicCase(String facilityId, String caseId) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/cases/$caseId/call'),
      headers: _headers,
      body: '{}',
    );
    return _decodeMap(res, failLabel: 'تعذر الاستدعاء');
  }

  Future<Map<String, dynamic>> completeClinicCase(
    String facilityId,
    String caseId, {
    required String doctor,
    String? note,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/cases/$caseId/complete'),
      headers: _headers,
      body: jsonEncode({'doctor': doctor, 'note': note}),
    );
    return _decodeMap(res, failLabel: 'تعذر إنهاء المعاينة');
  }

  Future<Map<String, dynamic>> returnClinicCase(
    String facilityId,
    String caseId, {
    required String doctor,
    String? reason,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/cases/$caseId/return'),
      headers: _headers,
      body: jsonEncode({'doctor': doctor, 'reason': reason}),
    );
    return _decodeMap(res, failLabel: 'تعذر الإعادة للاستقبال');
  }

  Future<Map<String, dynamic>> transferClinicCase(
    String facilityId,
    String caseId, {
    required String doctor,
    required String toClinic,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/cases/$caseId/transfer'),
      headers: _headers,
      body: jsonEncode({'doctor': doctor, 'toClinic': toClinic}),
    );
    return _decodeMap(res, failLabel: 'تعذر تحويل العيادة');
  }

  Future<Map<String, dynamic>> referClinicCase(
    String facilityId,
    String caseId, {
    required String doctor,
    required String department,
    String? note,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/cases/$caseId/refer-department'),
      headers: _headers,
      body: jsonEncode({'doctor': doctor, 'department': department, 'note': note}),
    );
    return _decodeMap(res, failLabel: 'تعذر التحويل للقسم');
  }

  Future<List<dynamic>> clinicCounts(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/counts'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب عدّادات العيادات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> clinicLive(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/clinics/live'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب إحصائيات العيادات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> receptionDayStats(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/reception/day-stats'),
      headers: _headers,
    );
    return _decodeMap(res, failLabel: 'إحصائيات الاستقبال');
  }

  Future<List<dynamic>> departmentsLive(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/departments/live'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب أقسام التحويل (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> fleet(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/fleet'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للأسطول');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الأسطول (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<void> setFleetStatus(
    String facilityId,
    String vehicleId, {
    required String status,
    String? missionNote,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/fleet/$vehicleId/status'),
      headers: _headers,
      body: jsonEncode({'status': status, 'missionNote': missionNote}),
    );
    await _decodeMap(res, failLabel: 'تحديث المركبة');
  }

  Future<List<dynamic>> stores(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/stores'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للمستودعات');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب المستودعات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> assets(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/assets'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للأصول');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الأصول (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> addAsset(
    String facilityId, {
    required String code,
    required String name,
    required String department,
    int count = 1,
    String? note,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/assets'),
      headers: _headers,
      body: jsonEncode({
        'code': code,
        'name': name,
        'department': department,
        'count': count,
        'note': note,
      }),
    );
    return _decodeMap(res, failLabel: 'إضافة أصل');
  }

  Future<Map<String, dynamic>> cycleAssetStatus(String facilityId, String assetId) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/assets/$assetId/cycle-status'),
      headers: _headers,
      body: '{}',
    );
    return _decodeMap(res, failLabel: 'تحديث حالة الأصل');
  }

  Future<Map<String, dynamic>> patientFiles(
    String facilityId, {
    String? q,
    String? kind,
  }) async {
    final params = <String>[];
    if (q != null && q.trim().isNotEmpty) params.add('q=${Uri.encodeQueryComponent(q.trim())}');
    if (kind != null && kind.isNotEmpty) params.add('kind=${Uri.encodeQueryComponent(kind)}');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/files$qs'),
      headers: _headers,
    );
    return _decodeMap(res, failLabel: 'ملفات المرضى');
  }

  Future<List<dynamic>> harastaOps(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/ops'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب مؤشرات التشغيل (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> departmentQueue(String facilityId, String department) async {
    final encoded = Uri.encodeComponent(department);
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/departments/$encoded/queue'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية لهذا القسم');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب طابور القسم (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> completeDepartmentCase(
    String facilityId,
    String caseId, {
    String? result,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/departments/cases/$caseId/complete'),
      headers: _headers,
      body: jsonEncode({'result': result}),
    );
    return _decodeMap(res, failLabel: 'تعذر إنهاء حالة القسم');
  }

  Future<Map<String, dynamic>> returnDepartmentToClinic(
    String facilityId,
    String caseId, {
    String? result,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/departments/cases/$caseId/return-clinic'),
      headers: _headers,
      body: jsonEncode({'result': result}),
    );
    return _decodeMap(res, failLabel: 'تعذر الإعادة للعيادة');
  }

  Future<Map<String, dynamic>> openReceptionCase(
    String facilityId, {
    required String entryType,
    required String category,
    String? specialType,
    String? specialNote,
    String? nationalId,
    required String patientName,
    int? age,
    String? residence,
    required String governorate,
    String? adminUnit,
    required String bookedClinic,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/reception/cases'),
      headers: _headers,
      body: jsonEncode({
        'entryType': entryType,
        'category': category,
        'specialType': specialType,
        'specialNote': specialNote,
        'nationalId': nationalId,
        'patientName': patientName,
        'age': age,
        'residence': residence,
        'governorate': governorate,
        'adminUnit': adminUnit,
        'bookedClinic': bookedClinic,
      }),
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode == 400) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(err['error']?.toString() ?? 'طلب غير صالح');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('طلب غير صالح');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر فتح الاستمارة (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendReceptionToClinic(
    String facilityId,
    String caseId, {
    String? clinic,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/reception/cases/$caseId/send-to-clinic'),
      headers: _headers,
      body: jsonEncode({'clinic': clinic}),
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode == 400) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(err['error']?.toString() ?? 'طلب غير صالح');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('طلب غير صالح');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر التحويل (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateReceptionCase(
    String facilityId,
    String caseId, {
    required String entryType,
    required String category,
    String? specialType,
    String? specialNote,
    String? nationalId,
    required String patientName,
    int? age,
    String? residence,
    required String governorate,
    String? adminUnit,
    required String bookedClinic,
  }) async {
    final res = await _put(
      Uri.parse('$_base/api/facilities/$facilityId/reception/cases/$caseId'),
      headers: _headers,
      body: jsonEncode({
        'entryType': entryType,
        'category': category,
        'specialType': specialType,
        'specialNote': specialNote,
        'nationalId': nationalId,
        'patientName': patientName,
        'age': age,
        'residence': residence,
        'governorate': governorate,
        'adminUnit': adminUnit,
        'bookedClinic': bookedClinic,
      }),
    );
    return _decodeMap(res, failLabel: 'تعذر حفظ التعديلات');
  }

  Future<List<dynamic>> pendingReceptionBookings(String facilityId) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/reception/pending-bookings'),
      headers: _headers,
    );
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الحجوزات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> arriveReceptionBooking(String facilityId, String bookingId) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/reception/bookings/$bookingId/arrive'),
      headers: _headers,
      body: '{}',
    );
    return _decodeMap(res, failLabel: 'تعذر تسجيل الوصول');
  }

  Future<Map<String, dynamic>> noShowReceptionBooking(String facilityId, String bookingId) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/reception/bookings/$bookingId/no-show'),
      headers: _headers,
      body: '{}',
    );
    return _decodeMap(res, failLabel: 'تعذر تسجيل عدم الحضور');
  }

  Future<Map<String, dynamic>> _decodeMap(http.Response res, {required String failLabel}) async {
    if (res.statusCode == 401) {
      await _expire();
    }
    if (res.statusCode == 403) {
      throw Exception('لا صلاحية لهذه العملية');
    }
    if (res.statusCode == 400) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(err['error']?.toString() ?? 'طلب غير صالح');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('طلب غير صالح');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$failLabel (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> bookingAvailability(String facilityId, {required String date}) async {
    final res = await _get(
      Uri.parse('$_base/api/stations/$facilityId/booking/availability?date=$date'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للحجز');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب التوفر (${res.statusCode})');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> bookingList(
    String facilityId, {
    required String entity,
    required String adminUnit,
  }) async {
    final q = Uri.encodeQueryComponent;
    final res = await _get(
      Uri.parse(
        '$_base/api/stations/$facilityId/booking/list?entity=${q(entity)}&adminUnit=${q(adminUnit)}',
      ),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للحجز');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الحجوزات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> createBookings(
    String facilityId, {
    required String entity,
    required String adminUnit,
    required String clinic,
    required String appointmentDate,
    required String preferredSlot,
    required String bookedBy,
    required List<Map<String, dynamic>> people,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/stations/$facilityId/booking/'),
      headers: _headers,
      body: jsonEncode({
        'entity': entity,
        'adminUnit': adminUnit,
        'clinic': clinic,
        'appointmentDate': appointmentDate,
        'preferredSlot': preferredSlot,
        'bookedBy': bookedBy,
        'people': people,
      }),
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للحجز');
    if (res.statusCode == 400) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(err['error']?.toString() ?? 'طلب غير صالح');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('طلب غير صالح');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر إنشاء الحجز (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateBooking(
    String facilityId,
    String bookingId, {
    required String clinic,
    required String appointmentDate,
    required String preferredSlot,
    required String patientName,
    String? nationalId,
    int? age,
    required String governorate,
    String? residence,
    required String category,
    String? specialType,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/stations/$facilityId/booking/$bookingId/update'),
      headers: _headers,
      body: jsonEncode({
        'clinic': clinic,
        'appointmentDate': appointmentDate,
        'preferredSlot': preferredSlot,
        'patientName': patientName,
        'nationalId': nationalId,
        'age': age,
        'governorate': governorate,
        'residence': residence,
        'category': category,
        'specialType': specialType,
      }),
    );
    return _decodeMap(res, failLabel: 'تعديل الحجز');
  }

  Future<void> cancelBooking(String facilityId, String bookingId) async {
    final res = await _post(
      Uri.parse('$_base/api/stations/$facilityId/booking/$bookingId/cancel'),
      headers: _headers,
      body: '{}',
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للحجز');
    if (res.statusCode == 400) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(err['error']?.toString() ?? 'طلب غير صالح');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('طلب غير صالح');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر الإلغاء (${res.statusCode})');
    }
  }

  Future<Map<String, dynamic>> createFacilityEvent(
    String facilityId, {
    required String title,
    required String kind,
    required String severity,
    String? details,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/events'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'kind': kind,
        'severity': severity,
        'details': details,
      }),
    );
    return _decodeMap(res, failLabel: 'إنشاء الحدث');
  }

  Future<Map<String, dynamic>> closeFacilityEvent(String facilityId, String eventId) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/events/$eventId/close'),
      headers: _headers,
      body: '{}',
    );
    return _decodeMap(res, failLabel: 'إغلاق الحدث');
  }

  Future<List<dynamic>> facilityNeeds(String facilityId, {bool openOnly = true}) async {
    final q = openOnly ? '?openOnly=true' : '';
    final res = await _get(
      Uri.parse('$_base/api/facilities/$facilityId/needs$q'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية لاحتياجات هذه المنشأة');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الاحتياجات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createFacilityNeed(
    String facilityId, {
    required String title,
    required String category,
    required String priority,
    required int quantity,
    String? notes,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/needs'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'category': category,
        'priority': priority,
        'quantity': quantity,
        'notes': notes,
      }),
    );
    return _decodeMap(res, failLabel: 'إنشاء الاحتياج');
  }

  Future<Map<String, dynamic>> updateFacilityNeedStatus(
    String facilityId,
    String needId,
    String status,
  ) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/$facilityId/needs/$needId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return _decodeMap(res, failLabel: 'تحديث الاحتياج');
  }

  Future<List<dynamic>> hasiaInmates() async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/hasia/inmates'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية لسجل نزلاء حسيا');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب النزلاء (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createHasiaInmate(Map<String, dynamic> body) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/hasia/inmates'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decodeMap(res, failLabel: 'تسجيل النزيل');
  }

  Future<List<dynamic>> hasiaCases({String? status, bool archiveOnly = false}) async {
    final q = <String>[];
    if (status != null && status.isNotEmpty) q.add('status=${Uri.encodeQueryComponent(status)}');
    if (archiveOnly) q.add('archiveOnly=true');
    final qs = q.isEmpty ? '' : '?${q.join('&')}';
    final res = await _get(
      Uri.parse('$_base/api/facilities/hasia/cases$qs'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية لحالات حسيا');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الحالات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> hasiaTriage({
    required String triager,
    required String inmateNo,
    required String complaint,
    required String toServiceId,
  }) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/hasia/triage'),
      headers: _headers,
      body: jsonEncode({
        'triager': triager,
        'inmateNo': inmateNo,
        'complaint': complaint,
        'toServiceId': toServiceId,
      }),
    );
    return _decodeMap(res, failLabel: 'فتح فرز');
  }

  Future<Map<String, dynamic>> hasiaCaseStep(String caseId, Map<String, dynamic> body) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/hasia/cases/$caseId/step'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decodeMap(res, failLabel: 'خطوة الحالة');
  }

  Future<List<dynamic>> hasiaPharmacyStock(String pharmacy) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/hasia/pharmacy/$pharmacy/stock'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للصيدلية');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب المخزون (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<List<dynamic>> hasiaPharmacyRx(String pharmacy) async {
    final res = await _get(
      Uri.parse('$_base/api/facilities/hasia/pharmacy/$pharmacy/rx'),
      headers: _headers,
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للوصفات');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر جلب الوصفات (${res.statusCode})');
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<void> hasiaDispense(Map<String, dynamic> body) async {
    final res = await _post(
      Uri.parse('$_base/api/facilities/hasia/pharmacy/dispense'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensureAuth(res.statusCode);
    if (res.statusCode == 403) throw Exception('لا صلاحية للصرف');
    if (res.statusCode == 400) {
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(err['error']?.toString() ?? 'طلب غير صالح');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('طلب غير صالح');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر الصرف (${res.statusCode})');
    }
  }

  void _ensureAuth(int statusCode) {
    if (statusCode == 401) {
      unawaited(_expire());
      throw Exception(sessionExpiredMessage);
    }
  }

  /// Clears the token, calls `/api/auth/logout`, and returns the app to the login screen.
  Future<Never> _expire([String message = sessionExpiredMessage]) async {
    await logout();
    onSessionExpired?.call(message);
    throw Exception(message);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    if (_base.isEmpty) throw Exception('لم يُضبط عنوان الخادم لهذا الإصدار');
    try {
      return await request().timeout(requestTimeout);
    } on TimeoutException {
      throw Exception(networkErrorMessage);
    } on http.ClientException {
      throw Exception(networkErrorMessage);
    }
  }

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) =>
      _withRefresh(url, () => http.get(url, headers: _headers));

  Future<http.Response> _post(Uri url, {Map<String, String>? headers, Object? body}) =>
      _withRefresh(url, () => http.post(url, headers: headers ?? _headers, body: body));

  Future<http.Response> _put(Uri url, {Map<String, String>? headers, Object? body}) =>
      _withRefresh(url, () => http.put(url, headers: headers ?? _headers, body: body));

  bool _canRefresh(Uri url) {
    final path = url.path;
    return !path.endsWith('/api/auth/login') && !path.endsWith('/api/auth/refresh') && !path.endsWith('/api/auth/logout');
  }

  Future<http.Response> _withRefresh(Uri url, Future<http.Response> Function() request) async {
    final res = await _send(request);
    if (_isAccountDisabled(res)) await _expire(accountDisabledMessage);
    if (res.statusCode != 401 || !_canRefresh(url)) return res;
    final result = await _refreshShared();
    if (result == _RefreshResult.disabled) await _expire(accountDisabledMessage);
    if (result != _RefreshResult.ok) await _expire();
    final again = await _send(request);
    if (_isAccountDisabled(again)) await _expire(accountDisabledMessage);
    if (again.statusCode == 401) await _expire();
    return again;
  }

  Future<_RefreshResult> _refreshShared() {
    final running = _refreshFlight;
    if (running != null) return running;
    final task = _tryRefresh();
    _refreshFlight = task;
    return task.whenComplete(() {
      if (identical(_refreshFlight, task)) _refreshFlight = null;
    });
  }

  Future<_RefreshResult> _tryRefresh() async {
    final refresh = _refresh;
    if (refresh == null || refresh.isEmpty) return _RefreshResult.failed;
    try {
      final res = await _send(() => http.post(
            Uri.parse('$_base/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          ));
      if (_isAccountDisabled(res)) return _RefreshResult.disabled;
      if (res.statusCode < 200 || res.statusCode >= 300) return _RefreshResult.failed;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await _saveToken(data['accessToken'] as String?);
      await _saveRefresh(data['refreshToken'] as String?);
      return _token != null && _token!.isNotEmpty ? _RefreshResult.ok : _RefreshResult.failed;
    } catch (_) {
      return _RefreshResult.failed;
    }
  }
}

enum _RefreshResult { ok, failed, disabled }

bool _isAccountDisabled(http.Response res) {
  if (res.statusCode != 403) return false;
  try {
    final body = jsonDecode(res.body);
    return body is Map && body['error'] == 'account_disabled';
  } catch (_) {
    return false;
  }
}
