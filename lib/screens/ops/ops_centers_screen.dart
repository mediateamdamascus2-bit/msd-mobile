import 'package:flutter/material.dart';

import '../../api_client.dart';
import 'ops_med_points.dart';

/// مراكز الرعاية الطبية — read-only monitoring.
class OpsCentersScreen extends StatelessWidget {
  const OpsCentersScreen({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) => OpsMedPointsScreen(api: api, kind: OpsPointKind.center);
}
