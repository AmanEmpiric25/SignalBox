import 'package:flutter_test/flutter_test.dart';
import 'package:signalbox/core/extensions/string_x.dart';

void main() {
  group('StringX', () {
    test('normalised collapses whitespace and trims', () {
      expect('  two   words \n here '.normalised, 'two words here');
    });

    test('truncate leaves short strings untouched', () {
      expect('short'.truncate(10), 'short');
    });

    test('truncate adds an ellipsis to long strings', () {
      expect('abcdefghij'.truncate(4), 'abcd…');
    });

    test('packageLabel capitalises the last package segment', () {
      expect('com.whatsapp'.packageLabel, 'Whatsapp');
      expect('com.google.android.gm'.packageLabel, 'Gm');
    });

    test('packageLabel tolerates input without dots', () {
      expect('slack'.packageLabel, 'Slack');
    });

    test('isBlank is true for whitespace only', () {
      expect('   \n '.isBlank, isTrue);
      expect(' a '.isBlank, isFalse);
    });
  });
}
