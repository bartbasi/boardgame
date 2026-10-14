import 'package:flutter/widgets.dart';

/// Lets a screen open one route at a time, so a double tap (or two keyboard
/// actions before the next frame) does not push the same screen twice
/// (T-031 review R1-M1 and R1-S2).
///
/// [openOnce] runs `open` (which returns the push future) and ignores
/// further calls until either:
/// - the push future completes (the opened route was popped), or
/// - this screen's route is the current route again. go_router completes a
///   push future only on pop; a `go` that drops the pushed route (for
///   example tapping the selected destination again) never completes it,
///   so without this the screen would stay locked.
mixin OpenOnce<T extends StatefulWidget> on State<T> {
  bool _opening = false;
  bool _wasCurrent = true;

  /// Counts opens, so a late `finally` of an older open cannot release a
  /// newer one (review R2-G1).
  int _generation = 0;

  /// Whether an open is in flight; further [openOnce] calls are ignored.
  @protected
  bool get isOpening => _opening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends only on the route's isCurrent, so this runs when it changes.
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (isCurrent && !_wasCurrent) _opening = false;
    _wasCurrent = isCurrent;
  }

  /// Runs [open] unless an earlier open is still in flight.
  Future<void> openOnce(Future<void> Function() open) async {
    if (_opening) return;
    _opening = true;
    final generation = ++_generation;
    try {
      await open();
    } finally {
      if (mounted && generation == _generation) _opening = false;
    }
  }
}
