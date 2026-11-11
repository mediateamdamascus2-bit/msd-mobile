import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme/app_theme.dart';
import '../theme/msd_widgets.dart';
import 'hasia_cases_screen.dart';
import 'hasia_inmates_screen.dart';
import 'hasia_pharmacy_screen.dart';

class HasiaHubScreen extends StatelessWidget {
  const HasiaHubScreen({
    super.key,
    required this.api,
    required this.user,
    this.onLogout,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function()? onLogout;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final name = user['displayNameAr']?.toString() ?? 'مسؤول طبي';
    final items = <_HasiaTile>[
      _HasiaTile(
        'سجل النزلاء',
        'الأضابير الطبية وتسجيل نزيل',
        Icons.groups_outlined,
        () => _open(context, HasiaInmatesScreen(api: api, user: user)),
      ),
      _HasiaTile(
        'الفرز والحالات',
        'فتح فرز ومتابعة خطوات الحالة',
        Icons.monitor_heart_outlined,
        () => _open(context, HasiaCasesScreen(api: api, user: user)),
      ),
      _HasiaTile(
        'الصيدلية الداخلية',
        'مخزون ووصفات النقطة الطبية',
        Icons.medication_outlined,
        () => _open(context, HasiaPharmacyScreen(api: api, pharmacy: 'internal')),
      ),
      _HasiaTile(
        'الصيدلية الخارجية',
        'مخزون ووصفات مشفى السجن',
        Icons.local_pharmacy_outlined,
        () => _open(context, HasiaPharmacyScreen(api: api, pharmacy: 'external')),
      ),
    ];

    return Scaffold(
      backgroundColor: MsdColors.mist,
      body: CustomScrollView(
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
                  const MsdHIcon(size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجن حسيا',
                          style: TextStyle(
                            color: MsdTokens.onDeep,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'الخدمات الطبية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          name,
                          style: TextStyle(color: MsdTokens.onDeep, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (Navigator.of(context).canPop())
                    IconButton(
                      tooltip: 'رجوع',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    )
                  else if (onLogout != null)
                    TextButton(
                      onPressed: onLogout,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        onTap: item.onTap,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: MsdColors.line),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: MsdColors.cyan.withValues(alpha: 0.15),
                          child: Icon(item.icon, color: MsdColors.teal),
                        ),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(item.subtitle),
                        trailing: const Icon(Icons.chevron_left),
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HasiaTile {
  const _HasiaTile(this.title, this.subtitle, this.icon, this.onTap);
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
