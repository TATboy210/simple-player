import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_player_flutter/l10n/app_localizations.dart';
import 'package:simple_player_flutter/ui/player/progress_bar.dart';

/// Tracks listener ownership so replacement tests can distinguish old-source
/// leakage from the active ProgressBar paint listeners.
class _TrackingIntNotifier extends ChangeNotifier
    implements ValueListenable<int> {
  _TrackingIntNotifier(this._value);

  int _value;
  int listenerCount = 0;

  @override
  int get value => _value;

  set value(int nextValue) {
    if (_value == nextValue) return;
    _value = nextValue;
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    listenerCount += 1;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount -= 1;
    super.removeListener(listener);
  }
}

/// Exercises a retained [ProgressBar] State while every external source changes.
void main() {
  testWidgets(
    'seek hold ignores a replaced position source until the new source arrives',
    (tester) async {
      final oldPosition = _TrackingIntNotifier(0);
      final newPosition = _TrackingIntNotifier(0);
      final oldDuration = ValueNotifier<int>(10000);
      final newDuration = ValueNotifier<int>(10000);
      final oldResizing = ValueNotifier<bool>(false);
      final newResizing = ValueNotifier<bool>(false);
      final barKey = GlobalKey();
      var seekTarget = 0;

      addTearDown(oldPosition.dispose);
      addTearDown(newPosition.dispose);
      addTearDown(oldDuration.dispose);
      addTearDown(newDuration.dispose);
      addTearDown(oldResizing.dispose);
      addTearDown(newResizing.dispose);

      Widget buildSubject({
        required ValueListenable<int> position,
        required ValueListenable<int> duration,
        required ValueListenable<bool> resizing,
      }) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 48,
            child: ProgressBar(
              key: barKey,
              position: position,
              duration: duration,
              resizing: resizing,
              onSeek: (target) => seekTarget = target,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        buildSubject(
          position: oldPosition,
          duration: oldDuration,
          resizing: oldResizing,
        ),
      );
      final bar = find.byType(ProgressBar);
      final rect = tester.getRect(bar);
      final start = rect.centerLeft + const Offset(50, 0);
      final end = rect.centerRight - const Offset(50, 0);

      // Establish a hold by ending a real drag before its position source catches up.
      await tester.dragFrom(start, end - start);
      await tester.pump();
      expect(seekTarget, greaterThan(0));

      await tester.pumpWidget(
        buildSubject(
          position: newPosition,
          duration: newDuration,
          resizing: newResizing,
        ),
      );
      await tester.pump();

      // Replacing merged listeners must detach the old port entirely while
      // the active source owns both painting and the seek-hold listener.
      expect(oldPosition.listenerCount, 0);
      expect(newPosition.listenerCount, 2);

      // The stale source reaches the target first. It must not clear the current hold.
      oldPosition.value = seekTarget;
      await tester.pump();
      final afterOldSource = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.slider ?? false),
        ),
      );
      expect(afterOldSource.properties.value, isNot('0%'));

      // Only the active replacement source may finish the hold.
      newPosition.value = seekTarget;
      await tester.pump();
      final afterNewSource = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && (widget.properties.slider ?? false),
        ),
      );
      expect(afterNewSource.properties.value, '${(seekTarget / 100).round()}%');

      // A second drag and unmount must cancel the active source listener and timers.
      await tester.dragFrom(start, end - start);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      oldPosition.value = 9000;
      newPosition.value = 9000;
      await tester.pump();
    },
  );
}
