/// Conservative stored-stack location extraction tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_location.dart';

void main() {
  group('extractErrorLocation', () {
    test(
      'selects the first project frame and two following project frames',
      () {
        // Arrange
        const rawStack = '''
#0 _Sdk.thrower (dart:core/errors.dart:12:3)
#1 Foreign.call (package:foreign/foreign.dart:8:2)
#2 FirstProject.run (package:simple_player_flutter/kernel/first.dart:42:7)
#3 SecondProject.run (package:simple_player_flutter/kernel/second.dart:43:8)
#4 ThirdProject.run (package:simple_player_flutter/kernel/third.dart:44:9)
#5 FourthProject.run (package:simple_player_flutter/kernel/fourth.dart:45:10)''';

        // Act
        final location = extractErrorLocation(rawStack);

        // Assert
        expect(location, isNotNull);
        expect(location?.primaryFrame.packagePath, 'kernel/first.dart');
        expect(location?.primaryFrame.line, 42);
        expect(location?.primaryFrame.column, 7);
        expect(location?.primaryFrame.member, 'FirstProject.run');
        expect(
          location?.primaryFrame.file,
          'package:simple_player_flutter/kernel/first.dart',
        );
        expect(location?.secondaryFrames, hasLength(2));
        expect(location?.secondaryFrames.map((frame) => frame.packagePath), [
          'kernel/second.dart',
          'kernel/third.dart',
        ]);
        expect(
          () => location?.secondaryFrames.add(location.primaryFrame),
          throwsUnsupportedError,
        );
      },
    );

    test('skips malformed VM lines without changing frozen raw evidence', () {
      // Arrange
      const rawStack = '''
#0 malformed VM line
#1 Project.run (package:simple_player_flutter/kernel/good.dart:20:5)
#2 also malformed''';

      // Act
      final location = extractErrorLocation(rawStack);

      // Assert
      expect(rawStack, '''
#0 malformed VM line
#1 Project.run (package:simple_player_flutter/kernel/good.dart:20:5)
#2 also malformed''');
      expect(location?.primaryFrame.packagePath, 'kernel/good.dart');
    });

    test(
      'returns the stable null fallback for non-project or degraded stacks',
      () {
        // Arrange
        const inputs = [
          '',
          '[unavailable original stack: no original throw-site stack was supplied]',
          '<asynchronous suspension>',
          '...',
          '#0 Other.run (package:foreign/other.dart:8:2)',
          '===== asynchronous gap ===========================',
          '#0 malformed VM line',
        ];

        // Act and assert
        for (final rawStack in inputs) {
          expect(extractErrorLocation(rawStack), isNull, reason: rawStack);
        }
      },
    );
  });
}
