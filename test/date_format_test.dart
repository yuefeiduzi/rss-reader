import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/utils/date_format.dart';

void main() {
  group('formatDate / formatDateTime', () {
    test('本地时间按其自身分量输出，不做二次转换', () {
      final local = DateTime(2026, 9, 16, 8, 30);
      expect(formatDate(local), '2026-09-16');
      expect(formatDateTime(local), '2026-09-16 08:30');
    });

    test('UTC 时间按本地时区显示（旧实现漏了 toLocal）', () {
      final utc = DateTime.utc(2026, 9, 16, 0, 30);
      final local = utc.toLocal();

      expect(formatDateTime(utc), formatDateTime(local));
      expect(
        formatDateTime(utc),
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}',
      );
    });

    test('月份/日期/时分补零', () {
      expect(formatDateTime(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
    });
  });

  group('formatRelativeDate', () {
    test('一小时内显示分钟', () {
      final date = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeDate(date), '5分钟前');
    });

    test('一天内显示小时', () {
      final date = DateTime.now().subtract(const Duration(hours: 3));
      expect(formatRelativeDate(date), '3小时前');
    });

    test('一周内显示天', () {
      final date = DateTime.now().subtract(const Duration(days: 2));
      expect(formatRelativeDate(date), '2天前');
    });

    test('超过一周回退到日期', () {
      final date = DateTime.now().subtract(const Duration(days: 30));
      expect(formatRelativeDate(date), formatDate(date));
    });

    test('未来时间不显示负数', () {
      final date = DateTime.now().add(const Duration(hours: 2));
      expect(formatRelativeDate(date), formatDateTime(date));
      expect(formatRelativeDate(date), isNot(contains('前')));
    });
  });
}