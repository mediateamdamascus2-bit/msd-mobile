/// Tracks item ids across periodic refreshes and reports the ones that are new.
/// The first call only primes the set, so opening a screen never floods notifications.
class NewItemWatcher {
  final _seen = <String>{};
  var _primed = false;

  /// Marks items as seen without reporting them (e.g. after the user's own action).
  void absorb(List<dynamic> items, {String idKey = 'id'}) {
    for (final m in items.whereType<Map>()) {
      final id = m[idKey]?.toString();
      if (id != null && id.isNotEmpty) _seen.add(id);
    }
    _primed = true;
  }

  /// Returns the items whose id was not seen in any earlier call.
  List<Map<String, dynamic>> diff(List<dynamic> items, {String idKey = 'id'}) {
    final maps = items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final fresh = <Map<String, dynamic>>[];
    for (final m in maps) {
      final id = m[idKey]?.toString();
      if (id == null || id.isEmpty) continue;
      if (_seen.add(id) && _primed) fresh.add(m);
    }
    _primed = true;
    return fresh;
  }
}
