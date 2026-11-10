import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';

/// Driver desk from `/api/directorate/state` (`fleet.drivers` / `fleet.missions`).
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.api,
    required this.user,
    required this.driverId,
    this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final String driverId;
  final Future<void> Function()? onLogout;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  Map<String, dynamic>? _driver;
  List<Map<String, dynamic>> _missions = const [];
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await widget.api.directorateState();
      final fleet = state?['fleet'];
      final drivers = fleet is Map ? fleet['drivers'] : null;
      final missions = fleet is Map ? fleet['missions'] : null;
      Map<String, dynamic>? mine;
      if (drivers is List) {
        for (final row in drivers) {
          if (row is Map && row['id']?.toString() == widget.driverId) {
            mine = Map<String, dynamic>.from(row);
            break;
          }
        }
      }
      final list = <Map<String, dynamic>>[];
      if (missions is List) {
        for (final row in missions) {
          if (row is! Map) continue;
          final id = row['driverId']?.toString();
          if (id == null || id.isEmpty || id == widget.driverId) {
            list.add(Map<String, dynamic>.from(row));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _driver = mine;
        _missions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _driver?['name']?.toString() ??
        widget.user['displayNameAr']?.toString() ??
        widget.driverId;
    return Scaffold(
      backgroundColor: MsdColors.mist,
      appBar: AppBar(
        title: const Text('مهمة السائق'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          if (widget.onLogout != null)
            TextButton(onPressed: widget.onLogout, child: const Text('خروج')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(name, style: GoogleFonts.tajawal(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('السائق ${widget.driverId}', style: GoogleFonts.tajawal(color: MsdColors.sub)),
                if (_driver?['status'] != null) ...[
                  const SizedBox(height: 8),
                  Text('الحالة: ${_driver!['status']}', style: GoogleFonts.tajawal()),
                ],
                const SizedBox(height: 18),
                Text('المهام', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(_error!, style: GoogleFonts.tajawal(color: MsdColors.danger))
                else if (_missions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text('لا توجد بيانات — لا مهام مسجّلة لهذا السائق'),
                  )
                else
                  for (final m in _missions)
                    Card(
                      child: ListTile(
                        title: Text(m['title']?.toString() ?? m['id']?.toString() ?? 'مهمة', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [
                            m['status']?.toString(),
                            m['from']?.toString(),
                            m['to']?.toString(),
                            m['vehicle']?.toString() ?? m['vehicleId']?.toString(),
                          ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          style: GoogleFonts.tajawal(),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}
