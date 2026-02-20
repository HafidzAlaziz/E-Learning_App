class IndonesiaHolidays {
  static final Map<DateTime, String> holidays2026 = {
    DateTime(2026, 1, 1): "Tahun Baru 2026 Masehi",
    DateTime(2026, 1, 16): "Isra Mikraj Nabi Muhammad SAW",
    DateTime(2026, 2, 16): "Cuti Bersama Tahun Baru Imlek 2577 Kongzili",
    DateTime(2026, 2, 17): "Tahun Baru Imlek 2577 Kongzili",
    DateTime(2026, 3, 18):
        "Cuti Bersama Hari Suci Nyepi (Tahun Baru Saka 1948)",
    DateTime(2026, 3, 19): "Hari Suci Nyepi (Tahun Baru Saka 1948)",
    DateTime(2026, 3, 20): "Cuti Bersama Idul Fitri 1447 H",
    DateTime(2026, 3, 21): "Hari Raya Idul Fitri 1447 H",
    DateTime(2026, 3, 22): "Hari Raya Idul Fitri 1447 H",
    DateTime(2026, 3, 23): "Cuti Bersama Idul Fitri 1447 H",
    DateTime(2026, 3, 24): "Cuti Bersama Idul Fitri 1447 H",
    DateTime(2026, 4, 3): "Wafat Yesus Kristus (Jumat Agung)",
    DateTime(2026, 4, 5): "Kebangkitan Yesus Kristus (Paskah)",
    DateTime(2026, 5, 1): "Hari Buruh Internasional",
    DateTime(2026, 5, 14): "Kenaikan Yesus Kristus",
    DateTime(2026, 5, 15): "Cuti Bersama Kenaikan Yesus Kristus",
    DateTime(2026, 5, 27): "Idul Adha 1447 H",
    DateTime(2026, 5, 28): "Cuti Bersama Idul Adha 1447 H",
    DateTime(2026, 5, 31): "Hari Raya Waisak 2570 BE",
    DateTime(2026, 6, 1): "Hari Lahir Pancasila",
    DateTime(2026, 6, 16): "1 Muharam Tahun Baru Islam 1448 H",
    DateTime(2026, 8, 17): "Proklamasi Kemerdekaan RI",
    DateTime(2026, 8, 25): "Maulid Nabi Muhammad SAW",
    DateTime(2026, 12, 24): "Cuti Bersama Natal",
    DateTime(2026, 12, 25): "Kelahiran Yesus Kristus (Natal)",
  };

  static List<Map<String, dynamic>> getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    List<Map<String, dynamic>> events = [];

    // Check for hardcoded holidays
    if (holidays2026.containsKey(dateKey)) {
      events.add({
        'title': holidays2026[dateKey],
        'type': 'holiday',
        'description': 'Hari Libur Nasional / Cuti Bersama 2026',
      });
    }

    // Check for Sunday (Weekend)
    if (day.weekday == DateTime.sunday) {
      // Avoid duplicate if it's already a holiday
      if (!events.any((e) => e['title'] == holidays2026[dateKey])) {
        events.add({
          'title': "Libur Akhir Pekan",
          'type': 'holiday',
          'description': 'Hari Minggu',
        });
      }
    }

    return events;
  }

  static bool isHoliday(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return holidays2026.containsKey(dateKey) || day.weekday == DateTime.sunday;
  }
}
