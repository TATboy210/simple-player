/// Trusted source-root containment and excerpt tests.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_location.dart';
import 'package:simple_player_flutter/kernel/diagnostics/source_line_reader.dart';

void main() {
  group('SourceLineReader', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('source-line-reader-');
      Directory('${root.path}/lib/kernel').createSync(recursive: true);
      File('${root.path}/lib/kernel/example.dart').writeAsStringSync(
        List<String>.generate(7, (index) => 'line ${index + 1}').join('\n'),
      );
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    test(
      'reads numbered target plus/minus two lines and clamps file edges',
      () {
        // Arrange
        final reader = SourceLineReader.forTesting(
          trustedRoot: root.path,
          buildMode: SourceReadBuildMode.debug,
        );

        // Act
        final middle = reader.read(_packageFrame(line: 4));
        final start = reader.read(_packageFrame(line: 1));
        final end = reader.read(_packageFrame(line: 7));

        // Assert
        expect(middle?.lines.map((line) => line.lineNumber), [2, 3, 4, 5, 6]);
        expect(middle?.lines.map((line) => line.text), [
          'line 2',
          'line 3',
          'line 4',
          'line 5',
          'line 6',
        ]);
        expect(start?.lines.map((line) => line.lineNumber), [1, 2, 3]);
        expect(end?.lines.map((line) => line.lineNumber), [5, 6, 7]);
        expect(
          () => middle?.lines.add(const SourceLine(lineNumber: 8, text: 'bad')),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'rejects traversal, sibling prefixes, absolute escape, and invalid lines',
      () {
        // Arrange
        final reader = SourceLineReader.forTesting(
          trustedRoot: root.path,
          buildMode: SourceReadBuildMode.profile,
        );
        final sibling = Directory('${root.path}-evil')..createSync();
        addTearDown(() => sibling.deleteSync(recursive: true));
        final siblingFile = File('${sibling.path}/outside.dart')
          ..writeAsStringSync('x');

        // Act and assert
        expect(
          reader.read(_packageFrame(path: '../outside.dart', line: 1)),
          isNull,
        );
        expect(reader.read(_fileFrame(siblingFile.path, line: 1)), isNull);
        expect(reader.read(_fileFrame('C:/outside.dart', line: 1)), isNull);
        expect(
          reader.read(_packageFrame(path: 'missing.dart', line: 1)),
          isNull,
        );
        expect(reader.read(_packageFrame(line: 0)), isNull);
        expect(reader.read(_packageFrame(line: 8)), isNull);
      },
    );

    test(
      'normalizes a Windows file URI form for case-insensitive containment',
      () {
        // Arrange
        final access = _RecordingAccess(
          canonicalPaths: {
            'd:/app': 'D:/App',
            'd:/app/lib/kernel/example.dart': 'D:/App/lib/kernel/example.dart',
          },
          lines: ['first'],
        );
        final reader = SourceLineReader.forTesting(
          trustedRoot: 'd:/app',
          buildMode: SourceReadBuildMode.debug,
          fileAccess: access,
        );

        // Act
        final excerpt = reader.read(
          _fileFrame('/D:/APP/lib/kernel/example.dart', line: 1),
        );

        // Assert
        expect(excerpt?.lines.single.text, 'first');
      },
    );

    test(
      'resolves an owned package config for production-style package frames',
      () {
        // Arrange
        final packageConfig =
            File('${root.path}/.dart_tool/package_config.json')
              ..parent.createSync(recursive: true)
              ..writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "simple_player_flutter",
      "rootUri": "../",
      "packageUri": "lib/"
    }
  ]
}
''');
        const fileAccess = DartIoSourceFileAccess();
        final reader = SourceLineReader.fromPackageConfigForTesting(
          buildMode: SourceReadBuildMode.debug,
          fileAccess: fileAccess,
          packageConfigAccess: _PackageConfigAccess(
            packageConfigPath: packageConfig.uri.toString(),
          ),
        );

        // Act
        final excerpt = reader.read(_packageFrame(line: 4));

        // Assert
        expect(excerpt?.lines.map((line) => line.text), [
          'line 2',
          'line 3',
          'line 4',
          'line 5',
          'line 6',
        ]);
      },
    );

    test(
      'does no file access in release and degrades without a trusted root',
      () {
        // Arrange
        final releaseAccess = _RecordingAccess(lines: ['must not read']);
        final releaseReader = SourceLineReader.forTesting(
          trustedRoot: root.path,
          buildMode: SourceReadBuildMode.release,
          fileAccess: releaseAccess,
        );
        final untrustedReader = SourceLineReader.forTesting(
          trustedRoot: null,
          buildMode: SourceReadBuildMode.debug,
          fileAccess: _RecordingAccess(lines: ['must not read']),
        );

        // Act and assert
        expect(releaseReader.read(_packageFrame(line: 1)), isNull);
        expect(releaseAccess.calls, 0);
        expect(untrustedReader.read(_packageFrame(line: 1)), isNull);
      },
    );
  });
}

/// Creates a parsed package frame matching the application-owned source form.
ErrorLocationFrame _packageFrame({
  String path = 'kernel/example.dart',
  int line = 1,
}) {
  return ErrorLocationFrame(
    file: 'package:simple_player_flutter/$path',
    packageScheme: 'package',
    package: 'simple_player_flutter',
    packagePath: path,
    line: line,
    column: 1,
    member: 'Example.run',
  );
}

/// Creates a file frame to exercise absolute path containment separately.
ErrorLocationFrame _fileFrame(String path, {required int line}) {
  return ErrorLocationFrame(
    file: 'file:$path',
    packageScheme: 'file',
    package: '<unknown>',
    packagePath: path,
    line: line,
    column: 1,
    member: 'Example.run',
  );
}

/// Runtime package-config seam that keeps production-style package resolution deterministic.
final class _PackageConfigAccess implements SourcePackageConfigAccess {
  const _PackageConfigAccess({required this.packageConfigPath});

  @override
  final String packageConfigPath;

  @override
  bool hasSourceDirectory(String root) => Directory('$root/lib').existsSync();

  @override
  String? readConfig(String packageConfigPath) {
    final uri = Uri.tryParse(packageConfigPath);
    return uri == null ? null : File.fromUri(uri).readAsStringSync();
  }
}

/// Test seam that records every prospective filesystem operation.
final class _RecordingAccess implements SourceFileAccess {
  _RecordingAccess({this.canonicalPaths = const {}, required this.lines});

  final Map<String, String> canonicalPaths;
  final List<String> lines;
  int calls = 0;

  @override
  String? canonicalize(String path) {
    calls += 1;
    return canonicalPaths[_key(path)] ?? path;
  }

  @override
  List<String>? readLines(String path) {
    calls += 1;
    return lines;
  }

  String _key(String value) => value.replaceAll('\\', '/').toLowerCase();
}
