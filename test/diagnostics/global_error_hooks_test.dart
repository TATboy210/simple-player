/// Behavioral tests for global Flutter and dispatcher diagnostic hooks.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporter.dart';
import 'package:simple_player_flutter/kernel/diagnostics/error_reporting_dependencies.dart';
import 'package:simple_player_flutter/kernel/diagnostics/global_error_hooks.dart';
import 'package:simple_player_flutter/kernel/models/player_error.dart';
import 'package:simple_player_flutter/main.dart' show BootstrapErrorFallback;

void main() {
  group('GlobalErrorHooks', () {
    test('declares guarded bootstrap installation ordering in main source', () {
      // Arrange
      final source = File('lib/main.dart').readAsStringSync();

      // Assert
      expect(
        source.indexOf('runZonedGuarded<Future<void>>'),
        greaterThanOrEqualTo(0),
      );
      expect(
        source.indexOf('ErrorReporterImpl.init()'),
        greaterThanOrEqualTo(0),
      );
      expect(
        source.indexOf('GlobalErrorHooks.install(ErrorReporterImpl.I)'),
        greaterThanOrEqualTo(0),
      );
      expect(
        source.indexOf('ErrorReporterImpl.init()'),
        lessThan(
          source.indexOf('GlobalErrorHooks.install(ErrorReporterImpl.I)'),
        ),
      );
    });

    test('declares bootstrap fallback containment helpers in main source', () {
      // Arrange
      final source = File('lib/main.dart').readAsStringSync();

      // Assert
      expect(source, contains('BootstrapErrorFallback'));
      expect(source, contains('reportBootstrapSafely'));
      expect(source, contains('isInitialized'));
      expect(source, contains('windowInitError ='));
    });

    test(
      'contains unavailable reporter fallback and throwing terminal output',
      () {
        // Arrange
        final outputs = <Object>[];

        // Act
        BootstrapErrorFallback.reportWith(
          StateError('bootstrap failure'),
          StackTrace.current,
          isReporterInitialized: () => false,
          reportInitialized: (_, _) => fail('reporter must not be accessed'),
          lastResortOutput: (error, _) => outputs.add(error),
        );

        // Assert
        expect(outputs.single, isA<StateError>());
        expect(
          () => BootstrapErrorFallback.reportWith(
            StateError('bootstrap failure'),
            StackTrace.current,
            isReporterInitialized: () => throw StateError('probe failed'),
            reportInitialized: (_, _) => fail('reporter must not be accessed'),
            lastResortOutput: (_, _) => throw StateError('output failed'),
          ),
          returnsNormally,
        );
      },
    );

    test('delegates an initialized bootstrap error once', () {
      // Arrange
      final reported = <Object>[];
      final error = StateError('bootstrap failure');

      // Act
      BootstrapErrorFallback.reportWith(
        error,
        StackTrace.current,
        isReporterInitialized: () => true,
        reportInitialized: (failure, _) => reported.add(failure),
        lastResortOutput: (_, _) => fail('fallback must not run'),
      );

      // Assert
      expect(reported, [same(error)]);
    });

    test(
      'presents framework details before forwarding them to the reporter',
      () {
        // Arrange
        final calls = <String>[];
        final reporter = _RecordingReporter(calls: calls);
        FlutterExceptionHandler? frameworkCallback;
        PlatformErrorCallback? dispatcherCallback;
        final hooks = GlobalErrorHooks.forTesting(
          setFrameworkErrorHandler: (callback) => frameworkCallback = callback,
          setPlatformErrorHandler: (callback) => dispatcherCallback = callback,
          presentFrameworkError: (details) {
            calls.add('present');
            expect(details.exception, isA<StateError>());
          },
        );

        // Act
        hooks.installCallbacks(reporter);
        frameworkCallback?.call(
          FlutterErrorDetails(exception: StateError('framework failure')),
        );

        // Assert
        expect(dispatcherCallback, isNotNull);
        expect(calls, ['present', 'flutter']);
        expect(reporter.flutterDetails.single.exception, isA<StateError>());
      },
    );

    test('forwards exact dispatcher error and stack then returns true', () {
      // Arrange
      final reporter = _RecordingReporter();
      FlutterExceptionHandler? frameworkCallback;
      PlatformErrorCallback? dispatcherCallback;
      final hooks = _hooks(
        setFramework: (callback) => frameworkCallback = callback,
        setDispatcher: (callback) => dispatcherCallback = callback,
      );
      final error = StateError('dispatcher failure');
      final stackTrace = StackTrace.fromString('dispatcher-test:1');

      // Act
      hooks.installCallbacks(reporter);
      final handled = dispatcherCallback?.call(error, stackTrace);

      // Assert
      expect(frameworkCallback, isNotNull);
      expect(handled, isTrue);
      expect(reporter.platformError, same(error));
      expect(reporter.platformStackTrace, same(stackTrace));
    });

    test('contains reporter failures from both installed callbacks', () {
      // Arrange
      FlutterExceptionHandler? frameworkCallback;
      PlatformErrorCallback? dispatcherCallback;
      final fallbackErrors = <Object>[];
      final hooks = _hooks(
        setFramework: (callback) => frameworkCallback = callback,
        setDispatcher: (callback) => dispatcherCallback = callback,
        lastResortOutput: (error, _) => fallbackErrors.add(error),
      );

      // Act
      hooks.installCallbacks(_ThrowingReporter());
      void invokeFramework() {
        frameworkCallback?.call(
          FlutterErrorDetails(exception: StateError('framework failure')),
        );
      }

      void invokeDispatcher() {
        dispatcherCallback?.call(
          StateError('dispatcher failure'),
          StackTrace.current,
        );
      }

      // Assert
      expect(invokeFramework, returnsNormally);
      expect(invokeDispatcher, returnsNormally);
      expect(
        dispatcherCallback?.call(StateError('again'), StackTrace.current),
        isTrue,
      );
      expect(fallbackErrors, hasLength(3));
    });

    test(
      'uses last-resort output for presentation failure then still reports',
      () {
        // Arrange
        final reporter = _RecordingReporter();
        FlutterExceptionHandler? frameworkCallback;
        PlatformErrorCallback? dispatcherCallback;
        final fallbackErrors = <Object>[];
        final hooks = _hooks(
          setFramework: (callback) => frameworkCallback = callback,
          setDispatcher: (callback) => dispatcherCallback = callback,
          presentFrameworkError: (_) => throw StateError('presentation failed'),
          lastResortOutput: (error, _) => fallbackErrors.add(error),
        );

        // Act
        hooks.installCallbacks(reporter);
        void invokeFramework() {
          frameworkCallback?.call(
            FlutterErrorDetails(exception: StateError('framework failure')),
          );
        }

        // Assert
        expect(invokeFramework, returnsNormally);
        expect(dispatcherCallback, isNotNull);
        expect(reporter.flutterDetails, hasLength(1));
        expect(fallbackErrors.single, isA<StateError>());
      },
    );

    test(
      'contains a throwing last-resort output without escaping callbacks',
      () {
        // Arrange
        FlutterExceptionHandler? frameworkCallback;
        PlatformErrorCallback? dispatcherCallback;
        final hooks = _hooks(
          setFramework: (callback) => frameworkCallback = callback,
          setDispatcher: (callback) => dispatcherCallback = callback,
          presentFrameworkError: (_) => throw StateError('presentation failed'),
          lastResortOutput: (_, _) => throw StateError('fallback failed'),
        );

        // Act
        hooks.installCallbacks(_ThrowingReporter());

        // Assert
        expect(
          () => frameworkCallback?.call(
            FlutterErrorDetails(exception: StateError('framework failure')),
          ),
          returnsNormally,
        );
        expect(
          () => dispatcherCallback?.call(
            StateError('dispatcher failure'),
            StackTrace.current,
          ),
          returnsNormally,
        );
      },
    );
  });
}

/// Builds hook seams without mutating real process-global callbacks.
GlobalErrorHooks _hooks({
  required FlutterErrorHandlerSetter setFramework,
  required PlatformErrorHandlerSetter setDispatcher,
  FrameworkErrorPresentation? presentFrameworkError,
  LastResortOutput? lastResortOutput,
}) {
  return GlobalErrorHooks.forTesting(
    setFrameworkErrorHandler: setFramework,
    setPlatformErrorHandler: setDispatcher,
    presentFrameworkError: presentFrameworkError ?? (_) {},
    lastResortOutput: lastResortOutput ?? (_, _) {},
  );
}

/// Captures reporter inputs for callback boundary assertions.
final class _RecordingReporter implements ErrorReporter {
  _RecordingReporter({this.calls});

  final List<String>? calls;
  final List<FlutterErrorDetails> flutterDetails = <FlutterErrorDetails>[];
  Object? platformError;
  StackTrace? platformStackTrace;

  @override
  void dismissCurrent() {}

  @override
  void flushPresentation() {}

  @override
  void reportBootstrapSafely(Object error, StackTrace stackTrace) {}

  @override
  void reportFlutterSafely(FlutterErrorDetails details) {
    calls?.add('flutter');
    flutterDetails.add(details);
  }

  @override
  void reportPlatformSafely(Object error, StackTrace stackTrace) {
    platformError = error;
    platformStackTrace = stackTrace;
  }

  @override
  void reportPlayerError(PlayerError error, {String? mediaPath}) {}
}

/// Simulates a reporter failure so callback containment remains observable.
final class _ThrowingReporter implements ErrorReporter {
  @override
  void dismissCurrent() {}

  @override
  void flushPresentation() {}

  @override
  void reportBootstrapSafely(Object error, StackTrace stackTrace) {}

  @override
  void reportFlutterSafely(FlutterErrorDetails details) {
    throw StateError('reporter failure');
  }

  @override
  void reportPlatformSafely(Object error, StackTrace stackTrace) {
    throw StateError('reporter failure');
  }

  @override
  void reportPlayerError(PlayerError error, {String? mediaPath}) {}
}
