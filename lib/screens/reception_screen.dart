import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../data/booking_catalog.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/msd_widgets.dart';
import '../theme/station_chrome.dart';
import '../ui/msd_text_field.dart';

enum _BookingFilter { pending, arrived, noshow }

String? _validateName(String v) {
  final parts = v.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length < 3) return 'أدخل الاسم الثلاثي كاملاً (ثلاثة أجزاء على الأقل)';
  return null;
}

String? _validateNationalId(String v, {required bool required}) {
  final t = v.trim();
  if (t.isEmpty) return required ? 'أدخل الرقم الوطني' : null;
  if (!RegExp(r'^\d{11}$').hasMatch(t)) return 'الرقم الوطني يجب أن يتكون من 11 رقمًا';
  return null;
}

String? _validateAge(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null || n < 0 || n > 120) return 'العمر يجب أن يكون بين 0 و 120';
  return null;
}

List<String> _strings(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final e in raw) {
    String? s;
    if (e is Map) {
      s = (e['name'] ?? e['value'] ?? e['label'] ?? e['clinic'])?.toString();
    } else if (e != null) {
      s = e.toString();
    }
    s = s?.trim();
    if (s != null && s.isNotEmpty && !out.contains(s)) out.add(s);
  }
  return out;
}

String _hhmm(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _todayIso() {
  final t = DateTime.now();
  return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

class ReceptionScreen extends StatefulWidget {
  const ReceptionScreen({
    super.key,
    required this.api,
    required this.facilityId,
    this.onLogout,
  });

  final ApiClient api;
  final String facilityId;
  final Future<void> Function()? onLogout;

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> with WidgetsBindingObserver {
  static const specialTypes = [
    'ابن شهيد',
    'بدون هوية',
    'جريح',
    'ذوو الاحتياجات الخاصة',
    'أخرى',
  ];

  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _age = TextEditingController();
  final _residence = TextEditingController();
  final _bookingQuery = TextEditingController();
  final _specialNote = TextEditingController();
  final _adminFree = TextEditingController();
  final _kinName = TextEditingController();

  String _entry = 'حجز مسبق';
  String _category = 'عامة';
  String _special = specialTypes.first;
  String _governorate = BookingCatalog.governorates.first;
  String _entity = BookingCatalog.entities.first;
  String _admin = '';
  String _legal = 'مدني';
  String _kinship = BookingCatalog.kinshipOptions.first;
  String _clinic = '';

  List<String> _clinicList = const [];
  List<String> _entityList = const [];
  List<String> _authorityList = const [];
  List<String> _governorateList = const [];

  bool _saving = false;
  bool _loading = true;
  String? _flash;
  bool _flashError = false;
  DateTime? _lastUpdated;
  bool _paused = false;

  String? _errName;
  String? _errNid;
  String? _errAge;
  String? _errKin;
  String? _errAdmin;

  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _bookings = [];
  final Set<String> _busyBookings = {};
  _BookingFilter _filter = _BookingFilter.pending;

  String? _selectedId;
  String _editCategory = 'عامة';
  String _editSpecial = specialTypes.first;
  final _editSpecialNote = TextEditingController();
  final _editNationalId = TextEditingController();
  final _editName = TextEditingController();
  final _editAge = TextEditingController();
  final _editResidence = TextEditingController();
  final _editAdminFree = TextEditingController();
  String _editGovernorate = BookingCatalog.governorates.first;
  String _editEntity = BookingCatalog.entities.first;
  String _editAdmin = '';
  String _editLegal = 'مدني';
  String _editClinic = '';
  String _editBaseline = '';
  bool _dossierBusy = false;
  String? _dossierMsg;
  bool _dossierError = false;

  bool get _noId => _category == 'خاصة' && _special == 'بدون هوية';
  bool get _editNoId => _editCategory == 'خاصة' && _editSpecial == 'بدون هوية';
  bool get _isDirty => _selectedId != null && _editSnapshot() != _editBaseline;
  bool get _isEmergency => _entry == 'إسعافي';
  bool get _isKinship => _legal == 'قرابة داخلية';
  bool get _needsAdmin => BookingCatalog.requiresAdmin(_entity);
  bool get _adminIsDropdown => _entity == 'وزارة الداخلية';

  List<String> get _entities {
    final raw = _entityList.isNotEmpty ? _entityList : BookingCatalog.entities;
    return [for (final e in raw) if (e != 'أخرى') e];
  }

  List<String> get _admins =>
      _authorityList.isNotEmpty ? _authorityList : BookingCatalog.interiorAdmins;

  List<String> get _governorates =>
      _governorateList.isNotEmpty ? _governorateList : BookingCatalog.governorates;

  List<String> get _clinics => _clinicList;

  List<Map<String, dynamic>> get _todayBookings {
    final today = _todayIso();
    return [for (final b in _bookings) if ((b['date']?.toString() ?? '') == today) b];
  }

  List<Map<String, dynamic>> get _filteredBookings {
    final q = _bookingQuery.text.trim().toLowerCase();
    Iterable<Map<String, dynamic>> list = _todayBookings;
    list = switch (_filter) {
      _BookingFilter.pending => list.where(_isPending),
      _BookingFilter.arrived => list.where(_isArrived),
      _BookingFilter.noshow => list.where(_isNoShow),
    };
    if (q.isEmpty) return list.toList();
    return list.where((b) {
      final code = (b['code']?.toString() ?? '').toLowerCase();
      final name = (b['patientName']?.toString() ?? '').toLowerCase();
      return code.contains(q) || name.contains(q);
    }).toList();
  }

  int get _countPending => _todayBookings.where(_isPending).length;
  int get _countArrived => _todayBookings.where(_isArrived).length;
  int get _countNoShow => _todayBookings.where(_isNoShow).length;

  bool _isPending(Map<String, dynamic> b) {
    final s = (b['status']?.toString() ?? '').toLowerCase();
    return s == 'reserved' || s == 'محجوز' || s.isEmpty;
  }

  bool _isArrived(Map<String, dynamic> b) {
    final s = (b['status']?.toString() ?? '').toLowerCase();
    final ar = b['statusAr']?.toString() ?? '';
    return s == 'arrived' || ar == 'حضر';
  }

  bool _isNoShow(Map<String, dynamic> b) {
    final s = (b['status']?.toString() ?? '').toLowerCase();
    final ar = b['statusAr']?.toString() ?? '';
    return s == 'noshow' || ar == 'لم يحضر';
  }

  Timer? _timer;
  final _bookingWatcher = NewItemWatcher();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entity = _entities.first;
    _legal = BookingCatalog.legalOfEntity[_entity] ?? 'مدني';
    _governorate = _governorates.first;
    _bootstrap();
    _armTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _name.dispose();
    _nationalId.dispose();
    _age.dispose();
    _residence.dispose();
    _bookingQuery.dispose();
    _specialNote.dispose();
    _adminFree.dispose();
    _kinName.dispose();
    _editSpecialNote.dispose();
    _editNationalId.dispose();
    _editName.dispose();
    _editAge.dispose();
    _editResidence.dispose();
    _editAdminFree.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _armTimer();
      _reloadAll(silent: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _paused = true;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_paused) _reloadAll(silent: true);
    });
  }

  String _editSnapshot() => [
        _editCategory,
        _editCategory == 'خاصة' ? _editSpecial : '',
        _editSpecialNote.text.trim(),
        _editNationalId.text.trim(),
        _editName.text.trim(),
        _editAge.text.trim(),
        _editResidence.text.trim(),
        _editGovernorate,
        _editEntity,
        _editAdmin.trim(),
        _editLegal,
        _editClinic,
      ].join('\u001f');

  String? _affiliation(String entity, String admin, {TextEditingController? free}) {
    final freeText = free?.text.trim() ?? admin.trim();
    if (entity == 'وزارة الداخلية') {
      if (admin.trim().isEmpty) return null;
      return '$entity — ${admin.trim()}';
    }
    if (entity == 'وزارة الدفاع') {
      if (freeText.isEmpty) return null;
      return '$entity — $freeText';
    }
    return entity;
  }

  (String, String) _parseAffiliation(String? raw) {
    if (raw == null || raw.trim().isEmpty) return (_entities.first, '');
    final text = raw.trim();
    if (_entities.contains(text) && text != 'وزارة الداخلية' && text != 'وزارة الدفاع') {
      return (text, '');
    }
    final sep = text.indexOf(' — ');
    if (sep > 0) {
      final entity = text.substring(0, sep).trim();
      final admin = text.substring(sep + 3).trim();
      if (_entities.contains(entity)) return (entity, admin);
    }
    if (_admins.contains(text)) return ('وزارة الداخلية', text);
    return (_entities.contains('مدني') ? 'مدني' : _entities.first, '');
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      await _loadCatalog();
      await _reloadAll(silent: true);
    } catch (e) {
      if (mounted) _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCatalog() async {
    Map<String, dynamic> data;
    try {
      data = await widget.api.bookingAvailability(
        widget.facilityId,
        date: _todayIso(),
      );
    } on ApiException {
      // Reception clerks cannot hit /stations/.../availability — use the shared catalog.
      data = await widget.api.bookingCatalog(widget.facilityId);
    }
    final clinics = <String>[];
    final rawClinics = data['clinics'];
    if (rawClinics is List) {
      for (final c in rawClinics) {
        if (c is Map) {
          final name = (c['clinic'] ?? c['name'] ?? '').toString().trim();
          final enabled = c['enabled'] != false && c['isEnabled'] != false;
          if (name.isNotEmpty && enabled && !clinics.contains(name)) clinics.add(name);
        } else {
          final name = c?.toString().trim() ?? '';
          if (name.isNotEmpty && !clinics.contains(name)) clinics.add(name);
        }
      }
    }
    _clinicList = clinics;
    _authorityList = _strings(data['authorities']);
    _governorateList = _strings(data['governorates']);
    _entityList = _strings(data['entities']).where((e) => e != 'أخرى').toList();

    if (!_entities.contains(_entity)) {
      _entity = _entities.first;
      _legal = BookingCatalog.legalOfEntity[_entity] ?? 'مدني';
    }
    if (!_governorates.contains(_governorate)) _governorate = _governorates.first;
    if (_clinic.isEmpty || !_clinics.contains(_clinic)) {
      _clinic = _clinics.isEmpty ? '' : _clinics.first;
    }
    if (_editClinic.isEmpty || (!_clinics.contains(_editClinic) && _editClinic != 'الإسعاف')) {
      _editClinic = _clinics.isEmpty ? '' : _clinics.first;
    }
  }

  Future<void> _reloadAll({bool silent = false}) async {
    if (silent && (_loading || _saving || _dossierBusy || _busyBookings.isNotEmpty)) return;
    if (!silent) setState(() => _loading = true);
    try {
      if (_clinicList.isEmpty) await _loadCatalog();
      final bookings = await widget.api.pendingReceptionBookings(widget.facilityId);
      final queue = await widget.api.receptionQueue(widget.facilityId);
      if (!mounted) return;
      final maps = [for (final e in bookings) Map<String, dynamic>.from(e as Map)];
      final fresh = _bookingWatcher.diff(maps);
      NotificationService.instance.newPatients(
        fresh.map((b) => b['patientName']?.toString() ?? '').where((n) => n.isNotEmpty).toList(),
        where: 'حجوزات الاستقبال',
      );
      setState(() {
        _bookings = maps;
        _queue = [for (final e in queue) Map<String, dynamic>.from(e as Map)];
        _lastUpdated = DateTime.now();
        if (_selectedId != null && !_queue.any((x) => x['id']?.toString() == _selectedId)) {
          _clearSelection(force: true);
        }
      });
    } catch (e) {
      if (!mounted || silent) return;
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _setFlash(String msg, {bool error = false}) {
    setState(() {
      _flash = msg;
      _flashError = error;
    });
  }

  bool _validateForm() {
    final errName = _validateName(_name.text);
    final errNid = _noId || _isEmergency && _nationalId.text.trim().isEmpty
        ? null
        : _validateNationalId(_nationalId.text, required: !_noId && !_isEmergency);
    final errAge = _validateAge(_age.text);
    String? errKin;
    String? errAdmin;
    if (!_isEmergency) {
      if (_isKinship) {
        if (_kinName.text.trim().isEmpty) errKin = 'أدخل اسم المنتسب';
      }
      if (_needsAdmin) {
        final adminVal = _adminIsDropdown ? _admin : _adminFree.text.trim();
        if (adminVal.isEmpty) {
          errAdmin = _entity == 'وزارة الداخلية' ? 'اختر الإدارة' : 'أدخل الوحدة الإدارية';
        }
      }
      if (_clinic.isEmpty) {
        _setFlash('لا توجد عيادات مفعّلة من الخادم', error: true);
        return false;
      }
    }
    setState(() {
      _errName = errName;
      _errNid = errNid;
      _errAge = errAge;
      _errKin = errKin;
      _errAdmin = errAdmin;
    });
    return errName == null && errNid == null && errAge == null && errKin == null && errAdmin == null;
  }

  Future<void> _startEmergency() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استمارة إسعافية'),
        content: const Text('فتح استمارة إسعافية وتحويل للإسعاف؟'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: MsdTokens.danger),
                child: const Text('تأكيد'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _entry = 'إسعافي';
      _errAdmin = null;
    });
    await _open();
  }

  Future<void> _open() async {
    if (!_validateForm()) return;

    setState(() {
      _saving = true;
      _flash = null;
    });
    try {
      final affiliation = _isEmergency
          ? null
          : _affiliation(_entity, _admin, free: _adminFree);
      if (!_isEmergency && affiliation == null && _needsAdmin) {
        setState(() => _errAdmin = 'أكمل بيانات الجهة');
        return;
      }
      final row = await widget.api.openReceptionCase(
        widget.facilityId,
        entryType: _entry,
        category: _category,
        specialType: _category == 'خاصة' ? _special : null,
        specialNote: _specialNote.text.trim().isEmpty ? null : _specialNote.text.trim(),
        nationalId: _noId || _nationalId.text.trim().isEmpty ? null : _nationalId.text.trim(),
        patientName: _name.text.trim(),
        age: int.tryParse(_age.text),
        residence: _residence.text.trim().isEmpty ? null : _residence.text.trim(),
        governorate: _governorate,
        adminUnit: affiliation,
        bookedClinic: _isEmergency ? 'الإسعاف' : _clinic,
        legal: _isEmergency ? null : _legal,
      );
      _name.clear();
      _nationalId.clear();
      _age.clear();
      _residence.clear();
      _specialNote.clear();
      _kinName.clear();
      _setFlash('تم فتح ${row['caseNumber']}');
      await _reloadAll();
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _arrive(Map<String, dynamic> b) async {
    final id = b['id'].toString();
    setState(() => _busyBookings.add(id));
    try {
      final row = await widget.api.arriveReceptionBooking(widget.facilityId, id);
      await _reloadAll(silent: true);
      if (!mounted) return;
      final msg = 'وصل ${b['code']} — فُتحت ${row['caseNumber']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 5),
        ),
      );
      _setFlash(msg);
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busyBookings.remove(id));
    }
  }

  Future<void> _noShow(Map<String, dynamic> b) async {
    final name = b['patientName']?.toString() ?? '';
    final code = b['code']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل عدم الحضور'),
        content: Text('تسجيل «لم يحضر» للمراجع $name — رمز $code؟'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: MsdTokens.danger),
                child: const Text('لم يحضر'),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = b['id'].toString();
    setState(() => _busyBookings.add(id));
    try {
      await widget.api.noShowReceptionBooking(widget.facilityId, id);
      _setFlash('تم تسجيل $code كـ «لم يحضر»');
      await _reloadAll(silent: true);
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busyBookings.remove(id));
    }
  }

  void _toggleCase(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id == null) return;
    if (_selectedId == id) {
      _tryClose();
      return;
    }
    if (_selectedId != null && _isDirty) {
      setState(() {
        _dossierError = true;
        _dossierMsg = 'يوجد تعديلات غير محفوظة — احفظ أولاً.';
      });
      return;
    }
    _selectCase(item);
  }

  void _selectCase(Map<String, dynamic> item) {
    final parsed = _parseAffiliation(item['adminUnit']?.toString());
    final clinic = item['bookedClinic']?.toString() ?? '';
    setState(() {
      _selectedId = item['id']?.toString();
      _editCategory = (item['category']?.toString().isNotEmpty == true) ? item['category'].toString() : 'عامة';
      _editSpecial = (item['specialType']?.toString().isNotEmpty == true)
          ? item['specialType'].toString()
          : specialTypes.first;
      _editSpecialNote.text = item['specialNote']?.toString() ?? '';
      _editNationalId.text = item['nationalId']?.toString() ?? '';
      _editName.text = item['patientName']?.toString() ?? '';
      _editAge.text = item['age']?.toString() ?? '';
      _editResidence.text = item['residence']?.toString() ?? '';
      _editGovernorate = (item['governorate']?.toString().isNotEmpty == true)
          ? item['governorate'].toString()
          : _governorates.first;
      _editEntity = parsed.$1;
      _editAdmin = parsed.$2;
      _editAdminFree.text = parsed.$2;
      final legalRaw = item['legal']?.toString() ?? '';
      _editLegal = legalRaw.isNotEmpty
          ? legalRaw
          : (BookingCatalog.legalOfEntity[_editEntity] ?? 'مدني');
      _editClinic = clinic.isEmpty || clinic == 'الإسعاف'
          ? (_clinics.isEmpty ? clinic : _clinics.first)
          : clinic;
      _editBaseline = _editSnapshot();
      _dossierMsg = null;
      _dossierError = false;
    });
  }

  void _tryClose() {
    if (_isDirty) {
      setState(() {
        _dossierError = true;
        _dossierMsg = 'يوجد تعديلات غير محفوظة — احفظ أولاً.';
      });
      return;
    }
    _clearSelection(force: true);
  }

  void _clearSelection({bool force = false}) {
    if (!force && _isDirty) {
      _tryClose();
      return;
    }
    setState(() {
      _selectedId = null;
      _editBaseline = '';
      _dossierMsg = null;
      _dossierError = false;
    });
  }

  Future<void> _primaryDossier() async {
    if (_isDirty) {
      await _saveDossier();
    } else {
      await _sendSelected();
    }
  }

  Future<void> _saveDossier() async {
    if (_selectedId == null) return;
    if (!_isDirty) {
      setState(() {
        _dossierError = false;
        _dossierMsg = 'لا توجد تعديلات للحفظ.';
      });
      return;
    }
    final errName = _validateName(_editName.text);
    final errNid = _editNoId
        ? null
        : _validateNationalId(_editNationalId.text, required: true);
    final errAge = _validateAge(_editAge.text);
    if (errName != null || errNid != null || errAge != null) {
      setState(() {
        _dossierError = true;
        _dossierMsg = errName ?? errNid ?? errAge;
      });
      return;
    }
    setState(() => _dossierBusy = true);
    try {
      final affiliation = _affiliation(
        _editEntity,
        _editAdmin,
        free: _editAdminFree,
      );
      if (affiliation == null && BookingCatalog.requiresAdmin(_editEntity)) {
        setState(() {
          _dossierError = true;
          _dossierMsg = 'أكمل بيانات الجهة';
        });
        return;
      }
      final row = await widget.api.updateReceptionCase(
        widget.facilityId,
        _selectedId!,
        entryType: 'حجز مسبق',
        category: _editCategory,
        specialType: _editCategory == 'خاصة' ? _editSpecial : null,
        specialNote: _editSpecialNote.text.trim().isEmpty ? null : _editSpecialNote.text.trim(),
        nationalId: _editNoId || _editNationalId.text.trim().isEmpty ? null : _editNationalId.text.trim(),
        patientName: _editName.text.trim(),
        age: int.tryParse(_editAge.text),
        residence: _editResidence.text.trim().isEmpty ? null : _editResidence.text.trim(),
        governorate: _editGovernorate,
        adminUnit: affiliation,
        bookedClinic: _editClinic,
        legal: _editLegal,
      );
      setState(() {
        _editBaseline = _editSnapshot();
        _dossierError = false;
        _dossierMsg = 'تم حفظ تعديلات ${row['caseNumber']}.';
      });
      await _reloadAll(silent: true);
    } catch (e) {
      setState(() {
        _dossierError = true;
        _dossierMsg = ApiException.messageOf(e);
      });
    } finally {
      if (mounted) setState(() => _dossierBusy = false);
    }
  }

  Future<void> _sendSelected() async {
    if (_selectedId == null) return;
    if (_isDirty) {
      setState(() {
        _dossierError = true;
        _dossierMsg = 'يوجد تعديلات غير محفوظة — احفظ أولاً.';
      });
      return;
    }
    setState(() => _dossierBusy = true);
    try {
      final caseNumber = _queue
          .firstWhere((x) => x['id']?.toString() == _selectedId, orElse: () => {})['caseNumber'];
      await widget.api.sendReceptionToClinic(
        widget.facilityId,
        _selectedId!,
        clinic: _editClinic,
      );
      _clearSelection(force: true);
      _setFlash('تم تحويل ${caseNumber ?? ''} إلى عيادة $_editClinic');
      await _reloadAll(silent: true);
    } catch (e) {
      setState(() {
        _dossierError = true;
        _dossierMsg = ApiException.messageOf(e);
      });
    } finally {
      if (mounted) setState(() => _dossierBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StationBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: StationCompactHeader(
                  station: 'الاستقبال',
                  hospital: 'مشفى الشرطة في حرستا',
                  onLogout: widget.onLogout,
                  onSettings: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('إعدادات المحطة من قائمة التطبيق')),
                    );
                  },
                ),
              ),
              if (_lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'آخر تحديث ${_hhmm(_lastUpdated!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MsdColors.sub,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: MsdColors.cyan,
                  onRefresh: () => _reloadAll(),
                  child: _loading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: const [
                            _SkeletonBox(height: 88),
                            SizedBox(height: 12),
                            _SkeletonBox(height: 160),
                            SizedBox(height: 12),
                            _SkeletonBox(height: 220),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                          children: [
                            if (_flash != null) ...[
                              _banner(_flash!, error: _flashError),
                              const SizedBox(height: 12),
                            ],
                            _buildBookings(),
                            const SizedBox(height: 12),
                            _buildForm(),
                            const SizedBox(height: 12),
                            _buildQueue(),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, {required bool error}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? MsdTokens.dangerWash : MsdTokens.successWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error ? MsdTokens.dangerWash : MsdTokens.successWash),
      ),
      child: Text(
        text,
        maxLines: 3,
        softWrap: true,
        style: TextStyle(
          color: error ? MsdColors.danger : MsdColors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBookings() {
    return StationSection(
      title: 'حجوزات اليوم',
      trailing: Text(
        '${_todayBookings.length}',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MsdColors.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'لم يصل ($_countPending)',
                selected: _filter == _BookingFilter.pending,
                onTap: () => setState(() => _filter = _BookingFilter.pending),
              ),
              _FilterChip(
                label: 'وصل ($_countArrived)',
                selected: _filter == _BookingFilter.arrived,
                onTap: () => setState(() => _filter = _BookingFilter.arrived),
              ),
              _FilterChip(
                label: 'لم يحضر ($_countNoShow)',
                selected: _filter == _BookingFilter.noshow,
                onTap: () => setState(() => _filter = _BookingFilter.noshow),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bookingQuery,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'بحث بالاسم أو رمز الحجز',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          if (_filteredBookings.isEmpty)
            _EmptyState(
              icon: Icons.event_busy_rounded,
              message: switch (_filter) {
                _BookingFilter.pending => 'لا حجوزات بانتظار الحضور',
                _BookingFilter.arrived => 'لا حجوزات وصلت بعد',
                _BookingFilter.noshow => 'لا حجوزات «لم يحضر»',
              },
            )
          else
            ..._filteredBookings.map(_bookingCard),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final id = b['id'].toString();
    final busy = _busyBookings.contains(id);
    final pending = _isPending(b);
    final side = (b['adminUnit']?.toString().isNotEmpty == true)
        ? '${b['entity']} — ${b['adminUnit']}'
        : '${b['entity'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MsdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${b['code']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MsdColors.teal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${b['slot'] ?? ''} · ${b['statusAr'] ?? ''}',
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(fontSize: 12, color: MsdColors.faint),
                ),
              ),
            ],
          ),
          Text(
            '${b['patientName']}',
            maxLines: 2,
            softWrap: true,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(
            'عيادة ${b['clinic']} · $side',
            maxLines: 2,
            softWrap: true,
            style: TextStyle(fontSize: 12, color: MsdColors.sub),
          ),
          if (pending) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => _arrive(b),
                  child: const Text('وصل'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => _noShow(b),
                  style: OutlinedButton.styleFrom(foregroundColor: MsdColors.danger),
                  child: const Text('لم يحضر'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return StationSection(
      title: 'استمارة جديدة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _saving ? null : _startEmergency,
            style: FilledButton.styleFrom(
              backgroundColor: MsdTokens.danger,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('حالة إسعافية'),
          ),
          const SizedBox(height: 12),
          if (!_isEmergency)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _entry = 'حجز مسبق'),
                child: Text(
                  _entry == 'حجز مسبق' ? 'نوع الدخول: حجز مسبق' : 'العودة لحجز مسبق',
                ),
              ),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _entry = 'حجز مسبق'),
                child: const Text('إلغاء الوضع الإسعافي'),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CatChip(
                  label: 'عامة',
                  selected: _category == 'عامة',
                  onTap: () => setState(() => _category = 'عامة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CatChip(
                  label: 'خاصة',
                  selected: _category == 'خاصة',
                  onTap: () => setState(() => _category = 'خاصة'),
                ),
              ),
            ],
          ),
          if (_category == 'خاصة') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialTypes
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _special == s,
                        onSelected: (_) => setState(() {
                          _special = s;
                          _errNid = null;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            MsdTextField(
              controller: _specialNote,
              labelText: 'ملاحظة الحالة الخاصة',
              hintText: _special == 'بدون هوية' ? 'علامات مميزة / جهة الإحضار...' : 'رقم الوثيقة أو ملاحظة',
            ),
          ],
          const SizedBox(height: 12),
          MsdTextField(
            controller: _name,
            labelText: 'الاسم الثلاثي',
            hintText: _noId ? 'مثال: مجهول الهوية ذكر' : 'الاسم الأول · الأب · العائلة',
            errorText: _errName,
            onChanged: (_) {
              if (_errName != null) setState(() => _errName = null);
            },
          ),
          if (!_noId) ...[
            const SizedBox(height: 12),
            MsdTextField(
              controller: _nationalId,
              labelText: 'الرقم الوطني',
              keyboardType: TextInputType.number,
              forceLtr: true,
              errorText: _errNid,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) {
                if (_errNid != null) setState(() => _errNid = null);
              },
            ),
          ],
          const SizedBox(height: 12),
          MsdTextField(
            controller: _age,
            labelText: 'العمر',
            keyboardType: TextInputType.number,
            forceLtr: true,
            errorText: _errAge,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) {
              if (_errAge != null) setState(() => _errAge = null);
            },
          ),
          if (!_isEmergency) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('gov-${_governorates.join('|')}'),
              isExpanded: true,
              initialValue: _governorates.contains(_governorate) ? _governorate : null,
              decoration: const InputDecoration(labelText: 'المحافظة'),
              items: _governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _governorate = v ?? _governorate),
            ),
            const SizedBox(height: 12),
            MsdTextField(controller: _residence, labelText: 'السكن'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('entity-${_entities.join('|')}'),
              isExpanded: true,
              initialValue: _entities.contains(_entity) ? _entity : null,
              decoration: const InputDecoration(labelText: 'الجهة'),
              items: _entities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() {
                _entity = v ?? _entity;
                _admin = '';
                _adminFree.clear();
                _legal = BookingCatalog.legalOfEntity[_entity] ?? 'مدني';
                _errAdmin = null;
              }),
            ),
            if (_adminIsDropdown) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('admin-${_admins.join('|')}'),
                isExpanded: true,
                initialValue: _admin.isEmpty ? null : _admin,
                decoration: InputDecoration(labelText: 'الإدارة', errorText: _errAdmin),
                items: _admins.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() {
                  _admin = v ?? '';
                  _errAdmin = null;
                }),
              ),
            ] else if (_needsAdmin) ...[
              const SizedBox(height: 12),
              MsdTextField(
                controller: _adminFree,
                labelText: 'الوحدة',
                errorText: _errAdmin,
                onChanged: (_) {
                  if (_errAdmin != null) setState(() => _errAdmin = null);
                },
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('legal-$_entity-$_legal'),
              isExpanded: true,
              initialValue: BookingCatalog.legalOptions.contains(_legal) ? _legal : null,
              decoration: const InputDecoration(labelText: 'الصفة الاعتبارية'),
              items: BookingCatalog.legalOptions
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() {
                _legal = v ?? _legal;
                _errKin = null;
              }),
            ),
            if (_isKinship) ...[
              const SizedBox(height: 12),
              MsdTextField(
                controller: _kinName,
                labelText: 'اسم المنتسب',
                errorText: _errKin,
                onChanged: (_) {
                  if (_errKin != null) setState(() => _errKin = null);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _kinship,
                decoration: const InputDecoration(labelText: 'صلة القرابة'),
                items: BookingCatalog.kinshipOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _kinship = v ?? _kinship),
              ),
            ],
            const SizedBox(height: 12),
            if (_clinics.isEmpty)
              InputDecorator(
                decoration: const InputDecoration(labelText: 'العيادة'),
                child: Text('لا توجد عيادات مفعّلة', style: TextStyle(color: MsdColors.sub)),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey('clinic-${_clinics.join('|')}'),
                isExpanded: true,
                initialValue: _clinics.contains(_clinic) ? _clinic : null,
                decoration: const InputDecoration(labelText: 'العيادة'),
                items: _clinics.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _clinic = v ?? _clinic),
              ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving
                ? null
                : () {
                    if (_isEmergency) {
                      _open();
                    } else {
                      setState(() => _entry = 'حجز مسبق');
                      _open();
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: _isEmergency ? MsdTokens.danger : MsdTokens.teal,
            ),
            child: Text(
              _saving
                  ? 'جاري الحفظ...'
                  : _isEmergency
                      ? 'تأكيد الاستمارة الإسعافية'
                      : 'فتح استمارة العيادة',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueue() {
    return StationSection(
      title: 'طابور التوجيه',
      trailing: Text(
        '${_queue.length}',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MsdColors.teal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_queue.isEmpty)
            const _EmptyState(
              icon: Icons.inbox_outlined,
              message: 'الطابور فارغ — بعد فتح الاستمارة تظهر الحالات هنا',
            )
          else
            ..._queue.map(_queueCard),
        ],
      ),
    );
  }

  Widget _queueCard(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    final open = id != null && id == _selectedId;
    final dirty = open && _isDirty;
    final name = open ? (_editName.text.isEmpty ? item['patientName'] : _editName.text) : item['patientName'];
    final meta =
        '${item['caseNumber']} · ${item['nationalId'] ?? 'بدون رقم وطني'} · ${item['age'] ?? '—'} سنة · ${open ? _editClinic : item['bookedClinic']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dirty ? MsdTokens.amberWash : MsdColors.line,
          width: open ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleCase(item),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name?.toString() ?? '',
                            maxLines: 2,
                            softWrap: true,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: MsdColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(meta, maxLines: 2, softWrap: true, style: TextStyle(fontSize: 12, color: MsdColors.sub)),
                          const SizedBox(height: 6),
                          MsdPill(
                            label: dirty
                                ? 'تعديل جارٍ'
                                : (item['statusAr']?.toString() ?? item['status']?.toString() ?? ''),
                            tone: dirty ? MsdPillTone.amber : MsdPillTone.sky,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: MsdColors.teal,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open) _queueEditor(item),
        ],
      ),
    );
  }

  Widget _queueEditor(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'إضبارة ${item['caseNumber']}',
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(fontSize: 14, color: MsdColors.teal, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: _tryClose, child: const Text('إغلاق')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CatChip(
                  label: 'عامة',
                  selected: _editCategory == 'عامة',
                  onTap: () => setState(() => _editCategory = 'عامة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CatChip(
                  label: 'خاصة',
                  selected: _editCategory == 'خاصة',
                  onTap: () => setState(() => _editCategory = 'خاصة'),
                ),
              ),
            ],
          ),
          if (_editCategory == 'خاصة') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialTypes
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _editSpecial == s,
                        onSelected: (_) => setState(() => _editSpecial = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            MsdTextField(
              controller: _editSpecialNote,
              labelText: 'ملاحظة الحالة الخاصة',
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          MsdTextField(
            controller: _editName,
            labelText: 'الاسم الثلاثي',
            onChanged: (_) => setState(() {}),
          ),
          if (!_editNoId) ...[
            const SizedBox(height: 10),
            MsdTextField(
              controller: _editNationalId,
              labelText: 'الرقم الوطني',
              keyboardType: TextInputType.number,
              forceLtr: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 10),
          MsdTextField(
            controller: _editAge,
            labelText: 'العمر',
            keyboardType: TextInputType.number,
            forceLtr: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _governorates.contains(_editGovernorate) ? _editGovernorate : null,
            decoration: const InputDecoration(labelText: 'المحافظة'),
            items: _governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _editGovernorate = v ?? _editGovernorate),
          ),
          const SizedBox(height: 10),
          MsdTextField(
            controller: _editResidence,
            labelText: 'السكن',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _entities.contains(_editEntity) ? _editEntity : null,
            decoration: const InputDecoration(labelText: 'الجهة'),
            items: _entities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() {
              _editEntity = v ?? _editEntity;
              _editAdmin = '';
              _editAdminFree.clear();
              _editLegal = BookingCatalog.legalOfEntity[_editEntity] ?? 'مدني';
            }),
          ),
          if (_editEntity == 'وزارة الداخلية') ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _editAdmin.isEmpty ? null : _editAdmin,
              decoration: const InputDecoration(labelText: 'الإدارة'),
              items: _admins.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) => setState(() => _editAdmin = v ?? ''),
            ),
          ] else if (_editEntity == 'وزارة الدفاع') ...[
            const SizedBox(height: 10),
            MsdTextField(
              controller: _editAdminFree,
              labelText: 'الوحدة',
              onChanged: (v) => setState(() => _editAdmin = v),
            ),
          ],
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: BookingCatalog.legalOptions.contains(_editLegal) ? _editLegal : null,
            decoration: const InputDecoration(labelText: 'الصفة الاعتبارية'),
            items: BookingCatalog.legalOptions
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _editLegal = v ?? _editLegal),
          ),
          const SizedBox(height: 10),
          if (_clinics.isEmpty)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'العيادة'),
              child: Text(_editClinic.isEmpty ? '—' : _editClinic),
            )
          else
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _clinics.contains(_editClinic) ? _editClinic : null,
              decoration: const InputDecoration(labelText: 'العيادة'),
              items: _clinics.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _editClinic = v ?? _editClinic),
            ),
          if (_dossierMsg != null) ...[
            const SizedBox(height: 10),
            _banner(_dossierMsg!, error: _dossierError),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _dossierBusy ? null : _primaryDossier,
            style: FilledButton.styleFrom(
              backgroundColor: _isDirty ? MsdTokens.amberFill : MsdTokens.teal,
            ),
            child: Text(_isDirty ? 'حفظ التعديلات' : 'تحويل إلى عيادة $_editClinic'),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: MsdTokens.cyanWash,
      checkmarkColor: MsdColors.teal,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? MsdColors.teal : MsdColors.sub,
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MsdColors.teal : MsdColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : MsdColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 40, color: MsdColors.sub),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            softWrap: true,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: MsdColors.sub),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MsdColors.line),
      ),
    );
  }
}
