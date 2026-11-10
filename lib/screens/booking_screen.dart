import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../api_client.dart';
import '../theme/app_theme.dart';
import '../theme/station_chrome.dart';
import '../ui/msd_notify.dart';
import '../ui/msd_text_field.dart';
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
  static const entities = ['وزارة الداخلية', 'وزارة الدفاع', 'موقوف', 'مدني', 'أخرى'];
  static const interiorAdmins = [
    'إدارة الخدمات الطبية',
    'قيادة شرطة دمشق',
    'قيادة شرطة ريف دمشق',
    'إدارة السجون',
    'إدارة المرور',
    'إدارة الهجرة والجوازات',
    'الأمن الجنائي',
  ];
  static const clinics = [
    'الداخلية', 'القلبية', 'الأطفال', 'حديثي الولادة', 'النسائية والتوليد', 'الجلدية',
    'الجراحة العامة', 'الجراحة العظمية', 'العينية', 'الأذنية', 'البولية', 'العصبية', 'السنية',
    'الكلية وغسيل الكلى', 'العلاج الفيزيائي',
  ];
  static const slots = [
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
    '11:00', '11:30', '12:00', '12:30', '13:00', '13:30',
  ];
  static const governorates = [
    'دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس',
    'إدلب', 'درعا', 'السويداء', 'القنيطرة', 'دير الزور', 'الرقة', 'الحسكة',
  ];
  final _bookedBy = TextEditingController();
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _age = TextEditingController();
  final _residence = TextEditingController();
  final _adminFree = TextEditingController();
  String _entity = entities.first;
  String _admin = '';
  String _clinic = clinics.first;
  String _slot = slots.first;
  late DateTime _date;
  String _governorate = 'دمشق';
  String _category = 'عامة';
  bool _tabList = false;
  bool _saving = false;
  bool _loading = true;
  String? _ok;
  Map<String, int> _remaining = {};
  List<dynamic> _list = const [];
  List<dynamic> _done = const [];
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _date = _nextOpenDay();
    _refreshAvailability();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }
  Future<void> _tick() async {
    if (_saving || _loading) return;
    await _refreshAvailability(silent: true);
    if (mounted && _tabList) await _loadList(silent: true);
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
    super.dispose();
  }
  DateTime _nextOpenDay() {
    var d = DateTime.now().add(const Duration(days: 1));
    if (d.weekday == DateTime.friday) d = d.add(const Duration(days: 1));
    return DateTime(d.year, d.month, d.day);
  }
  String get _dateIso =>
      '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';
  bool get _needsAdmin => _entity != 'وزارة الدفاع' && _entity != 'مدني';
  String get _adminUnit {
    if (!_needsAdmin) return '';
    if (_entity == 'وزارة الداخلية') return _admin;
    return _adminFree.text.trim();
  }
  String get _adminFieldLabel => switch (_entity) {
        'وزارة الداخلية' => 'الإدارة',
        'موقوف' => 'مكان التوقيف',
        _ => 'اسم الإدارة / الجهة',
      };
  String get _adminFieldHint =>
      _entity == 'موقوف' ? 'أي مكان يُحتجز فيه المراجع' : 'اسم الإدارة';
  Future<void> _refreshAvailability({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await widget.api.bookingAvailability(widget.facilityId, date: _dateIso);
      final clinicsRaw = (data['clinics'] as List?) ?? const [];
      _remaining = {
        for (final raw in clinicsRaw)
          (raw as Map)['clinic'].toString(): (raw['remaining'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _loadList({bool silent = false}) async {
    if (!silent) setState(() => _tabList = true);
    try {
      _list = await widget.api.bookingList(
        widget.facilityId,
        entity: _entity,
        adminUnit: _adminUnit,
      );
    } catch (e) {
      if (mounted && !silent) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() {});
    }
  }
  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _ok = null;
      _done = const [];
    });
    try {
      final nameParts = _name.text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (nameParts.length < 3) {
        throw Exception('أدخل الاسم الثلاثي كاملاً (ثلاثة أجزاء على الأقل).');
      }
      final created = await widget.api.createBookings(
        widget.facilityId,
        entity: _entity,
        adminUnit: _adminUnit,
        clinic: _clinic,
        appointmentDate: _dateIso,
        preferredSlot: _slot,
        bookedBy: _bookedBy.text.trim(),
        people: [
          {
            'patientName': nameParts.join(' '),
            'nationalId': _nationalId.text.trim().isEmpty ? null : _nationalId.text.trim(),
            'age': int.tryParse(_age.text),
            'governorate': _governorate,
            'residence': _residence.text.trim().isEmpty ? null : _residence.text.trim(),
            'category': _category,
            'specialType': null,
          },
        ],
      );
      _done = created;
      _ok = 'تم الحجز — أبلغ المراجع برمز الحجز';
      _name.clear();
      _nationalId.clear();
      _age.clear();
      _residence.clear();
      await _refreshAvailability();
      if (mounted) await MsdNotify.success(context, _ok!);
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    if (picked.weekday == DateTime.friday) {
      if (!mounted) return;
      await MsdNotify.error(context, 'يوم الجمعة عطلة — اختر يوماً آخر');
      return;
    }
    setState(() => _date = picked);
    await _refreshAvailability();
  }

  Future<void> _editBooking(Map<String, dynamic> booking) async {
    final name = TextEditingController(text: booking['patientName']?.toString() ?? '');
    final nationalId = TextEditingController(text: booking['nationalId']?.toString() ?? '');
    final age = TextEditingController(text: booking['age']?.toString() ?? '');
    final residence = TextEditingController(text: booking['residence']?.toString() ?? '');
    var clinic = booking['clinic']?.toString() ?? _clinic;
    var slot = booking['slot']?.toString() ?? _slot;
    var governorate = booking['governorate']?.toString() ?? _governorate;
    var category = booking['category']?.toString() ?? 'عامة';
    var date = DateTime.tryParse(booking['date']?.toString() ?? '') ?? _date;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('تعديل الحجز ${booking['code'] ?? ''}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: clinics.contains(clinic) ? clinic : clinics.first,
                    decoration: const InputDecoration(labelText: 'العيادة'),
                    items: clinics.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setLocal(() => clinic = v ?? clinic),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تاريخ الموعد'),
                    subtitle: Text(date.toIso8601String().split('T').first),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked == null) return;
                      if (picked.weekday == DateTime.friday) {
                        if (!ctx.mounted) return;
                        await MsdNotify.error(ctx, 'يوم الجمعة عطلة — اختر يوماً آخر');
                        return;
                      }
                      setLocal(() => date = picked);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: slots.contains(slot) ? slot : slots.first,
                    decoration: const InputDecoration(labelText: 'الوقت'),
                    items: slots.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setLocal(() => slot = v ?? slot),
                  ),
                  const SizedBox(height: 10),
                  MsdTextField(controller: name, labelText: 'الاسم الثلاثي'),
                  const SizedBox(height: 10),
                  MsdTextField(
                    controller: nationalId,
                    labelText: 'الرقم الوطني',
                    keyboardType: TextInputType.number,
                    forceLtr: true,
                  ),
                  const SizedBox(height: 10),
                  MsdTextField(
                    controller: age,
                    labelText: 'العمر',
                    keyboardType: TextInputType.number,
                    forceLtr: true,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: governorates.contains(governorate) ? governorate : governorates.first,
                    decoration: const InputDecoration(labelText: 'المحافظة'),
                    items: governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setLocal(() => governorate = v ?? governorate),
                  ),
                  const SizedBox(height: 10),
                  MsdTextField(controller: residence, labelText: 'السكن'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category == 'خاصة' ? 'خاصة' : 'عامة',
                    decoration: const InputDecoration(labelText: 'الفئة'),
                    items: const [
                      DropdownMenuItem(value: 'عامة', child: Text('عامة')),
                      DropdownMenuItem(value: 'خاصة', child: Text('خاصة')),
                    ],
                    onChanged: (v) => setLocal(() => category = v ?? category),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ التعديل')),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await widget.api.updateBooking(
        widget.facilityId,
        booking['id'].toString(),
        clinic: clinic,
        appointmentDate: date.toIso8601String().split('T').first,
        preferredSlot: slot,
        patientName: name.text.trim(),
        nationalId: nationalId.text.trim().isEmpty ? null : nationalId.text.trim(),
        age: int.tryParse(age.text.trim()),
        governorate: governorate,
        residence: residence.text.trim().isEmpty ? null : residence.text.trim(),
        category: category,
      );
      await _loadList();
      if (mounted) await MsdNotify.success(context, 'تم تعديل الحجز');
    } catch (e) {
      if (mounted) await MsdNotify.error(context, e.toString());
    }
  }
  @override
  Widget build(BuildContext context) {
    final left = _remaining[_clinic] ?? 20;
    return Scaffold(
      body: StationBackdrop(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: MsdColors.cyan))
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          StationHero(
                            brand: 'حجز الإدارات · حرستا',
                            headline: 'محطة حجز مستقلة للجهات',
                            subtitle: 'مشفى الشرطة في حرستا · إدارة الخدمات الطبية',
                            onLogout: widget.onLogout,
                          ),
                          const SizedBox(height: 14),
                          StationTabs(
                            newSelected: !_tabList,
                            listCount: _list.length,
                            onNew: () => setState(() => _tabList = false),
                            onList: _loadList,
                          ),
                          if (_ok != null) ...[
                            const SizedBox(height: 12),
                            SuccessBanner(
                              message: _ok!,
                              codes: _done.cast<Map<String, dynamic>>(),
                            ),
                          ],
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _tabList
                                ? KeyedSubtree(
                                    key: const ValueKey('list'),
                                    child: _buildList(),
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('form'),
                                    child: _buildForm(left),
                                  ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
  Widget _buildForm(int left) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StationSection(
          eyebrow: 'ENTITY',
          title: 'جهة الحجز',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _entity,
                decoration: const InputDecoration(labelText: 'الجهة'),
                items: entities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() {
                  _entity = v ?? _entity;
                  _admin = '';
                }),
              ),
              if (_entity == 'وزارة الداخلية') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _admin.isEmpty ? null : _admin,
                  decoration: InputDecoration(labelText: _adminFieldLabel),
                  items: interiorAdmins.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _admin = v ?? ''),
                ),
              ] else if (_needsAdmin) ...[
                const SizedBox(height: 12),
                MsdTextField(
                  controller: _adminFree,
                  labelText: _adminFieldLabel,
                  hintText: _adminFieldHint,
                ),
              ] else if (_entity == 'مدني') ...[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'الجهة'),
                  child: Text(
                    'مدني — بدون جهة تابعة',
                    style: GoogleFonts.tajawal(color: MsdColors.sub),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              MsdTextField(
                controller: _bookedBy,
                labelText: 'الموظف المسؤول',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StationSection(
          eyebrow: 'APPOINTMENT',
          title: 'الموعد والعيادة',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: left <= 0 ? const Color(0x14B42318) : const Color(0x140F8F86),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              left <= 0 ? 'ممتلئة' : 'متاح $left',
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: left <= 0 ? MsdColors.danger : MsdColors.cyan,
              ),
            ),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clinic,
                decoration: InputDecoration(labelText: 'العيادة — متاح $left'),
                items: clinics
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('$c · متاح ${_remaining[c] ?? 20}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _clinic = v ?? _clinic),
              ),
              const SizedBox(height: 12),
              Material(
                color: MsdColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
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
                                style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.sub),
                              ),
                              Text(
                                _dateIso,
                                style: GoogleFonts.ibmPlexMono(
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
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
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
              ),
              const SizedBox(height: 12),
              MsdTextField(
                controller: _nationalId,
                labelText: 'الرقم الوطني',
                keyboardType: TextInputType.number,
                forceLtr: true,
              ),
              const SizedBox(height: 12),
              MsdTextField(
                controller: _age,
                labelText: 'العمر',
                keyboardType: TextInputType.number,
                forceLtr: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _governorate,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _governorate = v ?? _governorate),
              ),
              const SizedBox(height: 12),
              MsdTextField(
                controller: _residence,
                labelText: 'السكن',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving || left <= 0 ? null : _submit,
          child: Text(_saving
              ? 'جاري الحجز...'
              : left <= 0
                  ? 'العيادة ممتلئة لهذا اليوم'
                  : 'تأكيد الحجز'),
        ),
      ],
    );
  }
  Widget _buildList() {
    if (_list.isEmpty) {
      return StationSection(
        eyebrow: 'BOOKINGS',
        title: 'حجوزات الإدارة',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'لا توجد حجوزات لهذه الجهة',
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(color: MsdColors.sub),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final raw in _list) ...[
          _BookingCard(
            booking: raw as Map<String, dynamic>,
            onEdit: raw['status'] == 'Reserved'
                ? () => _editBooking(Map<String, dynamic>.from(raw as Map))
                : null,
            onCancel: raw['status'] == 'Reserved'
                ? () async {
                    try {
                      await widget.api.cancelBooking(widget.facilityId, raw['id'].toString());
                      await _loadList();
                      if (mounted) await MsdNotify.success(context, 'تم إلغاء الحجز');
                    } catch (e) {
                      if (mounted) await MsdNotify.error(context, e.toString());
                    }
                  }
                : null,
          ),
          const SizedBox(height: 10),
        ],
      ],
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
            style: GoogleFonts.tajawal(
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
                  style: GoogleFonts.ibmPlexMono(
                    color: const Color(0xFF9FD8CF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${booking['patientName']}',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: MsdColors.ink,
                  ),
                ),
              ),
              Text(
                '${booking['statusAr']}',
                style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.sub),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'عيادة ${booking['clinic']} · ${booking['date']} · ${booking['slot']}',
            style: GoogleFonts.tajawal(fontSize: 13, color: MsdColors.sub),
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
