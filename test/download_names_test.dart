import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/utils/download_names.dart';

void main() {
  group('fileNameFromUrl', () {
    test('取最后一段路径', () {
      expect(fileNameFromUrl('https://example.com/a/b/img.png'), 'img.png');
    });

    test('丢掉 query 与 fragment', () {
      expect(
        fileNameFromUrl('https://example.com/img.png?w=800&h=600#top'),
        'img.png',
      );
    });

    test('百分号编码会被还原', () {
      expect(fileNameFromUrl('https://example.com/a%20b.png'), 'a b.png');
    });

    test('非法字符替换成下划线', () {
      // 注意不要用 `?`：那会变成 query，测的就不是路径里的字符了
      expect(
        fileNameFromUrl('https://example.com/a:b|c*d".png'),
        'a_b_c_d_.png',
      );
    });

    test('取不到文件名时退回 image', () {
      expect(fileNameFromUrl('https://example.com/'), 'image');
      expect(fileNameFromUrl(''), 'image');
    });

    test('编码非法不抛异常', () {
      expect(fileNameFromUrl('https://example.com/%zz.png'), '%zz.png');
    });
  });

  group('uniqueFileNamesFor', () {
    test('同名时在扩展名前加序号', () {
      final names = uniqueFileNamesFor([
        'https://a.com/img.png',
        'https://b.com/img.png',
        'https://c.com/img.png',
      ]);

      expect(names, ['img.png', 'img-2.png', 'img-3.png']);
    });

    test('无扩展名也能去重', () {
      final names = uniqueFileNamesFor([
        'https://a.com/image',
        'https://b.com/image',
      ]);

      expect(names, ['image', 'image-2']);
    });

    test('顺序与入参一致，且不同名不受影响', () {
      final names = uniqueFileNamesFor([
        'https://a.com/x.png',
        'https://a.com/y.jpg',
        'https://a.com/x.png',
      ]);

      expect(names, ['x.png', 'y.jpg', 'x-2.png']);
    });

    test('跨多个不同目录也不会撞名', () {
      final names = uniqueFileNamesFor([
        'https://a.com/1/img.png',
        'https://a.com/2/img.png',
        'https://a.com/3/img.png',
        'https://a.com/4/img.png',
      ]);

      expect(names.toSet().length, 4, reason: '文件名必须互不相同');
    });
  });
}
