import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/open_once.dart';
import '../../../l10n/app_localizations.dart';
import '../data/permission_handler_camera_permissions.dart';
import '../domain/barcode.dart';
import '../domain/scan_filter.dart';
import 'permission_panel.dart';
import 'scan_action_bar.dart';
import 'scan_session.dart';
import 'scanner_camera.dart';
import 'scanner_viewfinder.dart';
import 'torch_toggle.dart';

/// The Scan destination: the barcode scanner (T-030,
/// docs/ux/screens/scanner.md).
///
/// The camera runs only while this screen is visible: its route is current,
/// its tab is selected, and the app is in the foreground. The permission
/// prompt appears only here, the first time the scanner opens in an app
/// run. "Enter barcode" and "Search by title" are visible in every state.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    required this.onManualEntry,
    required this.onSearch,
    required this.onScanned,
    super.key,
  });

  /// Opens manual barcode entry (`scanner.actionManual`). Returns the push
  /// future; a double tap opens one screen (T-031 R1-S2).
  final Future<void> Function() onManualEntry;

  /// Switches to the Search destination (`scanner.actionSearch`).
  final VoidCallback onSearch;

  /// Opens the lookup result for a scanned code. Returns the push future.
  final Future<void> Function(Barcode barcode) onScanned;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with OpenOnce {
  late final ScannerCamera _camera;
  late final ScanSession _session;
  late final AppLifecycleListener _lifecycle;

  /// Keeps one preview when the layout moves it (rotation, starting to
  /// scanning), so the plugin's preview state is not rebuilt.
  final GlobalKey _previewKey = GlobalKey();

  bool _foreground = true;
  bool _routeCurrent = true;
  bool _tabSelected = true;
  bool _activeScheduled = false;

  /// Set by a torch tap, so the new torch state is announced once.
  bool _announceTorch = false;
  TorchStatus _lastTorch = TorchStatus.unavailable;

  @override
  void initState() {
    super.initState();
    _camera = ref.read(scannerCameraFactoryProvider)();
    _session = ScanSession(
      permissions: ref.read(cameraPermissionRepositoryProvider),
      camera: _camera,
      filter: ScanFilter(stopwatch: ref.read(scanStopwatchFactoryProvider)),
      promptShown: () => ref.read(cameraPromptShownProvider),
      markPromptShown: () =>
          ref.read(cameraPromptShownProvider.notifier).markShown(),
      onDetected: _onDetected,
      onOpen: _onOpen,
    )..addListener(_onSessionChanged);
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends on the route's isCurrent and on the branch's TickerMode
    // (go_router turns it off for the tabs that are not selected).
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _tabSelected = TickerMode.valuesOf(context).enabled;
    _scheduleActive();
  }

  void _onLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _scheduleActive();
  }

  bool get _active => _foreground && _routeCurrent && _tabSelected;

  /// Applies visibility after the current frame, so the session never
  /// notifies while this screen builds.
  void _scheduleActive() {
    if (_activeScheduled) return;
    _activeScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _activeScheduled = false;
        if (mounted) _session.setActive(_active);
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    _camera.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final torch = _session.torch;
    if (_announceTorch &&
        torch != _lastTorch &&
        torch != TorchStatus.unavailable) {
      _announceTorch = false;
      final l10n = AppLocalizations.of(context);
      _announce(
        torch == TorchStatus.on
            ? l10n.scannerTorchLabelOn
            : l10n.scannerTorchLabelOff,
      );
    }
    _lastTorch = torch;
  }

  void _onDetected(Barcode barcode) {
    unawaited(HapticFeedback.lightImpact());
    _announce(AppLocalizations.of(context).scannerSuccess(barcode.digits));
  }

  bool _onOpen(Barcode barcode) {
    if (isOpening) return false;
    unawaited(openOnce(() => widget.onScanned(barcode)));
    return true;
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _toggleTorch() async {
    _announceTorch = true;
    await _session.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scannerTitle)),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListenableBuilder(
          listenable: _session,
          builder: (context, _) => _buildBody(context, l10n),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final window = MediaQuery.sizeOf(context);
    final phoneLandscape = window.width > window.height && window.height < 600;
    final actions = ScanActionBar(
      onManualEntry: () => unawaited(openOnce(widget.onManualEntry)),
      onSearch: widget.onSearch,
      stacked: phoneLandscape,
      maxButtonWidth: window.width < 600 ? double.infinity : 280,
    );

    if (phoneLandscape) {
      return Row(
        children: [
          Expanded(flex: 3, child: _viewfinderArea(l10n, showHint: false)),
          Expanded(
            flex: 2,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // The actions come first, so large text cannot push
                    // them out of view (scanner.md section 1).
                    children: [
                      actions,
                      if (_hint(l10n) case final hint?) ...[
                        const SizedBox(height: 16),
                        Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final area = _viewfinderArea(l10n, showHint: true);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(
            child: window.width >= 840
                // Expanded: the preview is capped at 720 dp and centered;
                // the rest stays surface colored.
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: area,
                    ),
                  )
                : area,
          ),
          // The preview keeps at least 40% of the height; past that the
          // action bar scrolls (scanner.md section 2, 200% text).
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.6),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: actions,
            ),
          ),
        ],
      ),
    );
  }

  /// The hint for the camera states, or null for the panel states.
  String? _hint(AppLocalizations l10n) => switch (_session.phase) {
    ScanPhase.scanning || ScanPhase.detected =>
      _session.slowHint ? l10n.scannerHintSlow : l10n.scannerHint,
    _ => null,
  };

  Widget _viewfinderArea(AppLocalizations l10n, {required bool showHint}) {
    final session = _session;
    return switch (session.phase) {
      ScanPhase.starting ||
      ScanPhase.scanning ||
      ScanPhase.detected => ScannerViewfinder(
        preview: session.cameraInUse
            ? _camera.buildPreview(key: _previewKey)
            : null,
        starting: session.phase == ScanPhase.starting,
        detected: session.phase == ScanPhase.detected,
        hint: showHint ? _hint(l10n) : null,
        torchToggle: session.torch == TorchStatus.unavailable
            ? null
            : TorchToggle(
                isOn: session.torch == TorchStatus.on,
                onPressed: session.torchEnabled
                    ? () => unawaited(_toggleTorch())
                    : null,
              ),
      ),
      ScanPhase.requesting => PermissionPanel(
        icon: Icons.photo_camera_outlined,
        title: l10n.scannerPermissionRequestingTitle,
        body: l10n.scannerPermissionRequestingBody,
      ),
      ScanPhase.denied => PermissionPanel(
        icon: Icons.no_photography_outlined,
        title: l10n.scannerDeniedTitle,
        body: l10n.scannerDeniedBody,
        actionLabel: l10n.scannerDeniedAllow,
        onAction: session.allowCamera,
      ),
      ScanPhase.permanentlyDenied => PermissionPanel(
        icon: Icons.no_photography_outlined,
        title: l10n.scannerPermanentlyDeniedTitle,
        body: l10n.scannerPermanentlyDeniedBody,
        actionLabel: l10n.commonOpenSettings,
        onAction: () => unawaited(session.openSettings()),
      ),
      ScanPhase.restricted => PermissionPanel(
        icon: Icons.no_photography_outlined,
        title: l10n.scannerDeniedTitle,
        body: l10n.scannerRestrictedBody,
      ),
      ScanPhase.unavailable => PermissionPanel(
        icon: Icons.videocam_off_outlined,
        title: l10n.scannerUnavailableTitle,
        body: l10n.scannerUnavailableBody,
        actionLabel: l10n.commonRetry,
        onAction: session.retry,
      ),
    };
  }
}
