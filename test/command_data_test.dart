import 'package:flutter_test/flutter_test.dart';
import 'package:msd_mobile/data/command_data.dart';
import 'package:msd_mobile/services/new_item_watcher.dart';

void main() {
  test('NewItemWatcher primes on first call and reports only new ids after', () {
    final w = NewItemWatcher();
    expect(w.diff([{'id': 'a'}, {'id': 'b'}]), isEmpty);
    final fresh = w.diff([{'id': 'a'}, {'id': 'b'}, {'id': 'c'}]);
    expect(fresh.map((e) => e['id']), ['c']);
    expect(w.diff([{'id': 'c'}]), isEmpty);
  });

  test('NewItemWatcher.absorb hides items from the next diff', () {
    final w = NewItemWatcher()..absorb([{'caseCode': 'X1'}], idKey: 'caseCode');
    expect(w.diff([{'caseCode': 'X1'}, {'caseCode': 'X2'}], idKey: 'caseCode').length, 1);
  });

  test('CommandData event helpers follow server status/severity values', () {
    expect(CommandData.isOpen({'status': 'مفتوح', 'closedAt': null}), isTrue);
    expect(CommandData.isOpen({'status': 'مغلق', 'closedAt': '2026-11-07T10:00:00Z'}), isFalse);
    expect(CommandData.severityRank({'severity': 'عاجل'}), 0);
    expect(CommandData.severityRank({'severity': 'متوسط'}), 1);
    expect(CommandData.severityRank({'severity': 'عادي'}), 2);
  });

  test('CommandData aggregates events across facilities, newest first', () {
    final d = CommandData(
      facilities: [
        {'id': 'h1', 'type': CommandData.hospital, 'nameAr': 'مشفى', 'provinceAr': 'دمشق'},
        {'id': 'w1', 'type': CommandData.warehouse, 'nameAr': 'مستودع', 'provinceAr': 'حلب'},
      ],
      events: {
        'h1': [{'id': '1', 'createdAt': '2026-11-07T08:00:00Z'}],
        'w1': [{'id': '2', 'createdAt': '2026-11-07T09:00:00Z'}],
      },
      needs: {'h1': null, 'w1': const []},
      fleet: {'h1': null, 'w1': null},
      stores: {'h1': null, 'w1': null},
      inmates: null,
      fetchedAt: DateTime(2026, 11, 7),
    );
    expect(d.allEvents.map((e) => e['id']), ['2', '1']);
    expect(d.allEvents.first['facilityId'], 'w1');
    expect(d.ofType(CommandData.hospital).length, 1);
    expect(d.hasFleet, isFalse);
    expect(d.hasNeeds, isTrue);
    expect(d.provinceOf('w1'), 'حلب');
  });
}
