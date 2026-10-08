part of 'progress_bar.dart';

/// Owns the forwarding registrations created for a group of listenables.
///
/// [Listenable.merge] has no disposal API, so a retained widget state must keep
/// explicit callbacks and remove them when its PlayerPort sources are replaced.
class _MergedListenable extends ChangeNotifier {
  _MergedListenable(List<Listenable> sources) : _sources = List.of(sources) {
    for (final source in _sources) {
      source.addListener(notifyListeners);
    }
  }

  final List<Listenable> _sources;

  @override
  void dispose() {
    for (final source in _sources) {
      source.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
