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

  /// Whether an open is in flight; further [openOnce] calls are ignored.
  @protected
  bool get isOpening => _opening;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of rebuilds this State when isCurrent changes.
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (isCurrent && !_wasCurrent) _opening = false;
    _wasCurrent = isCurrent;
  }

  /// Runs [open] unless an earlier open is still in flight.
  Future<void> openOnce(Future<void> Function() open) async {
    if (_opening) return;
    _opening = true;
    try {
      await open();
    } finally {
      if (mounted) _opening = false;
    }
  }
}
