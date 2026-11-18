import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/msd_widgets.dart';
import '../theme/station_chrome.dart';
import '../ui/msd_text_field.dart';

class _RxLine {
  _RxLine();

  final drug = TextEditingController();
  final dose = TextEditingController();
  final freq = TextEditingController();
  final duration = TextEditingController();

  bool get isBlank =>
      drug.text.trim().isEmpty &&
      dose.text.trim().isEmpty &&
      freq.text.trim().isEmpty &&
      duration.text.trim().isEmpty;

  String get asNote {
    final parts = [
      drug.text.trim(),
      if (dose.text.trim().isNotEmpty) dose.text.trim(),
      if (freq.text.trim().isNotEmpty) freq.text.trim(),
      if (duration.text.trim().isNotEmpty) duration.text.trim(),
    ];
    return parts.join(' · ');
  }

  void dispose() {
    drug.dispose();
    dose.dispose();
    freq.dispose();
    duration.dispose();
  }
}

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

class _ClinicScreenState extends State<ClinicScreen> with WidgetsBindingObserver {
  final _complaint = TextEditingController();
  final _diagnosis = TextEditingController();
  final _returnReason = TextEditingController();
  final _labNote = TextEditingController();
  final _radNote = TextEditingController();
  final _admitNote = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _paused = false;
  String? _flash;
  bool _flashError = false;
  DateTime? _lastUpdated;

  List<Map<String, dynamic>> _queue = [];
  String? _selectedId;

  String _doctor = '';
  int _settingsVersion = 0;
  Map<String, dynamic> _settingsData = {};

  List<String> _clinics = [];
  List<Map<String, dynamic>> _deptLive = [];
  List<String> _drugNames = [];

  String? _transferTo;
  String? _admitDest;
  bool _wantLab = false;
  bool _wantRad = false;
  final List<_RxLine> _rx = [_RxLine()];

  Timer? _timer;
  final _watcher = NewItemWatcher();

  String get _title => widget.clinic == 'الإسعاف' ? 'الإسعاف' : 'عيادة ${widget.clinic}';

  String get _stationKey => '${widget.facilityId}.clinic:${widget.clinic}';

  List<String> get _otherClinics =>
      _clinics.where((c) => c != widget.clinic).toList(growable: false);

  Map<String, dynamic>? get _selected {
    if (_selectedId == null) return null;
    for (final q in _queue) {
      if (q['id']?.toString() == _selectedId) return q;
    }
    return null;
  }

  List<Map<String, dynamic>> get _orderedQueue {
    if (_selectedId == null) return _queue;
    final cur = <Map<String, dynamic>>[];
    final rest = <Map<String, dynamic>>[];
    for (final q in _queue) {
      if (q['id']?.toString() == _selectedId) {
        cur.add(q);
      } else {
        rest.add(q);
      }
    }
    return [...cur, ...rest];
  }

  int _callCountOf(Map<String, dynamic> item) {
    final n = item['callCount'];
    if (n is int) return n;
    return int.tryParse('$n') ?? 0;
  }

  bool _wasCalled(Map<String, dynamic> item) {
    final called = item['calledAt'];
    return called != null && called.toString().isNotEmpty && called.toString() != 'null';
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

  int? _deptFree(String name) {
    for (final d in _deptLive) {
      final n = (d['name'] ?? d['Name'] ?? '').toString();
      if (n == name) {
        final free = d['free'] ?? d['Free'];
        if (free is int) return free;
        return int.tryParse('$free');
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _armTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _complaint.dispose();
    _diagnosis.dispose();
    _returnReason.dispose();
    _labNote.dispose();
    _radNote.dispose();
    _admitNote.dispose();
    for (final line in _rx) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      _armTimer();
      _reload(silent: true);
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
      if (!_paused) _reload(silent: true);
    });
  }

  void _setFlash(String msg, {required bool error}) {
    setState(() {
      _flash = msg;
      _flashError = error;
    });
  }

  void _resetExam() {
    _complaint.clear();
    _diagnosis.clear();
    _returnReason.clear();
    _labNote.clear();
    _radNote.clear();
    _admitNote.clear();
    _transferTo = null;
    _admitDest = null;
    _wantLab = false;
    _wantRad = false;
    for (final line in _rx) {
      line.dispose();
    }
    _rx
      ..clear()
      ..add(_RxLine());
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadSettings(),
      _loadCatalogs(),
      _reload(silent: true),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSettings() async {
    try {
      final row = await widget.api.stationSettings(widget.facilityId, _stationKey);
      final data = row['data'];
      final ver = row['version'];
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _settingsData = map;
        _settingsVersion = ver is int ? ver : int.tryParse('$ver') ?? 0;
        _doctor = (map['doctor'] ?? '').toString().trim();
      });
    } catch (_) {
      // first open — empty doctor until settings saved
    }
  }

  Future<void> _loadCatalogs() async {
    final clinics = <String>{};
    try {
      final live = await widget.api.clinicLive(widget.facilityId);
      for (final r in live) {
        if (r is Map) {
          final c = (r['clinic'] ?? '').toString().trim();
          if (c.isNotEmpty) clinics.add(c);
        }
      }
    } catch (_) {}
    try {
      final avail = await widget.api.bookingAvailability(
        widget.facilityId,
        date: _todayIso(),
      );
      final list = avail['clinics'];
      if (list is List) {
        for (final c in list) {
          String? name;
          if (c is Map) name = (c['clinic'] ?? c['name'])?.toString();
          if (c is String) name = c;
          if (name != null && name.trim().isNotEmpty) clinics.add(name.trim());
        }
      }
    } catch (_) {}
    clinics.add('الإسعاف');

    List<Map<String, dynamic>> depts = [];
    try {
      final live = await widget.api.departmentsLive(widget.facilityId);
      depts = live.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}

    List<String> drugs = [];
    try {
      final stock = await widget.api.pharmacyStock(widget.facilityId);
      for (final s in stock) {
        if (s is Map) {
          final n = (s['name'] ?? s['Name'] ?? '').toString().trim();
          if (n.isNotEmpty && !drugs.contains(n)) drugs.add(n);
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _clinics = clinics.toList()..sort((a, b) {
        if (a == 'الإسعاف') return -1;
        if (b == 'الإسعاف') return 1;
        return a.compareTo(b);
      });
      _deptLive = depts;
      _drugNames = drugs;
    });
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
          _resetExam();
        }
        _lastUpdated = DateTime.now();
        if (!silent) _flash = null;
      });
      // refresh capacity quietly
      try {
        final live = await widget.api.departmentsLive(widget.facilityId);
        if (mounted) {
          setState(() {
            _deptLive = live.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } catch (_) {}
    } catch (e) {
      if (!mounted || silent) return;
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _openSettings() async {
    final ctrl = TextEditingController(text: _doctor);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعدادات المحطة'),
        content: MsdTextField(
          controller: ctrl,
          labelText: 'الطبيب المعاين',
          hintText: 'د. ...',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      ctrl.dispose();
      return;
    }
    final next = ctrl.text.trim();
    ctrl.dispose();
    setState(() => _busy = true);
    try {
      final data = Map<String, dynamic>.from(_settingsData)..['doctor'] = next;
      final saved = await widget.api.saveStationSettings(
        widget.facilityId,
        key: _stationKey,
        data: data,
        version: _settingsVersion,
      );
      final ver = saved['version'];
      setState(() {
        _doctor = next;
        _settingsData = data;
        _settingsVersion = ver is int ? ver : int.tryParse('$ver') ?? _settingsVersion;
        _flash = 'تم حفظ اسم الطبيب';
        _flashError = false;
      });
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
      await _loadSettings();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
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
    return ok == true;
  }

  Future<void> _call() async {
    final item = _selected;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      final row = await widget.api.callClinicCase(widget.facilityId, item['id'].toString());
      _setFlash('تم استدعاء ${row['patientName'] ?? item['patientName']}', error: false);
      await _reload(silent: true);
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _noShow() async {
    final item = _selected;
    if (item == null) return;
    final name = item['patientName']?.toString() ?? 'المريض';
    if (!await _confirm('لم يحضر', 'تسجيل عدم حضور $name؟')) return;
    setState(() => _busy = true);
    try {
      await widget.api.noShowClinicCase(widget.facilityId, item['id'].toString());
      setState(() {
        _selectedId = null;
        _resetExam();
      });
      _setFlash('سُجّل عدم حضور $name', error: false);
      await _reload(silent: true);
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>>? _buildOrders({required bool requireSomething}) {
    final orders = <Map<String, dynamic>>[];
    final rxNotes = <String>[];
    for (final line in _rx) {
      if (line.isBlank) continue;
      if (line.drug.text.trim().isEmpty) {
        _setFlash('أدخل اسم الدواء في الوصفة', error: true);
        return null;
      }
      rxNotes.add(line.asNote);
    }
    if (rxNotes.isNotEmpty) {
      orders.add({'department': 'الصيدلية', 'note': rxNotes.join('\n')});
    }
    if (_wantLab) {
      if (_labNote.text.trim().isEmpty) {
        _setFlash('اكتب التحاليل المطلوبة', error: true);
        return null;
      }
      orders.add({'department': 'المخبر', 'note': _labNote.text.trim()});
    }
    if (_wantRad) {
      if (_radNote.text.trim().isEmpty) {
        _setFlash('اكتب الأشعة المطلوبة', error: true);
        return null;
      }
      orders.add({'department': 'الأشعة', 'note': _radNote.text.trim()});
    }
    if (_admitDest != null) {
      orders.add({
        'department': _admitDest,
        'note': _admitNote.text.trim().isEmpty ? null : _admitNote.text.trim(),
      });
    }
    if (requireSomething && orders.isEmpty) {
      _setFlash('اختر قبولًا أو طلبًا واحدًا على الأقل', error: true);
      return null;
    }
    return orders;
  }

  Future<void> _submit({
    required String outcome,
    required String confirmTitle,
    required String confirmBody,
    String? reason,
    bool requireOrders = false,
    bool requireDiagnosis = false,
  }) async {
    final item = _selected;
    if (item == null) return;
    if (_doctor.trim().isEmpty) {
      _setFlash('حدّد الطبيب من إعدادات المحطة أولًا', error: true);
      return;
    }
    if (_complaint.text.trim().isEmpty) {
      _setFlash('سجّل الشكاية أولًا', error: true);
      return;
    }
    if (requireDiagnosis && _diagnosis.text.trim().isEmpty) {
      _setFlash('التشخيص إلزامي للإنهاء', error: true);
      return;
    }
    if (outcome == 'إعادة توجيه' && (reason == null || reason.trim().isEmpty)) {
      _setFlash('اكتب سبب إغلاق الإضبارة وإعادته إلى الاستقبال', error: true);
      return;
    }
    final orders = _buildOrders(requireSomething: requireOrders);
    if (orders == null) return;
    if (!await _confirm(confirmTitle, confirmBody)) return;

    setState(() => _busy = true);
    try {
      await widget.api.submitClinicVisit(
        widget.facilityId,
        item['id'].toString(),
        doctor: _doctor.trim(),
        complaint: _complaint.text.trim(),
        diagnosis: _diagnosis.text.trim().isEmpty ? null : _diagnosis.text.trim(),
        outcome: outcome,
        reason: reason,
        orders: orders,
      );
      setState(() {
        _selectedId = null;
        _resetExam();
      });
      _setFlash('تم حفظ القرار', error: false);
      await _reload(silent: true);
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discharge() async {
    final item = _selected;
    if (item == null) return;
    final name = item['patientName']?.toString() ?? 'المريض';
    await _submit(
      outcome: 'خروج',
      confirmTitle: 'إنهاء وخروج',
      confirmBody: 'إنهاء معاينة $name وخروجه؟',
      requireDiagnosis: true,
    );
  }

  Future<void> _admit() async {
    final item = _selected;
    if (item == null || _admitDest == null) return;
    final name = item['patientName']?.toString() ?? 'المريض';
    await _submit(
      outcome: 'تحويل',
      confirmTitle: 'قبول',
      confirmBody: 'قبول $name في $_admitDest؟',
      requireOrders: true,
    );
  }

  Future<void> _returnReception() async {
    final item = _selected;
    if (item == null) return;
    final name = item['patientName']?.toString() ?? 'المريض';
    await _submit(
      outcome: 'إعادة توجيه',
      confirmTitle: 'إعادة للاستقبال',
      confirmBody: 'إعادة $name إلى الاستقبال؟',
      reason: _returnReason.text.trim(),
    );
  }

  Future<void> _transferClinic() async {
    final item = _selected;
    if (item == null || _transferTo == null) return;
    if (_doctor.trim().isEmpty) {
      _setFlash('حدّد الطبيب من إعدادات المحطة أولًا', error: true);
      return;
    }
    final name = item['patientName']?.toString() ?? 'المريض';
    final dest = _transferTo!;
    if (!await _confirm('تحويل عيادة', 'تحويل $name إلى $dest؟')) return;
    setState(() => _busy = true);
    try {
      await widget.api.transferClinicCase(
        widget.facilityId,
        item['id'].toString(),
        doctor: _doctor.trim(),
        toClinic: dest,
      );
      setState(() {
        _selectedId = null;
        _resetExam();
      });
      _setFlash('تم التحويل إلى $dest', error: false);
      await _reload(silent: true);
    } catch (e) {
      _setFlash(ApiException.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFolder() async {
    final item = _selected;
    if (item == null) return;
    final caseId = item['id']?.toString() ?? '';
    final caseNo = item['caseNumber']?.toString() ?? '';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      Map<String, dynamic> res;
      try {
        res = await widget.api.listFolders(widget.facilityId, patient: caseId);
      } catch (_) {
        res = await widget.api.listFolders(widget.facilityId, patient: caseNo);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      final items = (res['items'] as List?) ?? const [];
      if (items.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('الإضبارة'),
            content: const Text('لا توجد إضبارة مفتوحة لهذا المريض.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
            ],
          ),
        );
        return;
      }
      final folder = Map<String, dynamic>.from(items.first as Map);
      final sheetsRaw = folder['sheets'];
      final sheets = <MapEntry<String, Map<String, dynamic>>>[];
      if (sheetsRaw is Map) {
        for (final e in sheetsRaw.entries) {
          final v = e.value;
          sheets.add(MapEntry(
            e.key.toString(),
            v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{'status': 'فارغة'},
          ));
        }
      }
      final order = (folder['order'] as List?)?.map((e) => e.toString()).toList() ?? [];
      sheets.sort((a, b) {
        final ia = order.indexOf(a.key);
        final ib = order.indexOf(b.key);
        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;
        return a.key.compareTo(b.key);
      });

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'إضبارة ${item['patientName'] ?? ''}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'رقم ${folder['no'] ?? caseNo} · ${folder['kind'] ?? ''}',
                    style: TextStyle(color: MsdColors.sub, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (sheets.isEmpty)
                    const Text('لا أوراق في الإضبارة بعد.', textAlign: TextAlign.center)
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sheets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = sheets[i];
                          final status = (s.value['status'] ?? 'فارغة').toString();
                          final color = status == 'مكتملة'
                              ? MsdColors.green
                              : status == 'جزئية'
                                  ? MsdColors.amber
                                  : MsdColors.faint;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MsdTokens.cyanLine),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.key,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'العرض للقراءة فقط — التعبئة من الموقع حاليًا.',
                    style: TextStyle(fontSize: 12, color: MsdColors.sub),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _setFlash(ApiException.messageOf(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final doctorLabel = _doctor.isEmpty ? 'لم يُحدَّد الطبيب' : _doctor;

    return Scaffold(
      body: StationBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: StationCompactHeader(
                  station: _title,
                  hospital: 'مشفى الشرطة في حرستا',
                  onLogout: widget.onLogout,
                  onSettings: _busy ? null : () { _openSettings(); },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.medical_services_outlined, size: 16, color: MsdColors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        doctorLabel,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _doctor.isEmpty ? MsdColors.amber : MsdColors.teal,
                        ),
                      ),
                    ),
                    if (_lastUpdated != null)
                      Text(
                        'آخر تحديث ${_hhmm(_lastUpdated!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MsdColors.sub,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: MsdColors.cyan,
                  onRefresh: () => _reload(),
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            if (_flash != null) ...[
                              _Banner(text: _flash!, error: _flashError),
                              const SizedBox(height: 10),
                            ],
                            StationSection(
                              title: 'الطابور',
                              trailing: Text(
                                '${_queue.length}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: MsdColors.teal,
                                  fontSize: 16,
                                ),
                              ),
                              child: _queue.isEmpty
                                  ? const _EmptyState(
                                      icon: Icons.hourglass_empty_rounded,
                                      message: 'لا يوجد مرضى في هذه العيادة',
                                    )
                                  : Column(
                                      children: [
                                        for (final item in _orderedQueue) _queueTile(item),
                                      ],
                                    ),
                            ),
                            if (selected != null) ...[
                              const SizedBox(height: 12),
                              _examPanel(selected),
                            ],
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

  Widget _queueTile(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    final on = id == _selectedId;
    final called = _wasCalled(item);
    final count = _callCountOf(item);
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
        onTap: () => setState(() {
          _selectedId = id;
          _resetExam();
        }),
        title: Text(
          item['patientName']?.toString() ?? '',
          maxLines: 2,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${item['caseNumber'] ?? ''} · ${item['statusAr'] ?? ''}',
          style: TextStyle(fontSize: 12, color: MsdColors.sub),
        ),
        trailing: called
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MsdColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count > 1 ? 'مُستدعى ×$count' : 'مُستدعى',
                  style: TextStyle(
                    color: MsdColors.green,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              )
            : Icon(on ? Icons.check_circle : Icons.chevron_left, color: on ? MsdColors.teal : MsdColors.faint),
      ),
    );
  }

  Widget _examPanel(Map<String, dynamic> selected) {
    final called = _wasCalled(selected);
    final count = _callCountOf(selected);
    final admitOptions = ['أسرّة الاستشفاء', 'العناية', 'العمليات'];

    return StationSection(
      title: selected['patientName']?.toString() ?? '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${selected['caseNumber'] ?? ''} · ${selected['nationalId'] ?? 'بدون هوية'}'
            '${selected['age'] != null ? ' · ${selected['age']} سنة' : ''}',
            style: TextStyle(color: MsdColors.sub, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MsdPrimaryButton(
                  label: count > 0 ? 'إعادة الاستدعاء ($count)' : 'استدعاء',
                  busy: _busy,
                  icon: Icons.campaign_outlined,
                  onPressed: _call,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: (_busy || !called) ? null : _noShow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MsdColors.danger,
                  side: BorderSide(color: MsdColors.danger.withValues(alpha: called ? 1 : 0.3)),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('لم يحضر', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _showFolder,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('الإضبارة'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: MsdColors.teal,
              side: const BorderSide(color: MsdColors.teal),
            ),
          ),
          const SizedBox(height: 14),
          MsdFieldShell(
            label: 'الشكاية',
            child: TextField(
              controller: _complaint,
              maxLines: 3,
              decoration: msdInputDecoration(hint: 'الشكاية الرئيسية'),
            ),
          ),
          const SizedBox(height: 10),
          MsdFieldShell(
            label: 'التشخيص',
            child: TextField(
              controller: _diagnosis,
              maxLines: 3,
              decoration: msdInputDecoration(hint: 'إلزامي للإنهاء'),
            ),
          ),
          const SizedBox(height: 14),
          Text('الوصفة', style: TextStyle(fontWeight: FontWeight.w800, color: MsdColors.ink)),
          const SizedBox(height: 8),
          for (var i = 0; i < _rx.length; i++) ...[
            _rxCard(i),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _busy ? null : () => setState(() => _rx.add(_RxLine())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة صنف'),
            ),
          ),
          const SizedBox(height: 8),
          Text('طلبات', style: TextStyle(fontWeight: FontWeight.w800, color: MsdColors.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('مخبر'),
                selected: _wantLab,
                onSelected: _busy
                    ? null
                    : (v) => setState(() {
                          _wantLab = v;
                          if (!v) _labNote.clear();
                        }),
              ),
              FilterChip(
                label: const Text('أشعة'),
                selected: _wantRad,
                onSelected: _busy
                    ? null
                    : (v) => setState(() {
                          _wantRad = v;
                          if (!v) _radNote.clear();
                        }),
              ),
            ],
          ),
          if (_wantLab) ...[
            const SizedBox(height: 8),
            MsdFieldShell(
              label: 'ملاحظة المخبر',
              child: TextField(
                controller: _labNote,
                decoration: msdInputDecoration(hint: 'التحاليل المطلوبة'),
              ),
            ),
          ],
          if (_wantRad) ...[
            const SizedBox(height: 8),
            MsdFieldShell(
              label: 'ملاحظة الأشعة',
              child: TextField(
                controller: _radNote,
                decoration: msdInputDecoration(hint: 'الأشعة المطلوبة'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('قبول', style: TextStyle(fontWeight: FontWeight.w800, color: MsdColors.ink)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in admitOptions)
                ChoiceChip(
                  label: Text(() {
                    final free = _deptFree(d);
                    final short = d == 'أسرّة الاستشفاء'
                        ? 'استشفاء'
                        : d == 'العناية'
                            ? 'عناية'
                            : 'عمليات';
                    return free == null ? short : '$short · متبقي $free';
                  }()),
                  selected: _admitDest == d,
                  onSelected: _busy
                      ? null
                      : (v) => setState(() => _admitDest = v ? d : null),
                ),
            ],
          ),
          if (_admitDest != null) ...[
            const SizedBox(height: 8),
            MsdFieldShell(
              label: 'ملاحظة القبول',
              child: TextField(
                controller: _admitNote,
                decoration: msdInputDecoration(
                  hint: _admitDest == 'العمليات' ? 'نوع العملية...' : 'سبب القبول',
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          MsdFieldShell(
            label: 'تحويل إلى عيادة',
            child: DropdownButtonFormField<String>(
              key: ValueKey('xfer-$_transferTo-${_otherClinics.length}'),
              initialValue: _transferTo,
              isExpanded: true,
              decoration: msdInputDecoration(hint: 'اختر عيادة...'),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                ..._otherClinics.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: _busy ? null : (v) => setState(() => _transferTo = v),
            ),
          ),
          const SizedBox(height: 10),
          MsdFieldShell(
            label: 'سبب الإعادة للاستقبال',
            child: TextField(
              controller: _returnReason,
              decoration: msdInputDecoration(hint: 'عند الإعادة فقط'),
            ),
          ),
          const SizedBox(height: 16),
          MsdPrimaryButton(
            label: 'إنهاء وخروج',
            busy: _busy,
            tone: MsdPrimaryTone.cyan,
            icon: Icons.check_rounded,
            onPressed: _discharge,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: (_busy || _transferTo == null) ? null : _transferClinic,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: MsdColors.teal,
              side: const BorderSide(color: MsdColors.teal),
            ),
            child: const Text('تحويل لعيادة', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: (_busy || _admitDest == null) ? null : _admit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: MsdColors.amber,
              side: const BorderSide(color: MsdColors.amber),
            ),
            child: const Text('قبول', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _returnReception,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: MsdColors.danger,
              side: const BorderSide(color: MsdColors.danger),
            ),
            child: const Text('إعادة للاستقبال', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _rxCard(int index) {
    final line = _rx[index];
    final picked = _drugNames.contains(line.drug.text) ? line.drug.text : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MsdTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MsdTokens.cyanLine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('صنف ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (_rx.length > 1)
                IconButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _rx.removeAt(index).dispose();
                          }),
                  icon: const Icon(Icons.delete_outline_rounded, color: MsdColors.danger),
                  tooltip: 'حذف',
                ),
            ],
          ),
          if (_drugNames.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('drug-$index-$picked'),
              initialValue: picked,
              isExpanded: true,
              decoration: msdInputDecoration(hint: 'الدواء من الصيدلية'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— أو اكتب يدويًا —')),
                ..._drugNames.map((d) => DropdownMenuItem(value: d, child: Text(d))),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() => line.drug.text = v);
                      }
                    },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: line.drug,
            decoration: msdInputDecoration(hint: 'الدواء'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: line.dose,
                  decoration: msdInputDecoration(hint: 'الجرعة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: line.freq,
                  decoration: msdInputDecoration(hint: 'التكرار'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: line.duration,
            decoration: msdInputDecoration(hint: 'المدة'),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
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
          Icon(icon, size: 36, color: MsdColors.faint),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: MsdColors.sub, fontWeight: FontWeight.w700),
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
        border: Border.all(color: MsdTokens.cyanLine),
      ),
    );
  }
}
