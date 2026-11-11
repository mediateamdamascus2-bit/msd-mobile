import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/new_item_watcher.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/msd_widgets.dart';
import '../theme/station_chrome.dart';

class DeptScreen extends StatefulWidget {
  const DeptScreen({
    super.key,
    required this.api,
    required this.facilityId,
    required this.department,
    this.onLogout,
  });

  final ApiClient api;
  final String facilityId;
  final String department;
  final Future<void> Function()? onLogout;

  @override
  State<DeptScreen> createState() => _DeptScreenState();
}

class _DeptScreenState extends State<DeptScreen> {
  final _result = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _flash;
  bool _flashError = false;
  List<Map<String, dynamic>> _queue = [];
  String? _selectedId;

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
    _result.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (silent && (_busy || _loading)) return;
    if (!silent) setState(() => _loading = true);
    try {
      final items = await widget.api.departmentQueue(widget.facilityId, widget.department);
      if (!mounted) return;
      final fresh = _watcher.diff(items);
      NotificationService.instance.newPatients(
        fresh.map((x) => x['patientName']?.toString() ?? '').where((n) => n.isNotEmpty).toList(),
        where: widget.department,
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

  Future<void> _complete() async {
    final item = _selected;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.completeDepartmentCase(
        widget.facilityId,
        item['id'].toString(),
        result: _result.text.trim(),
      );
      setState(() {
        _selectedId = null;
        _flash = 'تم الإنهاء.';
        _flashError = false;
        _result.clear();
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

  Future<void> _returnClinic() async {
    final item = _selected;
    if (item == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.returnDepartmentToClinic(
        widget.facilityId,
        item['id'].toString(),
        result: _result.text.trim(),
      );
      setState(() {
        _selectedId = null;
        _flash = 'أُعيد للعيادة.';
        _flashError = false;
        _result.clear();
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
                              'محطة قسم تحويل · مشفى حرستا',
                              style: TextStyle(
                                color: MsdTokens.onDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.department,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'الحالات المحوّلة من العيادات',
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
                    _kpi('بالانتظار', '${_queue.length}'),
                    if (_flash != null) ...[
                      const SizedBox(height: 10),
                      _banner(_flash!, error: _flashError),
                    ],
                    const SizedBox(height: 12),
                    _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('طابور القسم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (_queue.isEmpty)
                            Text(
                              'لا توجد حالات',
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
                              '${selected['caseNumber']} · من عيادة ${selected['currentClinic'] ?? selected['bookedClinic'] ?? '—'}',
                              style: TextStyle(color: MsdColors.sub),
                            ),
                            const SizedBox(height: 14),
                            MsdFieldShell(
                              label: 'نتيجة القسم',
                              child: TextField(
                                controller: _result,
                                maxLines: 3,
                                decoration: msdInputDecoration(hint: 'نتيجة / ملاحظة'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            MsdPrimaryButton(
                              label: 'إنهاء',
                              busy: _busy,
                              icon: Icons.check_rounded,
                              onPressed: _complete,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _busy ? null : _returnClinic,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: MsdColors.amber,
                                side: const BorderSide(color: MsdColors.amber),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text('إعادة للعيادة', style: TextStyle(fontWeight: FontWeight.w800)),
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
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MsdColors.teal)),
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
