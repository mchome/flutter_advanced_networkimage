import 'package:test/test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_advanced_networkimage/src/flutter_advanced_networkimage.dart';

void main() {
  group('Download Test', () {
    test('=> good url', () async {
      var url =
          'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png';
      var res = (await http.get(url)).bodyBytes;

      expect(
          await loadFromRemote(url, null, 5, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              printError: true),
          res);
    });

    test('=> bad url', () async {
      var url =
          'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Marks.png';

      expect(
          await loadFromRemote(url, null, 0, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              printError: true),
          null);
    });

    test('=> not a url', () async {
      var url = '/GitHub-Marks.png';

      expect(
          await loadFromRemote(url, null, 0, const Duration(milliseconds: 100),
              1.0, const Duration(seconds: 5), null, null,
              printError: true),
          null);
    });
  });
}
