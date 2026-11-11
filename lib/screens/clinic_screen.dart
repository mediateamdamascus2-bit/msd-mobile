import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/msd_widgets.dart';
import '../theme/station_chrome.dart';

class ClinicScreen extends StatefulWidget {
  const ClinicScreen({
    super.key,
    required this.api,
    required this.facilityId,
    required this.clinic,
    this.onLogout,
  });

  final ApiClient api;
  final String facilityId;
  final String clinic;
  final Future<void> Function()? onLogout;

  @override
  State<ClinicScreen> createState() => _ClinicScreenState();
}

class _ClinicScreenState extends State<ClinicScreen> {
  static const _allClinics = [
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
    'الإسعاف',
  ];

  static const _departments = [
    'أسرّة الاستشفاء',
    'العناية',
    'العمليات',
    'المخبر',
    'الصيدلية',
    'الأشعة',
  ];

  final _doctor = TextEditingController();
  final _note = TextEditingController();
  final _returnReason = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _flash;
  bool _flashError = false;
  List<Map<String, dynamic>> _queue = [];
  String? _selectedId;
  String? _transferTo;
  String? _referDept;

  String get _title => widget.clinic == 'الإسعاف' ? 'الإسعاف' : 'عيادة ${widget.clinic}';

  List<String> get _otherClinics =>
      _allClinics.where((c) => c != widget.clinic).toList(growable: false);

  Map<String, dynamic>? get _selected {
    if (_selectedId == null) return null;
    for (final q in _queue) {
      if (q['id']?.toString() == _selectedId) return q;
    }
    return null;
  }

  Timer? _timer;
  final _watcher = NewItemWatcher();

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) => _reload(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _doctor.dispose();
    _note.dispose();
    _returnReason.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (silent && (_busy || _loading)) return;
    if (!silent) setState(() => _loading = true);
    try {
      final items = await widget.api.clinicQueue(widget.facilityId, widget.clinic);
      if (!mounted) return;
      final fresh = _watcher.diff(items);
      NotificationService.instance.newPatients(
        fresh.map((x) => x['patientName']?.toString() ?? '').where((n) => n.isNotEmpty).toList(),
        where: _title,
      );
      setState(() {
        _queue = items.cast<Map<String, dynamic>>();
        if (_selectedId != null && !_queue.any((x) => x['id']?.toString() == _selectedId)) {
          _selectedId = null;
        }
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _flash = e.toString().replaceFirst('Exception: ', '');
        _flashError = true;
      });
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _call() async {
    final item = _selected;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      final row = await widget.api.callClinicCase(widget.facilityId, item['id'].toString());
      setState(() {
        _flash = 'تم استدعاء ${row['patientName']}';
        _flashError = false;
      });
      await _reload();
    } catch (e) {
      setState(() {
        _flash = e.toString().replaceFirst('Exception: ', '');
        _flashError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    final item = _selected;
    if (item == null) return;
    if (_doctor.text.trim().isEmpty) {
      setState(() {
        _flash = 'أدخل اسم الطبيب المعاين.';
        _flashError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.completeClinicCase(
        widget.facilityId,
        item['id'].toString(),
        doctor: _doctor.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      setState(() {
        _selectedId = null;
        _flash = 'تم إنهاء المعاينة.';
        _flashError = false;
        _note.clear();
        _returnReason.clear();
      });
      await _reload();
    } catch (e) {
      setState(() {
        _flash = e.toString().replaceFirst('Exception: ', '');
        _flashError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToReception() async {
    final item = _selected;
    if (item == null) return;
    if (_doctor.text.trim().isEmpty) {
      setState(() {
        _flash = 'أدخل اسم الطبيب المعاين.';
        _flashError = true;
      });
      return;
    }
    if (_returnReason.text.trim().isEmpty) {
      setState(() {
        _flash = 'اكتب سبب الإعادة إلى الاستقبال.';
        _flashError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.returnClinicCase(
        widget.facilityId,
        item['id'].toString(),
        doctor: _doctor.text.trim(),
        reason: _returnReason.text.trim(),
      );
      setState(() {
        _selectedId = null;
        _flash = 'أُعيد للاستقبال.';
        _flashError = false;
        _returnReason.clear();
      });
      await _reload();
    } catch (e) {
      setState(() {
        _flash = e.toString().replaceFirst('Exception: ', '');
        _flashError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transferClinic() async {
    final item = _selected;
    if (item == null || _transferTo == null) return;
    if (_doctor.text.trim().isEmpty) {
      setState(() {
        _flash = 'أدخل اسم الطبيب المعاين.';
        _flashError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.transferClinicCase(
        widget.facilityId,
        item['id'].toString(),
        doctor: _doctor.text.trim(),
        toClinic: _transferTo!,
      );
      setState(() {
        _selectedId = null;
        _flash = 'تم التحويل إلى عيادة $_transferTo.';
        _flashError = false;
        _transferTo = null;
      });
      await _reload();
    } catch (e) {
      setState(() {
        _flash = e.toString().replaceFirst('Exception: ', '');
        _flashError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _referDepartment() async {
    final item = _selected;
    if (item == null || _referDept == null) return;
    if (_doctor.text.trim().isEmpty) {
      setState(() {
        _flash = 'أدخل اسم الطبيب المعاين.';
        _flashError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.referClinicCase(
        widget.facilityId,
        item['id'].toString(),
        doctor: _doctor.text.trim(),
        department: _referDept!,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      setState(() {
        _selectedId = null;
        _flash = 'تم التحويل إلى $_referDept.';
        _flashError = false;
        _referDept = null;
      });
      await _reload();
    } catch (e) {
      setState(() {
        _flash = e.toString().replaceFirst('Exception: ', '');
        _flashError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      backgroundColor: MsdColors.mist,
      body: StationBackdrop(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [MsdTokens.teal, MsdTokens.teal, MsdTokens.deep],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'محطة مستقلة · مشفى الشرطة في حرستا',
                              style: TextStyle(
                                color: MsdTokens.onDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'طابور المحوّلين من الاستقبال',
                              style: TextStyle(color: MsdTokens.onDeep, fontSize: 13),
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
                          ),
                          child: const Text('خروج'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        Expanded(
                          child: _kpi('بالانتظار', '${_queue.length}'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _kpi('اليوم', DateTime.now().toString().substring(0, 10)),
                        ),
                      ],
                    ),
                    if (_flash != null) ...[
                      const SizedBox(height: 10),
                      _banner(_flash!, error: _flashError),
                    ],
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('طابور الانتظار', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_queue.isEmpty)
                            Text(
                              'لا يوجد مرضى في الطابور',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: MsdColors.sub),
                            )
                          else
                            ..._queue.map((item) {
                              final id = item['id']?.toString();
                              final on = id == _selectedId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: on ? MsdTokens.surface : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: on ? MsdColors.cyan : MsdTokens.cyanLine,
                                    width: on ? 1.6 : 1,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () => setState(() => _selectedId = id),
                                  title: Text(
                                    item['patientName']?.toString() ?? '',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  subtitle: Text(
                                    '${item['caseNumber']} · ${item['statusAr'] ?? ''}',
                                    style: TextStyle(fontSize: 12, color: MsdColors.sub),
                                  ),
                                  trailing: on
                                      ? const Icon(Icons.check_circle, color: MsdColors.teal)
                                      : const Icon(Icons.chevron_left, color: MsdColors.faint),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 12),
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              selected['patientName']?.toString() ?? '',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${selected['caseNumber']} · ${selected['nationalId'] ?? 'بدون هوية'}',
                              style: TextStyle(color: MsdColors.sub),
                            ),
                            const SizedBox(height: 14),
                            MsdFieldShell(
                              label: 'الطبيب',
                              child: TextField(
                                controller: _doctor,
                                decoration: msdInputDecoration(hint: 'اسم الطبيب'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            MsdFieldShell(
                              label: 'ملاحظة / شكاية',
                              child: TextField(
                                controller: _note,
                                maxLines: 2,
                                decoration: msdInputDecoration(hint: 'اختياري'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            MsdFieldShell(
                              label: 'سبب الإعادة للاستقبال',
                              child: TextField(
                                controller: _returnReason,
                                decoration: msdInputDecoration(hint: 'عند الإعادة فقط'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            MsdFieldShell(
                              label: 'تحويل إلى عيادة',
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('transfer-$_transferTo'),
                                initialValue: _transferTo,
                                decoration: msdInputDecoration(hint: 'اختر عيادة...'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('—')),
                                  ..._otherClinics.map(
                                    (c) => DropdownMenuItem(value: c, child: Text(c)),
                                  ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _transferTo = v),
                              ),
                            ),
                            const SizedBox(height: 12),
                            MsdFieldShell(
                              label: 'تحويل إلى قسم',
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('refer-$_referDept'),
                                initialValue: _referDept,
                                decoration: msdInputDecoration(hint: 'اختر قسماً...'),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('—')),
                                  ..._departments.map(
                                    (d) => DropdownMenuItem(value: d, child: Text(d)),
                                  ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _referDept = v),
                              ),
                            ),
                            const SizedBox(height: 16),
                            MsdPrimaryButton(
                              label: () {
                                final n = selected['callCount'];
                                final count = n is int ? n : int.tryParse('$n') ?? 0;
                                return count > 0 ? 'إعادة الاستدعاء ($count)' : 'استدعاء المريض';
                              }(),
                              busy: _busy,
                              icon: Icons.campaign_outlined,
                              onPressed: _call,
                            ),
                            const SizedBox(height: 8),
                            MsdPrimaryButton(
                              label: 'إنهاء وخروج',
                              busy: _busy,
                              tone: MsdPrimaryTone.cyan,
                              icon: Icons.check_rounded,
                              onPressed: _complete,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _busy ? null : _returnToReception,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: MsdColors.amber,
                                side: const BorderSide(color: MsdColors.amber),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('إعادة للاستقبال', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: (_busy || _transferTo == null) ? null : _transferClinic,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: MsdColors.teal,
                                side: const BorderSide(color: MsdColors.teal),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('تحويل عيادة', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: (_busy || _referDept == null) ? null : _referDepartment,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: MsdColors.cyan,
                                side: const BorderSide(color: MsdColors.cyan),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('تحويل قسم', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
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

  Widget _kpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MsdTokens.cyanLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: MsdColors.sub, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MsdColors.teal)),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MsdTokens.cyanLine),
      ),
      child: child,
    );
  }

  Widget _banner(String text, {required bool error}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? MsdTokens.dangerWash : MsdTokens.successWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: error ? MsdColors.danger : MsdColors.green,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
