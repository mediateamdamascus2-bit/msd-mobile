import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';
import '../theme/station_chrome.dart';

class ClinicLiveScreen extends StatefulWidget {
  const ClinicLiveScreen({
    super.key,
    required this.api,
    required this.facilityId,
    this.onLogout,
  });

  final ApiClient api;
  final String facilityId;
  final Future<void> Function()? onLogout;

  @override
  State<ClinicLiveScreen> createState() => _ClinicLiveScreenState();
}

class _ClinicLiveScreenState extends State<ClinicLiveScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _reload(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    setState(() => _busy = true);
    try {
      final rows = await widget.api.clinicLive(widget.facilityId);
      if (!mounted) return;
      setState(() {
        _rows = rows.cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MsdColors.mist,
      body: StationBackdrop(
        child: RefreshIndicator(
          onRefresh: () => _reload(),
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
                              'محطة مستقلة · مشفى حرستا',
                              style: TextStyle(
                                color: MsdTokens.onDeep,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'إحصائيات العيادات',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'متابعة مباشرة لطوابير اليوم',
                              style: TextStyle(color: MsdTokens.onDeep, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'تحديث',
                        onPressed: _busy ? null : () => _reload(),
                        icon: const Icon(Icons.refresh, color: Colors.white),
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
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MsdTokens.dangerWash,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!, style: TextStyle(color: MsdColors.danger, fontWeight: FontWeight.w700)),
                      ),
                    if (_loading && _rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else
                      ..._rows.map((r) {
                        final clinic = r['clinic']?.toString() ?? '';
                        final waiting = r['waiting'] is int ? r['waiting'] as int : int.tryParse('${r['waiting']}') ?? 0;
                        final referrals = r['todayReferrals'] is int
                            ? r['todayReferrals'] as int
                            : int.tryParse('${r['todayReferrals']}') ?? 0;
                        final title = clinic == 'الإسعاف' ? clinic : 'عيادة $clinic';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: waiting > 0 ? MsdTokens.amberWash : MsdTokens.cyanLine,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _metric('بالانتظار', '$waiting', hot: waiting > 0)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _metric('توجيهات اليوم', '$referrals', hot: referrals > 0)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _metric('متوسط الانتظار', '${r['avgWaitLabel'] ?? '—'}')),
                                  const SizedBox(width: 8),
                                  Expanded(child: _metric('أطول انتظار', '${r['maxWaitLabel'] ?? '—'}')),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value, {bool hot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hot ? MsdTokens.amberWash : MsdTokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: MsdColors.sub, fontWeight: FontWeight.w600)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: hot ? MsdColors.amber : MsdColors.teal,
            ),
          ),
        ],
      ),
    );
  }
}
