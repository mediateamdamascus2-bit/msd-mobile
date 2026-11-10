import 'package:flutter/material.dart';

import '../api_client.dart';
import 'admissions_screen.dart';
import 'harasta_hub_screen.dart';
import 'hasia_hub_screen.dart';
import 'reception_screen.dart';

class FacilityScreen extends StatefulWidget {
  const FacilityScreen({super.key, required this.api, required this.facilityId});

  final ApiClient api;
  final String facilityId;

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.facility(widget.facilityId);
  }

  bool _isMedicalUnit(Map<String, dynamic> f) {
    final type = f['type']?.toString().toLowerCase() ?? '';
    final typeAr = f['typeAr']?.toString() ?? '';
    return type.contains('medicalunit') || typeAr.contains('نقطة');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('منشأة ${widget.facilityId}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final f = snap.data!;
          final profile = f['profile'] as Map<String, dynamic>? ?? {};
          final kpis = (profile['kpis'] as List?) ?? const [];
          final name = f['nameAr']?.toString() ?? widget.facilityId;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '${profile['eyebrow'] ?? ''} · ${f['provinceAr'] ?? ''}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(profile['overviewLead']?.toString() ?? ''),
              if (widget.facilityId == 'harasta') ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HarastaHubScreen(
                          api: widget.api,
                          user: const {'displayNameAr': 'مدير المنشأة', 'facilityId': 'harasta'},
                          onLogout: () async {},
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('لوحة حرستا الكاملة'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceptionScreen(
                          api: widget.api,
                          facilityId: widget.facilityId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('الاستقبال'),
                ),
              ],
              if (widget.facilityId == 'hasia') ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HasiaHubScreen(
                          api: widget.api,
                          user: const {'displayNameAr': 'المسؤول الطبي', 'facilityId': 'hasia'},
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('خدمات حسيا الطبية'),
                ),
              ],
              if (_isMedicalUnit(f)) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdmissionsScreen(
                          api: widget.api,
                          facilityId: widget.facilityId,
                          facilityName: name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.hotel_class_outlined),
                  label: const Text('إشغالات القبول'),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kpis.map((raw) {
                  final k = raw as Map<String, dynamic>;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 48) / 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              k['value']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              k['label']?.toString() ?? '',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
