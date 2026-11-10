import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/msd_widgets.dart';
import '../theme/station_chrome.dart';

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

class _ReceptionScreenState extends State<ReceptionScreen> {
  static const clinics = [
    'الداخلية',
    'القلبية',
    'الأطفال',
    'حديثي الولادة',
    'النسائية والتوليد',
    'الجلدية',
    'الجراحة العامة',
    'الجراحة العظمية',
    'العينية',
    'الأذنية',
    'البولية',
    'العصبية',
    'السنية',
    'الكلية وغسيل الكلى',
    'العلاج الفيزيائي',
  ];

  static const entities = [
    'وزارة الداخلية',
    'وزارة الدفاع',
    'موقوف',
    'مدني',
    'أخرى',
  ];

  static const interiorAdmins = [
    'إدارة الخدمات الطبية',
    'قيادة شرطة دمشق',
    'قيادة شرطة ريف دمشق',
    'إدارة السجون',
    'إدارة المرور',
    'إدارة الهجرة والجوازات',
    'الأمن الجنائي',
  ];

  static const governorates = [
    'دمشق',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'درعا',
    'السويداء',
    'القنيطرة',
    'دير الزور',
    'الرقة',
    'الحسكة',
  ];

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

  String _entry = 'حجز مسبق';
  String _category = 'عامة';
  String _special = specialTypes.first;
  String _governorate = 'ريف دمشق';
  String _entity = 'وزارة الداخلية';
  String _admin = '';
  String _clinic = 'القلبية';

  bool _saving = false;
  bool _loading = true;
  String? _flash;
  bool _flashError = false;

  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _bookings = [];
  final Set<String> _busyBookings = {};

  String? _selectedId;
  String _editCategory = 'عامة';
  String _editSpecial = specialTypes.first;
  final _editSpecialNote = TextEditingController();
  final _editNationalId = TextEditingController();
  final _editName = TextEditingController();
  final _editAge = TextEditingController();
  final _editResidence = TextEditingController();
  String _editGovernorate = 'ريف دمشق';
  String _editEntity = 'وزارة الداخلية';
  String _editAdmin = '';
  String _editClinic = 'القلبية';
  String _editBaseline = '';
  bool _dossierBusy = false;
  String? _dossierMsg;
  bool _dossierError = false;

  bool get _noId => _category == 'خاصة' && _special == 'بدون هوية';
  bool get _editNoId => _editCategory == 'خاصة' && _editSpecial == 'بدون هوية';
  bool get _isDirty => _selectedId != null && _editSnapshot() != _editBaseline;

  List<Map<String, dynamic>> get _filteredBookings {
    final q = _bookingQuery.text.trim();
    if (q.isEmpty) return _bookings;
    return _bookings.where((b) {
      final code = b['code']?.toString() ?? '';
      final name = b['patientName']?.toString() ?? '';
      final nid = b['nationalId']?.toString() ?? '';
      return code.contains(q) || name.contains(q) || nid.contains(q);
    }).toList();
  }

  Timer? _timer;
  final _bookingWatcher = NewItemWatcher();

  @override
  void initState() {
    super.initState();
    _reloadAll();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _reloadAll(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _nationalId.dispose();
    _age.dispose();
    _residence.dispose();
    _bookingQuery.dispose();
    _specialNote.dispose();
    _editSpecialNote.dispose();
    _editNationalId.dispose();
    _editName.dispose();
    _editAge.dispose();
    _editResidence.dispose();
    super.dispose();
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
        _editClinic,
      ].join('\u001f');

  String _affiliation(String entity, String admin) {
    if (entity == 'وزارة الداخلية' || entity == 'وزارة الدفاع' || entity == 'أخرى') {
      if (admin.trim().isEmpty) {
        throw Exception(entity == 'وزارة الداخلية'
            ? 'اختر الإدارة التابعة لوزارة الداخلية.'
            : 'أدخل الوحدة الإدارية.');
      }
      return '$entity — ${admin.trim()}';
    }
    return entity;
  }

  (String, String) _parseAffiliation(String? raw) {
    if (raw == null || raw.trim().isEmpty) return ('وزارة الداخلية', '');
    final text = raw.trim();
    if (entities.contains(text) && text != 'وزارة الداخلية' && text != 'وزارة الدفاع' && text != 'أخرى') {
      return (text, '');
    }
    final sep = text.indexOf(' — ');
    if (sep > 0) {
      final entity = text.substring(0, sep).trim();
      final admin = text.substring(sep + 3).trim();
      if (entities.contains(entity)) return (entity, admin);
    }
    if (interiorAdmins.contains(text)) return ('وزارة الداخلية', text);
    return ('أخرى', text);
  }

  Future<void> _reloadAll({bool silent = false}) async {
    if (silent && (_loading || _saving || _dossierBusy || _busyBookings.isNotEmpty)) return;
    if (!silent) setState(() => _loading = true);
    try {
      final bookings = await widget.api.pendingReceptionBookings(widget.facilityId);
      final queue = await widget.api.receptionQueue(widget.facilityId);
      if (!mounted) return;
      final fresh = _bookingWatcher.diff(bookings);
      NotificationService.instance.newPatients(
        fresh.map((b) => b['patientName']?.toString() ?? '').where((n) => n.isNotEmpty).toList(),
        where: 'حجوزات الاستقبال',
      );
      setState(() {
        _bookings = bookings.cast<Map<String, dynamic>>();
        _queue = queue.cast<Map<String, dynamic>>();
        if (_selectedId != null && !_queue.any((x) => x['id']?.toString() == _selectedId)) {
          _clearSelection(force: true);
        }
      });
    } catch (e) {
      if (!mounted || silent) return;
      _setFlash(e.toString().replaceFirst('Exception: ', ''), error: true);
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

  Future<void> _open() async {
    setState(() {
      _saving = true;
      _flash = null;
    });
    try {
      final affiliation = _entry == 'إسعافي' ? null : _affiliation(_entity, _admin);
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
        bookedClinic: _entry == 'إسعافي' ? 'الإسعاف' : _clinic,
      );
      _name.clear();
      _nationalId.clear();
      _age.clear();
      _residence.clear();
      _specialNote.clear();
      _setFlash('تم فتح ${row['caseNumber']}');
      await _reloadAll();
    } catch (e) {
      _setFlash(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _arrive(Map<String, dynamic> b) async {
    final id = b['id'].toString();
    setState(() => _busyBookings.add(id));
    try {
      final row = await widget.api.arriveReceptionBooking(widget.facilityId, id);
      _setFlash('وصل ${b['code']} — فُتحت ${row['caseNumber']}');
      await _reloadAll();
    } catch (e) {
      _setFlash(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busyBookings.remove(id));
    }
  }

  Future<void> _noShow(Map<String, dynamic> b) async {
    final id = b['id'].toString();
    setState(() => _busyBookings.add(id));
    try {
      await widget.api.noShowReceptionBooking(widget.facilityId, id);
      _setFlash('تم تسجيل ${b['code']} كـ «لم يحضر»');
      await _reloadAll();
    } catch (e) {
      _setFlash(e.toString().replaceFirst('Exception: ', ''), error: true);
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
      _editGovernorate =
          (item['governorate']?.toString().isNotEmpty == true) ? item['governorate'].toString() : 'ريف دمشق';
      _editEntity = parsed.$1;
      _editAdmin = parsed.$2;
      final clinic = item['bookedClinic']?.toString() ?? '';
      _editClinic = clinic.isEmpty || clinic == 'الإسعاف' ? clinics.first : clinic;
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
    setState(() => _dossierBusy = true);
    try {
      final affiliation = _affiliation(_editEntity, _editAdmin);
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
      );
      setState(() {
        _editBaseline = _editSnapshot();
        _dossierError = false;
        _dossierMsg = 'تم حفظ تعديلات ${row['caseNumber']}.';
      });
      await _reloadAll();
    } catch (e) {
      setState(() {
        _dossierError = true;
        _dossierMsg = e.toString().replaceFirst('Exception: ', '');
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
      await _reloadAll();
    } catch (e) {
      setState(() {
        _dossierError = true;
        _dossierMsg = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _dossierBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: MsdColors.mist,
      body: StationBackdrop(
        child: RefreshIndicator(
          onRefresh: _reloadAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStats(todayStr),
                    if (_flash != null) ...[
                      const SizedBox(height: 10),
                      _banner(_flash!, error: _flashError),
                    ],
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      _buildBookings(),
                      const SizedBox(height: 12),
                      _buildForm(),
                      const SizedBox(height: 12),
                      _buildQueue(),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1A6B8A), Color(0xFF145A75), Color(0xFF0F4A62)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'محطة مستقلة · مشفى الشرطة في حرستا',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFB8E0F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الاستقبال',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'تسجيل الوصول · فتح الإضبارة · توجيه العيادة',
                  style: GoogleFonts.tajawal(
                    color: const Color(0xFFD5EEF7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onLogout != null)
            TextButton(
              onPressed: widget.onLogout,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('خروج'),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(String todayStr) {
    return Row(
      children: [
        Expanded(child: _statCard('حجوزات بانتظار الحضور', '${_bookings.length}')),
        const SizedBox(width: 8),
        Expanded(child: _statCard('بالطابور للتوجيه', '${_queue.length}', accent: true)),
        const SizedBox(width: 8),
        Expanded(child: _statCard('اليوم', todayStr, soft: true)),
      ],
    );
  }

  Widget _statCard(String label, String value, {bool accent = false, bool soft = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: accent ? const Color(0x337EC8E3) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x384BA3C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.tajawal(fontSize: 11, color: MsdColors.sub, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: soft ? 13 : 22,
              fontWeight: FontWeight.w800,
              color: MsdColors.teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, {required bool error}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0x1AB42318) : const Color(0x1A2E9E6C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: error ? const Color(0x40B42318) : const Color(0x402E9E6C)),
      ),
      child: Text(
        text,
        style: GoogleFonts.tajawal(
          color: error ? MsdColors.danger : MsdColors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x334BA3C7)),
        boxShadow: const [
          BoxShadow(color: Color(0x141A6B8A), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildBookings() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('حجوزات الإدارات', style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.teal, fontWeight: FontWeight.w700)),
                    Text('وصول المراجعين المحجوزين', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800, color: MsdColors.ink)),
                  ],
                ),
              ),
              Text('${_bookings.length}', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: MsdColors.teal)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bookingQuery,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'بحث: رمز الحجز · الاسم · الرقم الوطني',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          if (_filteredBookings.isEmpty)
            _emptyBox('لا حجوزات بانتظار الحضور', 'عند وصول مراجع محجوز، سجّل وصوله من هنا.')
          else
            ..._filteredBookings.map(_bookingCard),
        ],
      ),
    );
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final id = b['id'].toString();
    final busy = _busyBookings.contains(id);
    final date = b['date']?.toString() ?? '';
    final isToday = date ==
        '${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final side = (b['adminUnit']?.toString().isNotEmpty == true)
        ? '${b['entity']} — ${b['adminUnit']}'
        : '${b['entity']}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFAFDFE), Color(0x73EAF6FB)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x334BA3C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${b['code']}',
                style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.w800, color: MsdColors.teal),
              ),
              const SizedBox(width: 8),
              Text('$date · ${b['slot']}', style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.faint)),
            ],
          ),
          Text('${b['patientName']}', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(
            'عيادة ${b['clinic']} · $side',
            style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.sub),
          ),
          Text(
            '${b['nationalId'] ?? 'بدون هوية'}',
            style: GoogleFonts.ibmPlexMono(fontSize: 11, color: MsdColors.faint),
          ),
          const SizedBox(height: 8),
          if (isToday)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _arrive(b),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                    child: const Text('وصل — فتح استمارة'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: busy ? null : () => _noShow(b),
                  child: const Text('لم يحضر'),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1F4BA3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('موعد لاحق', style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.teal, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('استمارة جديدة', style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.teal, fontWeight: FontWeight.w700)),
          Text('فتح استمارة عيادة', style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            'تسجيل مراجع جديد — يُحفظ مباشرة في قاعدة البيانات.',
            style: GoogleFonts.tajawal(color: MsdColors.sub, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _entryCard(
                  'حجز مسبق',
                  'محجوز من الإدارة',
                  _entry == 'حجز مسبق',
                  () => setState(() => _entry = 'حجز مسبق'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _entryCard(
                  'إسعافي',
                  'تحويل مباشر للإسعاف',
                  _entry == 'إسعافي',
                  () => setState(() => _entry = 'إسعافي'),
                  danger: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MsdSegmented(
            leftLabel: 'حالة عامة',
            rightLabel: 'حالة خاصة',
            leftSelected: _category == 'عامة',
            onLeft: () => setState(() => _category = 'عامة'),
            onRight: () => setState(() => _category = 'خاصة'),
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
                        selectedColor: MsdColors.amber,
                        labelStyle: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w700,
                          color: _special == s ? Colors.white : MsdColors.sub,
                        ),
                        onSelected: (_) => setState(() => _special = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            MsdFieldShell(
              label: 'ملاحظة الحالة الخاصة',
              child: TextField(
                controller: _specialNote,
                decoration: msdInputDecoration(
                  hint: _special == 'بدون هوية' ? 'علامات مميزة / جهة الإحضار...' : 'رقم الوثيقة أو ملاحظة',
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          MsdFieldShell(
            label: 'الرقم الوطني',
            child: TextField(
              controller: _nationalId,
              enabled: !_noId,
              keyboardType: TextInputType.number,
              decoration: msdInputDecoration(
                hint: _noId ? 'لا يحمل هوية' : '11 رقماً',
                enabled: !_noId,
                prefixIcon: const Icon(Icons.badge_outlined, color: MsdColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MsdFieldShell(
            label: 'الاسم الثلاثي',
            child: TextField(
              controller: _name,
              decoration: msdInputDecoration(
                hint: _noId ? 'مثال: مجهول الهوية ذكر' : 'الاسم الأول · الأب · العائلة',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: MsdColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: MsdFieldShell(
                  label: 'العمر',
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: msdInputDecoration(hint: 'سنة'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: MsdFieldShell(
                  label: 'المحافظة',
                  child: DropdownButtonFormField<String>(
                    initialValue: _governorate,
                    decoration: msdInputDecoration(),
                    items: governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _governorate = v ?? _governorate),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MsdFieldShell(
            label: 'السكن الحالي',
            child: TextField(
              controller: _residence,
              decoration: msdInputDecoration(
                hint: 'المنطقة - الحي - الشارع',
                prefixIcon: const Icon(Icons.home_outlined, color: MsdColors.cyan),
              ),
            ),
          ),
          if (_entry != 'إسعافي') ...[
            const SizedBox(height: 12),
            MsdFieldShell(
              label: 'الجهة',
              child: DropdownButtonFormField<String>(
                initialValue: _entity,
                decoration: msdInputDecoration(),
                items: entities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() {
                  _entity = v ?? _entity;
                  _admin = '';
                }),
              ),
            ),
            if (_entity == 'وزارة الداخلية' || _entity == 'وزارة الدفاع' || _entity == 'أخرى') ...[
              const SizedBox(height: 12),
              if (_entity == 'وزارة الداخلية')
                MsdFieldShell(
                  label: 'الإدارة',
                  child: DropdownButtonFormField<String>(
                    initialValue: _admin.isEmpty ? null : _admin,
                    decoration: msdInputDecoration(hint: 'اختر الإدارة...'),
                    items: interiorAdmins.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (v) => setState(() => _admin = v ?? ''),
                  ),
                )
              else
                MsdFieldShell(
                  label: _entity == 'وزارة الدفاع' ? 'الوحدة' : 'التفاصيل',
                  child: TextField(
                    onChanged: (v) => _admin = v,
                    decoration: msdInputDecoration(),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            MsdFieldShell(
              label: 'العيادة المحجوز عليها',
              child: DropdownButtonFormField<String>(
                initialValue: _clinic,
                decoration: msdInputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(10),
                    child: MsdHIcon(size: 20),
                  ),
                ),
                items: clinics.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _clinic = v ?? _clinic),
              ),
            ),
          ],
          const SizedBox(height: 16),
          MsdPrimaryButton(
            label: _entry == 'إسعافي' ? 'فتح استمارة إسعافية وتحويل للإسعاف' : 'فتح استمارة العيادة',
            busy: _saving,
            tone: _entry == 'إسعافي' ? MsdPrimaryTone.danger : MsdPrimaryTone.teal,
            icon: Icons.note_add_rounded,
            onPressed: _open,
          ),
        ],
      ),
    );
  }

  Widget _entryCard(String title, String sub, bool active, VoidCallback onTap, {bool danger = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? (danger ? const Color(0x1ACF5A52) : const Color(0x334BA3C7))
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? (danger ? const Color(0xFFCF5A52) : MsdColors.cyan)
                  : const Color(0x334BA3C7),
              width: active ? 1.7 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: (danger ? MsdColors.danger : MsdColors.cyan).withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: MsdColors.ink, fontSize: 15)),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.tajawal(fontSize: 11, color: MsdColors.sub, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueue() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('طابور التوجيه', style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.teal, fontWeight: FontWeight.w700)),
                    Text('بانتظار التوجيه إلى العيادة', style: GoogleFonts.tajawal(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Text('${_queue.length}', style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800, color: MsdColors.teal)),
            ],
          ),
          const SizedBox(height: 10),
          if (_queue.isEmpty)
            _emptyBox('الطابور فارغ', 'بعد فتح الاستمارة أو تسجيل الوصول تظهر الحالات هنا للتوجيه.')
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: dirty
              ? const [Color(0xFFFBF6EC), Color(0xFFFFFCF7)]
              : open
                  ? const [Color(0xFFEAF6FB), Color(0xFFF8FCFE)]
                  : const [Color(0xFFF8FCFE), Color(0xFFFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dirty
              ? const Color(0x99C0913A)
              : open
                  ? const Color(0x994BA3C7)
                  : const Color(0x334BA3C7),
          width: open ? 1.7 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (dirty ? MsdColors.amber : MsdColors.teal).withValues(alpha: open ? 0.14 : 0.06),
            blurRadius: open ? 22 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleCase(item),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: dirty
                              ? const [Color(0xFFD4A84B), Color(0xFFC0913A)]
                              : const [Color(0xFF7EC8E3), Color(0xFF1A6B8A)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (name?.toString().isNotEmpty == true) ? name.toString().characters.first : '؟',
                        style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name?.toString() ?? '',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: MsdColors.ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            meta,
                            style: GoogleFonts.ibmPlexMono(fontSize: 11, color: MsdColors.sub, height: 1.35),
                          ),
                          const SizedBox(height: 8),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDirty ? const Color(0x66C0913A) : const Color(0x334BA3C7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إضبارة ${item['caseNumber']}',
                      style: GoogleFonts.tajawal(
                        fontSize: 15,
                        color: MsdColors.teal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item['entryType']} · $_editCategory · ${item['statusAr'] ?? ''}',
                      style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.sub),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _tryClose,
                style: TextButton.styleFrom(
                  foregroundColor: MsdColors.sub,
                  backgroundColor: const Color(0x147EC8E3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('إغلاق'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          MsdSegmented(
            leftLabel: 'حالة عامة',
            rightLabel: 'حالة خاصة',
            leftSelected: _editCategory == 'عامة',
            onLeft: () => setState(() => _editCategory = 'عامة'),
            onRight: () => setState(() => _editCategory = 'خاصة'),
          ),
          if (_editCategory == 'خاصة') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialTypes
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _editSpecial == s,
                        selectedColor: MsdColors.amber,
                        labelStyle: GoogleFonts.tajawal(
                          fontWeight: FontWeight.w700,
                          color: _editSpecial == s ? Colors.white : MsdColors.sub,
                        ),
                        onSelected: (_) => setState(() => _editSpecial = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            MsdFieldShell(
              label: 'ملاحظة الحالة الخاصة',
              child: TextField(
                controller: _editSpecialNote,
                onChanged: (_) => setState(() {}),
                decoration: msdInputDecoration(
                  hint: _editSpecial == 'بدون هوية' ? 'علامات مميزة / جهة الإحضار...' : 'رقم الوثيقة أو ملاحظة',
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          MsdFieldShell(
            label: 'الرقم الوطني',
            child: TextField(
              controller: _editNationalId,
              enabled: !_editNoId,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: msdInputDecoration(
                hint: _editNoId ? 'لا يحمل هوية' : '11 رقماً',
                enabled: !_editNoId,
                prefixIcon: const Icon(Icons.badge_outlined, color: MsdColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MsdFieldShell(
            label: 'الاسم الثلاثي',
            child: TextField(
              controller: _editName,
              onChanged: (_) => setState(() {}),
              decoration: msdInputDecoration(
                hint: 'الاسم الأول · الأب · العائلة',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: MsdColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: MsdFieldShell(
                  label: 'العمر',
                  child: TextField(
                    controller: _editAge,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: msdInputDecoration(hint: 'سنة'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: MsdFieldShell(
                  label: 'المحافظة',
                  child: DropdownButtonFormField<String>(
                    initialValue: _editGovernorate,
                    decoration: msdInputDecoration(),
                    items: governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _editGovernorate = v ?? _editGovernorate),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MsdFieldShell(
            label: 'السكن الحالي',
            child: TextField(
              controller: _editResidence,
              onChanged: (_) => setState(() {}),
              decoration: msdInputDecoration(
                hint: 'المنطقة - الحي - الشارع',
                prefixIcon: const Icon(Icons.home_outlined, color: MsdColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MsdFieldShell(
            label: 'الجهة',
            child: DropdownButtonFormField<String>(
              initialValue: _editEntity,
              decoration: msdInputDecoration(),
              items: entities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() {
                _editEntity = v ?? _editEntity;
                _editAdmin = '';
              }),
            ),
          ),
          if (_editEntity == 'وزارة الداخلية' || _editEntity == 'وزارة الدفاع' || _editEntity == 'أخرى') ...[
            const SizedBox(height: 12),
            if (_editEntity == 'وزارة الداخلية')
              MsdFieldShell(
                label: 'الإدارة',
                child: DropdownButtonFormField<String>(
                  initialValue: _editAdmin.isEmpty ? null : _editAdmin,
                  decoration: msdInputDecoration(hint: 'اختر الإدارة...'),
                  items: interiorAdmins.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (v) => setState(() => _editAdmin = v ?? ''),
                ),
              )
            else
              MsdFieldShell(
                label: _editEntity == 'وزارة الدفاع' ? 'الوحدة' : 'التفاصيل',
                child: TextFormField(
                  initialValue: _editAdmin,
                  onChanged: (v) => setState(() => _editAdmin = v),
                  decoration: msdInputDecoration(),
                ),
              ),
          ],
          const SizedBox(height: 12),
          MsdFieldShell(
            label: 'العيادة',
            child: DropdownButtonFormField<String>(
              initialValue: _editClinic,
              decoration: msdInputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(10),
                  child: MsdHIcon(size: 20),
                ),
              ),
              items: clinics.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _editClinic = v ?? _editClinic),
            ),
          ),
          if (_dossierMsg != null) ...[
            const SizedBox(height: 12),
            _banner(_dossierMsg!, error: _dossierError),
          ],
          const SizedBox(height: 16),
          MsdPrimaryButton(
            label: _isDirty ? 'حفظ التعديلات' : 'تحويل إلى عيادة $_editClinic',
            busy: _dossierBusy,
            tone: _isDirty ? MsdPrimaryTone.amber : MsdPrimaryTone.teal,
            icon: _isDirty ? Icons.save_rounded : Icons.send_rounded,
            onPressed: _primaryDossier,
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x55EAF6FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x594BA3C7), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(sub, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: 12, color: MsdColors.sub)),
        ],
      ),
    );
  }
}
