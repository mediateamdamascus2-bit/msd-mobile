/// Shared booking lists used when the server catalog is unavailable.
abstract final class BookingCatalog {
  static const entities = [
    'وزارة الداخلية',
    'وزارة الدفاع',
    'موقوف',
    'مدني',
  ];

  static const legalOptions = [
    'مدني',
    'داخلية',
    'دفاع',
    'قرابة داخلية',
    'موقوف',
  ];

  static const kinshipOptions = ['أب', 'أم', 'زوجة', 'ابن', 'ابنة'];

  static const interiorAdmins = [
    'إدارة الخدمات الطبية',
    'قيادة شرطة دمشق',
    'قيادة شرطة ريف دمشق',
    'إدارة السجون',
    'إدارة المرور',
    'إدارة الهجرة والجوازات',
    'الأمن الجنائي',
  ];

  static const governorates = [
    'دمشق',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'درعا',
    'السويداء',
    'القنيطرة',
    'دير الزور',
    'الرقة',
    'الحسكة',
  ];

  static const legalOfEntity = <String, String>{
    'وزارة الداخلية': 'داخلية',
    'وزارة الدفاع': 'دفاع',
    'موقوف': 'موقوف',
    'مدني': 'مدني',
  };

  static bool requiresAdmin(String entity) =>
      entity != 'وزارة الدفاع' && entity != 'مدني';

  /// C# [DayOfWeek] uses Sunday = 0 … Saturday = 6.
  static int csharpDayOfWeek(DateTime d) => d.weekday % 7;
}
