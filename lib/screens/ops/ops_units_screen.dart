import 'package:flutter/material.dart';

import '../../api_client.dart';
import 'ops_med_points.dart';

/// الوحدات الطبية — read-only monitoring.
class OpsUnitsScreen extends StatelessWidget {
  const OpsUnitsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) => OpsMedPointsScreen(api: api, kind: OpsPointKind.unit);
}
