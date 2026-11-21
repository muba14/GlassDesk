/// Türkçe tarih adları ve takvim yardımcıları.
/// Ek paket (intl) gerektirmemek için elle tanımlı.
class TrDate {
  TrDate._();

  static const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const days = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  static const shortDays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  static String month(int month) => months[month - 1];

  static String day(DateTime date) => days[date.weekday - 1];

  static String shortDay(DateTime date) => shortDays[date.weekday - 1];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// Örn. "21 Kasım 2026"
  static String longDate(DateTime d) => '${d.day} ${month(d.month)} ${d.year}';
}

/// Pazartesi ile başlayan aylık takvim ızgarası. Ayın ilk gününden
/// önceki ve son gününden sonraki boş hücreler `null` olur; uzunluk her
/// zaman 7'nin katıdır.
List<DateTime?> monthGrid(int year, int month) {
  final first = DateTime(year, month, 1);
  final leading = first.weekday - 1;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final cells = <DateTime?>[
    for (var i = 0; i < leading; i++) null,
    for (var d = 1; d <= daysInMonth; d++) DateTime(year, month, d),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return cells;
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
