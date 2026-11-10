import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';

class HasiaPharmacyScreen extends StatefulWidget {
  const HasiaPharmacyScreen({
    super.key,
    required this.api,
    required this.pharmacy,
  });

  final ApiClient api;
  final String pharmacy;

  @override
  State<HasiaPharmacyScreen> createState() => _HasiaPharmacyScreenState();
}

class _HasiaPharmacyScreenState extends State<HasiaPharmacyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Future<List<dynamic>>? _stock;
  Future<List<dynamic>>? _rx;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _silentReload());
  }

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _silentReload() async {
    try {
      final results = await Future.wait([
        widget.api.hasiaPharmacyStock(widget.pharmacy),
        widget.api.hasiaPharmacyRx(widget.pharmacy),
      ]);
      if (!mounted) return;
      setState(() {
        _stock = Future.value(results[0]);
        _rx = Future.value(results[1]);
      });
    } catch (_) {
      // Keep the last good lists; the next tick retries.
    }
  }

  Future<void> _reload() async {
    setState(() {
      _stock = widget.api.hasiaPharmacyStock(widget.pharmacy);
      _rx = widget.api.hasiaPharmacyRx(widget.pharmacy);
    });
    await Future.wait([_stock!, _rx!]);
  }

  Future<void> _dispenseFromRx(Map<String, dynamic> rx) async {
    try {
      await widget.api.hasiaDispense({
        'pharmacy': widget.pharmacy,
        'inmateNo': rx['inmateNo'],
        'drugName': rx['drugName'],
        'quantity': rx['quantity'],
        'caseCode': rx['caseCode'],
        'prescriptionId': rx['id'],
        'by': 'mobile',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الصرف')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _manualDispense() async {
    final inmate = TextEditingController();
    final drug = TextEditingController();
    final qty = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('صرف يدوي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: inmate, decoration: const InputDecoration(labelText: 'رقم النزيل')),
            const SizedBox(height: 8),
            TextField(controller: drug, decoration: const InputDecoration(labelText: 'اسم الدواء')),
            const SizedBox(height: 8),
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('صرف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.hasiaDispense({
        'pharmacy': widget.pharmacy,
        'inmateNo': inmate.text.trim(),
        'drugName': drug.text.trim(),
        'quantity': int.tryParse(qty.text.trim()) ?? 1,
        'by': 'mobile',
      });
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pharmacy == 'external' ? 'الصيدلية الخارجية' : 'الصيدلية الداخلية';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'المخزون'),
            Tab(text: 'الوصفات'),
          ],
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _manualDispense,
        icon: const Icon(Icons.outbox_outlined),
        label: const Text('صرف'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          FutureBuilder<List<dynamic>>(
            future: _stock,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'.replaceFirst('Exception: ', '')));
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) return const Center(child: Text('لا يوجد مخزون'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = Map<String, dynamic>.from(rows[i] as Map);
                  final qty = m['quantity'] is int
                      ? m['quantity'] as int
                      : int.tryParse('${m['quantity']}') ?? 0;
                  final low = qty <= 10;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: low ? MsdColors.amber.withValues(alpha: 0.5) : MsdColors.line),
                      ),
                      title: Text(m['drugName']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                      trailing: Text(
                        '$qty',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: low ? MsdColors.amber : MsdColors.teal,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FutureBuilder<List<dynamic>>(
            future: _rx,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done && !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('${snap.error}'.replaceFirst('Exception: ', '')));
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) return const Center(child: Text('لا توجد وصفات معلّقة'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = Map<String, dynamic>.from(rows[i] as Map);
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: MsdColors.line),
                      ),
                      title: Text(
                        '${m['drugName'] ?? ''} × ${m['quantity'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text('نزيل ${m['inmateNo'] ?? ''} · ${m['doctor'] ?? m['caseCode'] ?? ''}'),
                      trailing: FilledButton(
                        onPressed: () => _dispenseFromRx(m),
                        child: const Text('صرف'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
