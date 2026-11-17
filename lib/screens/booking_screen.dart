import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../data/booking_catalog.dart';
import '../theme/app_theme.dart';
import '../theme/station_chrome.dart';
import '../ui/msd_notify.dart';
import '../ui/msd_text_field.dart';

// ───────────────────────── helpers ─────────────────────────

const _weekdaysAr = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _weekdayAr(DateTime d) => _weekdaysAr[d.weekday % 7];

/// Normalises a server list (strings or `{name|value|label}` maps) to unique strings.
List<String> _strings(dynamic raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final e in raw) {
    String? s;
    if (e is Map) {
      s = (e['name'] ?? e['value'] ?? e['label'])?.toString();
    } else if (e != null) {
      s = e.toString();
    }
    s = s?.trim();
    if (s != null && s.isNotEmpty && !out.contains(s)) out.add(s);
  }
  return out;
}

Set<int> _intSet(dynamic raw) {
  if (raw is! List) return <int>{};
  return {
    for (final e in raw)
      if (e is num) e.toInt() else if (int.tryParse('$e') != null) int.parse('$e'),
  };
}

Set<String> _dateSet(dynamic raw) {
  if (raw is! List) return <String>{};
  return {
    for (final e in raw)
      if ('$e'.length >= 10) '$e'.substring(0, 10),
  };
}

String? _validateName(String v) {
  final parts = v.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length < 3) return 'أدخل الاسم الثلاثي كاملاً (ثلاثة أجزاء على الأقل)';
  return null;
}

String? _validateNationalId(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
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

class _ClinicInfo {
  _ClinicInfo({
    required this.name,
    required this.remaining,
    required this.cap,
    required this.slots,
    required this.taken,
  });

  final String name;
  final int remaining;
  final int cap;
  final List<String> slots;
  final Set<String> taken;

  factory _ClinicInfo.fromJson(Map raw) => _ClinicInfo(
        name: '${raw['clinic'] ?? ''}',
        remaining: (raw['remaining'] as num?)?.toInt() ?? 0,
        cap: (raw['cap'] as num?)?.toInt() ?? 0,
        slots: _strings(raw['slots']),
        taken: _strings(raw['takenSlots']).toSet(),
      );

  List<String> get freeSlots => [for (final s in slots) if (!taken.contains(s)) s];
}

List<_ClinicInfo> _parseClinics(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final c in raw)
      if (c is Map && '${c['clinic'] ?? ''}'.isNotEmpty) _ClinicInfo.fromJson(c),
  ];
}

// ───────────────────────── screen ─────────────────────────

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.api,
    this.facilityId = 'harasta',
    this.onLogout,
  });

  final ApiClient api;
  final String facilityId;
  final Future<void> Function()? onLogout;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const _horizonDays = 30;

  final _bookedBy = TextEditingController();
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _age = TextEditingController();
  final _residence = TextEditingController();
  final _adminFree = TextEditingController();
  final _kinName = TextEditingController();
  final _search = TextEditingController();

  // Server-driven catalogue (falls back to BookingCatalog).
  Set<int> _daysOff = <int>{};
  Set<String> _closedDays = <String>{};
  List<String> _authorities = const [];
  List<String> _governorateList = const [];
  List<String> _entityList = const [];
  List<_ClinicInfo> _clinicData = const [];

  late String _entity;
  String _admin = '';
  String _legal = 'مدني';
  String _kinship = BookingCatalog.kinshipOptions.first;
  String _clinic = '';
  String _slot = '';
  String _governorate = '';
  String _category = 'عامة';
  late DateTime _date;

  bool _tabList = false;
  bool _saving = false;
  bool _loading = true;
  bool _listLoading = false;
  String? _ok;

  String? _errName;
  String? _errNid;
  String? _errAge;
  String? _errKin;

  List<dynamic> _list = const [];
  List<dynamic> _done = const [];
  Timer? _timer;

  List<String> get _entities =>
      _entityList.isNotEmpty ? _entityList : BookingCatalog.entities;
  List<String> get _admins =>
      _authorities.isNotEmpty ? _authorities : BookingCatalog.interiorAdmins;
  List<String> get _governorates =>
      _governorateList.isNotEmpty ? _governorateList : BookingCatalog.governorates;

  @override
  void initState() {
    super.initState();
    _entity = BookingCatalog.entities.first;
    _legal = BookingCatalog.legalOfEntity[_entity] ?? 'مدني';
    _governorate = BookingCatalog.governorates.first;
    _date = _dateOnly(DateTime.now().add(const Duration(days: 1)));
    _bootstrap();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bookedBy.dispose();
    _name.dispose();
    _nationalId.dispose();
    _age.dispose();
    _residence.dispose();
    _adminFree.dispose();
    _kinName.dispose();
    _search.dispose();
    super.dispose();
  }

  // ───── availability ─────

  bool _isSelectable(DateTime d) {
    final day = _dateOnly(d);
    return !_daysOff.contains(day.weekday % 7) && !_closedDays.contains(_iso(day));
  }

  DateTime? _nextOpenDay() {
    final today = _dateOnly(DateTime.now());
    for (var i = 1; i <= _horizonDays; i++) {
      final d = today.add(Duration(days: i));
      if (_isSelectable(d)) return d;
    }
    return null;
  }

  void _applyAvailability(Map<String, dynamic> data) {
    if (data['daysOff'] is List) _daysOff = _intSet(data['daysOff']);
    if (data['closedDays'] is List) _closedDays = _dateSet(data['closedDays']);
    _authorities = _strings(data['authorities']);
    _governorateList = _strings(data['governorates']);
    _entityList = _strings(data['entities']);
    _clinicData = _parseClinics(data['clinics']);
    _syncSelection();
  }

  /// Keeps entity / clinic / slot / governorate valid against the current lists.
  void _syncSelection() {
    final ents = _entities;
    if (!ents.contains(_entity)) {
      _entity = ents.first;
      _legal = BookingCatalog.legalOfEntity[_entity] ?? 'مدني';
      _admin = '';
    }
    final govs = _governorates;
    if (!govs.contains(_governorate)) _governorate = govs.first;
    if (_admin.isNotEmpty && !_admins.contains(_admin)) _admin = '';

    if (_clinicData.isEmpty) {
      _clinic = '';
      _slot = '';
      return;
    }
    if (!_clinicData.any((c) => c.name == _clinic)) _clinic = _clinicData.first.name;
    final slots = _currentClinic?.freeSlots ?? const <String>[];
    if (!slots.contains(_slot)) _slot = slots.isEmpty ? '' : slots.first;
  }

  _ClinicInfo? get _currentClinic {
    for (final c in _clinicData) {
      if (c.name == _clinic) return c;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    try {
      var data = await widget.api.bookingAvailability(widget.facilityId, date: _iso(_date));
      if (data['closedDays'] is! List) {
        try {
          final closed = await widget.api.bookingClosedDays(widget.facilityId);
          data = {...data, 'closedDays': closed};
        } catch (_) {}
      }
      _daysOff = _intSet(data['daysOff']);
      _closedDays = _dateSet(data['closedDays']);
      final open = _nextOpenDay();
      if (open != null && !_isSelectable(_date)) {
        _date = open;
        data = await widget.api.bookingAvailability(widget.facilityId, date: _iso(_date));
      }
      if (!mounted) return;
      _applyAvailability(data);
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) unawaited(_loadList(silent: true));
  }

  Future<void> _refreshAvailability({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await widget.api.bookingAvailability(widget.facilityId, date: _iso(_date));
      if (!mounted) return;
      setState(() => _applyAvailability(data));
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _tick() async {
    if (!mounted || _saving || _loading) return;
    if (_tabList) {
      await _loadList(silent: true);
    } else {
      await _refreshAvailability(silent: true);
    }
  }

  // ───── derived ─────

  bool get _needsAdmin => BookingCatalog.requiresAdmin(_entity);
  bool get _adminIsDropdown => _entity == 'وزارة الداخلية';
  bool get _isKinship => _legal == 'قرابة داخلية';

  String get _adminUnit {
    if (!_needsAdmin) return '';
    if (_adminIsDropdown) return _admin;
    return _adminFree.text.trim();
  }

  String get _adminFieldLabel => switch (_entity) {
        'وزارة الداخلية' => 'الإدارة',
        'موقوف' => 'مكان التوقيف',
        _ => 'اسم الإدارة / الجهة',
      };

  String get _adminFieldHint =>
      _entity == 'موقوف' ? 'أي مكان يُحتجز فيه المراجع' : 'اسم الإدارة';

  String get _residenceValue {
    final base = _residence.text.trim();
    if (!_isKinship) return base;
    final note = 'منتسب: ${_kinName.text.trim()} · صلة: $_kinship';
    return base.isEmpty ? note : '$base · $note';
  }

  // ───── actions ─────

  void _onEntityChanged(String? v) {
    if (v == null) return;
    setState(() {
      _entity = v;
      _admin = '';
      _adminFree.clear();
      _legal = BookingCatalog.legalOfEntity[v] ?? 'مدني';
      _errKin = null;
    });
  }

  Future<void> _loadList({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _tabList = true;
        _listLoading = true;
      });
    }
    try {
      final res = await widget.api.bookingList(
        widget.facilityId,
        entity: _entity,
        adminUnit: _adminUnit,
      );
      _list = res;
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e);
    } finally {
      if (mounted) setState(() => _listLoading = false);
    }
  }

  bool _validate() {
    final name = _validateName(_name.text);
    final nid = _validateNationalId(_nationalId.text);
    final age = _validateAge(_age.text);
    final kin = _isKinship && _kinName.text.trim().isEmpty ? 'أدخل اسم المنتسب' : null;
    setState(() {
      _errName = name;
      _errNid = nid;
      _errAge = age;
      _errKin = kin;
    });
    return name == null && nid == null && age == null && kin == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    if (_clinic.isEmpty || _slot.isEmpty) return;
    setState(() {
      _saving = true;
      _ok = null;
      _done = const [];
    });
    try {
      final nameParts =
          _name.text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      final residence = _residenceValue;
      final created = await widget.api.createBookings(
        widget.facilityId,
        entity: _entity,
        adminUnit: _adminUnit,
        clinic: _clinic,
        appointmentDate: _iso(_date),
        preferredSlot: _slot,
        bookedBy: _bookedBy.text.trim(),
        people: [
          {
            'patientName': nameParts.join(' '),
            'nationalId': _nationalId.text.trim().isEmpty ? null : _nationalId.text.trim(),
            'age': int.tryParse(_age.text.trim()),
            'governorate': _governorate,
            'residence': residence.isEmpty ? null : residence,
            'category': _category,
            'specialType': null,
            'legal': _legal,
          },
        ],
      );
      _done = created;
      _ok = 'تم الحجز — أبلغ المراجع برمز الحجز';
      _name.clear();
      _nationalId.clear();
      _age.clear();
      _residence.clear();
      _kinName.clear();
      await _refreshAvailability();
      if (mounted) await MsdNotify.success(context, _ok!);
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final open = _nextOpenDay();
    final initial = _isSelectable(_date) && !_date.isBefore(today) ? _date : open;
    if (initial == null) {
      await MsdNotify.error(context, 'لا توجد أيام متاحة للحجز حاليًا');
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: _horizonDays)),
      selectableDayPredicate: _isSelectable,
    );
    if (picked == null) return;
    setState(() => _date = _dateOnly(picked));
    await _refreshAvailability();
  }

  Future<void> _confirmCancel(Map<String, dynamic> b) async {
    final code = '${b['code'] ?? ''}';
    final name = '${b['patientName'] ?? ''}';
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'إلغاء الحجز',
          style: TextStyle(fontWeight: FontWeight.w800, color: MsdColors.ink),
        ),
        content: Text(
          'إلغاء الحجز $code للمراجع $name؟',
          style: TextStyle(height: 1.45, color: MsdColors.sub, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MsdColors.danger),
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await widget.api.cancelBooking(widget.facilityId, b['id'].toString());
      await _loadList(silent: true);
      if (mounted) await MsdNotify.success(context, 'تم إلغاء الحجز');
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e);
    }
  }

  Future<void> _editBooking(Map<String, dynamic> booking) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.96,
          minChildSize: 0.6,
          maxChildSize: 1.0,
          snap: true,
          builder: (ctx, scroll) => _EditBookingSheet(
            api: widget.api,
            facilityId: widget.facilityId,
            booking: booking,
            governorates: _governorates,
            daysOff: _daysOff,
            closedDays: _closedDays,
            scrollController: scroll,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.api.updateBooking(
        widget.facilityId,
        booking['id'].toString(),
        clinic: result['clinic'] as String,
        appointmentDate: result['date'] as String,
        preferredSlot: result['slot'] as String,
        patientName: result['name'] as String,
        nationalId: result['nationalId'] as String?,
        age: result['age'] as int?,
        governorate: result['governorate'] as String,
        residence: result['residence'] as String?,
        category: result['category'] as String,
      );
      await _loadList(silent: true);
      if (mounted) await MsdNotify.success(context, 'تم تعديل الحجز');
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e);
    }
  }

  // ───── build ─────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StationBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _CompactHeader(
                  station: 'حجز الإدارات',
                  hospital: 'مشفى حرستا',
                  onLogout: widget.onLogout,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: StationTabs(
                  newSelected: !_tabList,
                  listCount: _list.length,
                  onNew: () => setState(() => _tabList = false),
                  onList: _loadList,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: MsdColors.cyan))
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _tabList
                            ? KeyedSubtree(key: const ValueKey('list'), child: _buildList())
                            : KeyedSubtree(key: const ValueKey('form'), child: _buildForm()),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final clinic = _currentClinic;
    final left = clinic?.remaining ?? 0;
    final slots = clinic?.freeSlots ?? const <String>[];
    final clinicNames = [for (final c in _clinicData) c.name];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        if (_ok != null) ...[
          SuccessBanner(
            message: _ok!,
            codes: [for (final e in _done) Map<String, dynamic>.from(e as Map)],
          ),
          const SizedBox(height: 12),
        ],
        StationSection(
          eyebrow: 'ENTITY',
          title: 'جهة الحجز',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('entity-${_entities.join('|')}-$_entity'),
                isExpanded: true,
                initialValue: _entity,
                decoration: const InputDecoration(labelText: 'الجهة'),
                items: _entities
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: _onEntityChanged,
              ),
              if (_adminIsDropdown) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('admin-${_admins.join('|')}'),
                  isExpanded: true,
                  initialValue: _admin.isEmpty ? null : _admin,
                  decoration: InputDecoration(labelText: _adminFieldLabel),
                  items: _admins
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _admin = v ?? ''),
                ),
              ] else if (_needsAdmin) ...[
                const SizedBox(height: 12),
                MsdTextField(
                  controller: _adminFree,
                  labelText: _adminFieldLabel,
                  hintText: _adminFieldHint,
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
              MsdTextField(controller: _bookedBy, labelText: 'الموظف المسؤول'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StationSection(
          eyebrow: 'APPOINTMENT',
          title: 'الموعد والعيادة',
          trailing: clinic == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: left <= 0 ? MsdTokens.dangerWash : MsdTokens.cyanWash,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    left <= 0 ? 'ممتلئة' : 'متاح $left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: left <= 0 ? MsdColors.danger : MsdColors.cyan,
                    ),
                  ),
                ),
          child: Column(
            children: [
              _DateTile(
                date: _date,
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              if (clinicNames.isEmpty)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'العيادة'),
                  child: Text(
                    'لا توجد عيادات متاحة في هذا اليوم',
                    style: TextStyle(color: MsdColors.sub),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('clinic-${clinicNames.join('|')}-${_iso(_date)}'),
                  isExpanded: true,
                  initialValue: _clinic,
                  decoration: const InputDecoration(labelText: 'العيادة'),
                  items: _clinicData
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text('${c.name} · متاح ${c.remaining}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _clinic = v ?? _clinic;
                    final s = _currentClinic?.freeSlots ?? const <String>[];
                    if (!s.contains(_slot)) _slot = s.isEmpty ? '' : s.first;
                  }),
                ),
              const SizedBox(height: 12),
              if (slots.isEmpty)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'الوقت'),
                  child: Text(
                    clinic == null ? '—' : 'لا توجد أوقات متاحة',
                    style: TextStyle(color: MsdColors.sub),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('slot-$_clinic-${_iso(_date)}-${slots.join('|')}'),
                  isExpanded: true,
                  initialValue: _slot,
                  decoration: const InputDecoration(labelText: 'الوقت'),
                  items: slots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _slot = v ?? _slot),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StationSection(
          eyebrow: 'PATIENT',
          title: 'بيانات المراجع',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 12),
              MsdTextField(
                controller: _name,
                labelText: 'الاسم الثلاثي',
                hintText: 'الاسم الأول · الأب · العائلة',
                errorText: _errName,
                onChanged: (_) {
                  if (_errName != null) setState(() => _errName = null);
                },
              ),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('gov-${_governorates.join('|')}'),
                isExpanded: true,
                initialValue: _governorate,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: _governorates
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _governorate = v ?? _governorate),
              ),
              const SizedBox(height: 12),
              MsdTextField(controller: _residence, labelText: 'السكن'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving || clinic == null || left <= 0 || slots.isEmpty ? null : _submit,
          child: Text(
            _saving
                ? 'جاري الحجز...'
                : clinic == null
                    ? 'لا توجد عيادات متاحة'
                    : left <= 0 || slots.isEmpty
                        ? 'العيادة ممتلئة لهذا اليوم'
                        : 'تأكيد الحجز',
          ),
        ),
      ],
    );
  }

  // ───── list tab ─────

  String _groupLabel(DateTime d) {
    final diff = _dateOnly(d).difference(_dateOnly(DateTime.now())).inDays;
    if (diff == 0) return 'اليوم';
    if (diff == 1) return 'غدًا';
    return '${_weekdayAr(d)} ${_iso(d)}';
  }

  Widget _buildList() {
    final q = _search.text.trim().toLowerCase();
    final all = [for (final e in _list) Map<String, dynamic>.from(e as Map)];
    final filtered = q.isEmpty
        ? all
        : all
            .where((b) =>
                '${b['patientName'] ?? ''}'.toLowerCase().contains(q) ||
                '${b['code'] ?? ''}'.toLowerCase().contains(q))
            .toList();

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final b in filtered) {
      final raw = '${b['date'] ?? ''}';
      final key = raw.length >= 10 ? raw.substring(0, 10) : raw;
      groups.putIfAbsent(key, () => []).add(b);
    }
    final keys = groups.keys.toList()..sort();
    for (final k in keys) {
      groups[k]!.sort((a, b) => '${a['slot'] ?? ''}'.compareTo('${b['slot'] ?? ''}'));
    }

    return RefreshIndicator(
      color: MsdColors.cyan,
      onRefresh: () => _loadList(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          TextField(
            controller: _search,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو رمز الحجز',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          if (_listLoading && _list.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: MsdColors.cyan)),
            )
          else if (filtered.isEmpty)
            _EmptyState(
              icon: q.isEmpty ? Icons.event_busy_rounded : Icons.search_off_rounded,
              message: q.isEmpty ? 'لا توجد حجوزات لهذه الجهة' : 'لا نتائج مطابقة للبحث',
            )
          else
            for (final k in keys) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                child: Text(
                  DateTime.tryParse(k) == null ? k : _groupLabel(DateTime.parse(k)),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: MsdColors.cyan,
                  ),
                ),
              ),
              for (final b in groups[k]!) ...[
                _BookingCard(
                  booking: b,
                  onEdit: b['status'] == 'Reserved' ? () => _editBooking(b) : null,
                  onCancel: b['status'] == 'Reserved' ? () => _confirmCancel(b) : null,
                ),
                const SizedBox(height: 10),
              ],
            ],
        ],
      ),
    );
  }
}

// ───────────────────────── edit sheet ─────────────────────────

class _EditBookingSheet extends StatefulWidget {
  const _EditBookingSheet({
    required this.api,
    required this.facilityId,
    required this.booking,
    required this.governorates,
    required this.daysOff,
    required this.closedDays,
    required this.scrollController,
  });

  final ApiClient api;
  final String facilityId;
  final Map<String, dynamic> booking;
  final List<String> governorates;
  final Set<int> daysOff;
  final Set<String> closedDays;
  final ScrollController scrollController;

  @override
  State<_EditBookingSheet> createState() => _EditBookingSheetState();
}

class _EditBookingSheetState extends State<_EditBookingSheet> {
  late final TextEditingController _name;
  late final TextEditingController _nationalId;
  late final TextEditingController _age;
  late final TextEditingController _residence;

  late final String _origClinic;
  late final String _origSlot;
  late final String _origDate;

  late String _clinic;
  late String _slot;
  late String _governorate;
  late String _category;
  late DateTime _date;

  List<_ClinicInfo> _clinics = const [];
  bool _loading = true;

  String? _errName;
  String? _errNid;
  String? _errAge;

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _name = TextEditingController(text: '${b['patientName'] ?? ''}');
    _nationalId = TextEditingController(text: b['nationalId']?.toString() ?? '');
    _age = TextEditingController(text: b['age']?.toString() ?? '');
    _residence = TextEditingController(text: b['residence']?.toString() ?? '');
    _origClinic = '${b['clinic'] ?? ''}';
    _origSlot = '${b['slot'] ?? ''}';
    final rawDate = '${b['date'] ?? ''}';
    _origDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
    _clinic = _origClinic;
    _slot = _origSlot;
    _governorate = '${b['governorate'] ?? ''}';
    _category = '${b['category']}' == 'خاصة' ? 'خاصة' : 'عامة';
    _date = DateTime.tryParse(_origDate) ?? DateTime.now().add(const Duration(days: 1));
    _date = _dateOnly(_date);
    _loadAvailability();
  }

  @override
  void dispose() {
    _name.dispose();
    _nationalId.dispose();
    _age.dispose();
    _residence.dispose();
    super.dispose();
  }

  bool _isSelectable(DateTime d) {
    final day = _dateOnly(d);
    return !widget.daysOff.contains(day.weekday % 7) && !widget.closedDays.contains(_iso(day));
  }

  List<String> get _governorateOptions {
    final list = [...widget.governorates];
    if (_governorate.isNotEmpty && !list.contains(_governorate)) list.insert(0, _governorate);
    if (_governorate.isEmpty && list.isNotEmpty) _governorate = list.first;
    return list;
  }

  List<String> get _clinicNames {
    final names = [for (final c in _clinics) c.name];
    if (_clinic.isNotEmpty && !names.contains(_clinic)) names.insert(0, _clinic);
    return names;
  }

  List<String> get _slotOptions {
    _ClinicInfo? info;
    for (final c in _clinics) {
      if (c.name == _clinic) info = c;
    }
    final unchanged = _clinic == _origClinic && _iso(_date) == _origDate;
    if (info == null) return unchanged && _origSlot.isNotEmpty ? [_origSlot] : const [];
    final list = [
      for (final s in info.slots)
        if (!info.taken.contains(s) || (unchanged && s == _origSlot)) s,
    ];
    if (unchanged && _origSlot.isNotEmpty && !list.contains(_origSlot)) list.insert(0, _origSlot);
    return list;
  }

  void _syncSlot() {
    final slots = _slotOptions;
    if (!slots.contains(_slot)) _slot = slots.isEmpty ? '' : slots.first;
  }

  Future<void> _loadAvailability() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.bookingAvailability(widget.facilityId, date: _iso(_date));
      if (!mounted) return;
      _clinics = _parseClinics(data['clinics']);
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e);
    } finally {
      if (mounted) {
        setState(() {
          _syncSlot();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    var initial = _date;
    if (initial.isBefore(today) || !_isSelectable(initial)) {
      DateTime? found;
      for (var i = 1; i <= 30; i++) {
        final d = today.add(Duration(days: i));
        if (_isSelectable(d)) {
          found = d;
          break;
        }
      }
      if (found == null) {
        await MsdNotify.error(context, 'لا توجد أيام متاحة للحجز حاليًا');
        return;
      }
      initial = found;
    }
    final last = today.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: today,
      lastDate: initial.isAfter(last) ? initial : last,
      selectableDayPredicate: _isSelectable,
    );
    if (picked == null) return;
    setState(() => _date = _dateOnly(picked));
    await _loadAvailability();
  }

  void _save() {
    final name = _validateName(_name.text);
    final nid = _validateNationalId(_nationalId.text);
    final age = _validateAge(_age.text);
    setState(() {
      _errName = name;
      _errNid = nid;
      _errAge = age;
    });
    if (name != null || nid != null || age != null) return;
    final parts = _name.text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    Navigator.pop<Map<String, dynamic>>(context, {
      'clinic': _clinic,
      'date': _iso(_date),
      'slot': _slot,
      'name': parts.join(' '),
      'nationalId': _nationalId.text.trim().isEmpty ? null : _nationalId.text.trim(),
      'age': int.tryParse(_age.text.trim()),
      'governorate': _governorate,
      'residence': _residence.text.trim().isEmpty ? null : _residence.text.trim(),
      'category': _category,
    });
  }

  @override
  Widget build(BuildContext context) {
    final clinics = _clinicNames;
    final slots = _slotOptions;
    final govs = _governorateOptions;

    return Container(
      decoration: const BoxDecoration(
        color: MsdTokens.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: MsdColors.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'تعديل الحجز ${widget.booking['code'] ?? ''}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: MsdColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                _DateTile(date: _date, onTap: _pickDate),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(color: MsdColors.cyan),
                  ),
                if (clinics.isEmpty)
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'العيادة'),
                    child: Text(
                      'لا توجد عيادات متاحة في هذا اليوم',
                      style: TextStyle(color: MsdColors.sub),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('e-clinic-${clinics.join('|')}-${_iso(_date)}'),
                    isExpanded: true,
                    initialValue: clinics.contains(_clinic) ? _clinic : clinics.first,
                    decoration: const InputDecoration(labelText: 'العيادة'),
                    items: clinics.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() {
                      _clinic = v ?? _clinic;
                      _syncSlot();
                    }),
                  ),
                const SizedBox(height: 12),
                if (slots.isEmpty)
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'الوقت'),
                    child: Text('لا توجد أوقات متاحة', style: TextStyle(color: MsdColors.sub)),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey('e-slot-$_clinic-${_iso(_date)}-${slots.join('|')}'),
                    isExpanded: true,
                    initialValue: slots.contains(_slot) ? _slot : slots.first,
                    decoration: const InputDecoration(labelText: 'الوقت'),
                    items: slots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _slot = v ?? _slot),
                  ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                MsdTextField(
                  controller: _name,
                  labelText: 'الاسم الثلاثي',
                  errorText: _errName,
                  onChanged: (_) {
                    if (_errName != null) setState(() => _errName = null);
                  },
                ),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('e-gov-${govs.join('|')}'),
                  isExpanded: true,
                  initialValue: govs.contains(_governorate) ? _governorate : null,
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                  items: govs.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _governorate = v ?? _governorate),
                ),
                const SizedBox(height: 12),
                MsdTextField(controller: _residence, labelText: 'السكن'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: MsdColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading || _clinic.isEmpty || _slot.isEmpty ? null : _save,
                  child: const Text('حفظ التعديل'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── widgets ─────────────────────────

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({required this.station, required this.hospital, this.onLogout});

  final String station;
  final String hospital;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [MsdTokens.deep, MsdTokens.cyan, MsdTokens.deep],
        ),
      ),
      child: Row(
        children: [
          const MedicalMark(size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    station,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('·', style: TextStyle(color: MsdTokens.mintWash)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hospital,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MsdTokens.mintWash,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('إعدادات المحطة من قائمة التطبيق')),
              );
            },
            tooltip: 'الإعدادات',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
          if (onLogout != null)
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تسجيل الخروج'),
                    content: const Text('هل تريد تسجيل الخروج؟'),
                    actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    actionsAlignment: MainAxisAlignment.spaceBetween,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(backgroundColor: MsdColors.danger),
                        child: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await onLogout!();
              },
              tooltip: 'تسجيل الخروج',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MsdColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تاريخ الموعد',
                      style: TextStyle(fontSize: 12, color: MsdColors.sub),
                    ),
                    Text(
                      '${_weekdayAr(date)} · ${_iso(date)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: MsdColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.calendar_month_rounded, color: MsdColors.cyan),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: MsdColors.sub),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: MsdColors.sub,
            ),
          ),
        ],
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onEdit, this.onCancel});

  final Map<String, dynamic> booking;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MsdColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MsdColors.deepMid,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${booking['code']}',
                  style: TextStyle(
                    color: MsdTokens.mintWash,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${booking['patientName']}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: MsdColors.ink,
                  ),
                ),
              ),
              Text(
                '${booking['statusAr'] ?? ''}',
                style: TextStyle(fontSize: 12, color: MsdColors.sub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'عيادة ${booking['clinic']} · ${booking['date']} · ${booking['slot']}',
            style: TextStyle(fontSize: 13, color: MsdColors.sub),
          ),
          if (onEdit != null || onCancel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(foregroundColor: MsdColors.teal),
                    child: const Text('تعديل الحجز'),
                  ),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(foregroundColor: MsdColors.danger),
                    child: const Text('إلغاء الحجز'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
