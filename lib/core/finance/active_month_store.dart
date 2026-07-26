import 'package:hive/hive.dart';

class ActiveMonthStore {
  static const String _boxName = 'active_month';
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);

    if (!_box.containsKey('monthKey')) {
      final now = DateTime.now();
      _box.put(
        'monthKey',
        '${now.year}-${now.month.toString().padLeft(2, '0')}',
      );
    }
  }

  static String get current =>
      _box.get('monthKey');

  static void set(String monthKey) {
    _box.put('monthKey', monthKey);
  }

  static void advanceToNextMonth() {
    final parts = current.split('-');
    int year = int.parse(parts[0]);
    int month = int.parse(parts[1]);

    month++;
    if (month == 13) {
      month = 1;
      year++;
    }

    set('$year-${month.toString().padLeft(2, '0')}');
  }
}
