import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'system.dart';
import 'timer_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(FocusTomatoApp(prefs: prefs, system: SystemBridge()));
}

const _tomato = Color(0xFFE5533D);
const _green = Color(0xFF2E9E6A);
const _blue = Color(0xFF3B6FD4);

Color phaseColor(Phase p) => switch (p) {
      Phase.focus => _tomato,
      Phase.shortBreak => _green,
      Phase.longBreak => _blue,
    };

String phaseLabel(Phase p) => switch (p) {
      Phase.focus => 'Focus',
      Phase.shortBreak => 'Short break',
      Phase.longBreak => 'Long break',
    };

class FocusTomatoApp extends StatelessWidget {
  const FocusTomatoApp({super.key, required this.prefs, required this.system});

  final SharedPreferences prefs;
  final SystemBridge system;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _tomato, brightness: b),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'Focus Tomato',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: TimerScreen(prefs: prefs, system: system),
    );
  }
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.prefs, required this.system});

  final SharedPreferences prefs;
  final SystemBridge system;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  late final TimerEngine _engine;
  Timer? _ticker;
  bool _askedNotifications = false;

  SharedPreferences get _p => widget.prefs;
  SystemBridge get _sys => widget.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = TimerSettings(
      focusMin: _p.getInt('focusMin') ?? 25,
      shortMin: _p.getInt('shortMin') ?? 5,
      longMin: _p.getInt('longMin') ?? 15,
      longEvery: _p.getInt('longEvery') ?? 4,
      useDnd: _p.getBool('useDnd') ?? false,
    );
    final endMs = _p.getInt('endAtMs');
    _engine = TimerEngine(
      settings,
      phase: Phase.values[(_p.getInt('phase') ?? 0).clamp(0, Phase.values.length - 1)],
      endAt: endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs),
      remainingSec: _p.getInt('remainingSec'),
      doneCount: _p.getInt('doneCount') ?? 0,
    );
    _askedNotifications = _p.getBool('askedNotifications') ?? false;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    if (_engine.isFinished(now)) {
      _finish(now);
    } else if (_engine.isRunning) {
      setState(() {});
    }
  }

  (String, String) _endMessage() => _engine.phase == Phase.focus
      ? ('Focus done 🍅', 'Nice work. Time for a ${_engine.nextPhase() == Phase.longBreak ? 'long' : 'short'} break.')
      : ('Break over', 'Ready for the next focus session?');

  void _finish(DateTime now) {
    final (title, body) = _endMessage();
    // Caught live (app open when time ran out): alert now. Caught late (app was closed): the alarm already did.
    final late = now.difference(_engine.endAt!).inSeconds > 3;
    if (late) {
      _sys.cancelEnd();
      _sys.setDnd(false);
    } else {
      _sys.completeNow(title, body);
    }
    setState(_engine.completePhase);
    _save();
  }

  Future<void> _start() async {
    setState(() => _engine.start(DateTime.now()));
    _save();
    if (!_askedNotifications) {
      _askedNotifications = true;
      _p.setBool('askedNotifications', true);
      await _sys.requestNotificationPermission();
    }
    if (!_engine.isRunning) return;
    final (title, body) = _endMessage();
    await _sys.scheduleEnd(_engine.endAt!, title, body);
    if (_engine.phase == Phase.focus && _engine.settings.useDnd) {
      final ok = await _sys.setDnd(true);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Do Not Disturb access is off. Turn it on in Settings.')),
        );
      }
    }
    _save();
  }

  void _stopSideEffects() {
    _sys.cancelEnd();
    _sys.setDnd(false);
  }

  void _pause() {
    setState(() => _engine.pause(DateTime.now()));
    _stopSideEffects();
    _save();
  }

  void _reset() {
    setState(_engine.reset);
    _stopSideEffects();
    _save();
  }

  void _skip() {
    setState(_engine.skip);
    _stopSideEffects();
    _save();
  }

  void _select(Phase p) {
    if (p == _engine.phase) return;
    setState(() => _engine.select(p));
    _stopSideEffects();
    _save();
  }

  void _save() {
    final s = _engine.settings;
    _p.setInt('focusMin', s.focusMin);
    _p.setInt('shortMin', s.shortMin);
    _p.setInt('longMin', s.longMin);
    _p.setInt('longEvery', s.longEvery);
    _p.setBool('useDnd', s.useDnd);
    _p.setInt('phase', _engine.phase.index);
    _p.setInt('remainingSec', _engine.storedRemainingSec);
    _p.setInt('doneCount', _engine.doneCount);
    final end = _engine.endAt;
    end == null ? _p.remove('endAtMs') : _p.setInt('endAtMs', end.millisecondsSinceEpoch);
  }

  Future<void> _openSettings() async {
    final updated = await showModalBottomSheet<TimerSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SettingsSheet(initial: _engine.settings, system: _sys),
    );
    if (updated == null) return;
    setState(() => _engine.applySettings(updated));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final color = phaseColor(_engine.phase);
    final scheme = Theme.of(context).colorScheme;
    final running = _engine.isRunning;
    final every = _engine.settings.longEvery;
    final filledDots = _engine.phase == Phase.longBreak ? every : _engine.doneCount % every;

    return Scaffold(
      backgroundColor: Color.alphaBlend(color.withValues(alpha: 0.08), scheme.surface),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Focus Tomato', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.tune_rounded), onPressed: _openSettings),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final ring = (box.maxWidth * 0.75).clamp(200.0, 340.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (box.maxHeight - 16).clamp(0, double.infinity)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SegmentedButton<Phase>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in Phase.values) ButtonSegment(value: p, label: Text(phaseLabel(p), maxLines: 1)),
                      ],
                      selected: {_engine.phase},
                      onSelectionChanged: (s) => _select(s.first),
                      style: SegmentedButton.styleFrom(selectedBackgroundColor: color.withValues(alpha: 0.2)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox.square(
                      dimension: ring,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: 1 - _engine.progress(now),
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.15),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatClock(_engine.remainingSec(now)),
                                  style: TextStyle(
                                    fontSize: ring * 0.22,
                                    fontWeight: FontWeight.w300,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: scheme.onSurface,
                                  ),
                                ),
                                Text(
                                  running ? phaseLabel(_engine.phase) : 'Paused · ${phaseLabel(_engine.phase)}',
                                  style: TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label: '$filledDots of $every focus sessions done',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < every; i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i < filledDots ? _tomato : _tomato.withValues(alpha: 0.18),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_engine.settings.useDnd && _engine.phase == Phase.focus)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.do_not_disturb_on_outlined, size: 16, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text('Do Not Disturb during focus', style: TextStyle(color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Reset',
                          iconSize: 28,
                          onPressed: _reset,
                          icon: const Icon(Icons.replay_rounded),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: running ? _pause : _start,
                            child: Icon(
                              running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 48,
                              semanticLabel: running ? 'Pause' : 'Start',
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton.filledTonal(
                          tooltip: 'Skip',
                          iconSize: 28,
                          onPressed: _skip,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.initial, required this.system});

  final TimerSettings initial;
  final SystemBridge system;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> with WidgetsBindingObserver {
  late TimerSettings _s = widget.initial;
  bool _waitingForDndAccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    // Back from the system "Do Not Disturb access" screen: switch on if access was granted.
    if (state == AppLifecycleState.resumed && _waitingForDndAccess) {
      _waitingForDndAccess = false;
      if (await widget.system.hasDndAccess() && mounted) setState(() => _s = _s.copyWith(useDnd: true));
    }
  }

  Future<void> _toggleDnd(bool on) async {
    if (!on) return setState(() => _s = _s.copyWith(useDnd: false));
    if (await widget.system.hasDndAccess()) {
      if (mounted) setState(() => _s = _s.copyWith(useDnd: true));
      return;
    }
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allow Do Not Disturb'),
        content: const Text(
          'To silence notifications while you focus, Android needs you to allow Focus Tomato '
          'in "Do Not Disturb access". Find Focus Tomato in the list, turn it on, then come back.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
        ],
      ),
    );
    if (go == true) {
      _waitingForDndAccess = true;
      await widget.system.openDndSettings();
    }
  }

  Widget _stepper(String label, int value, int min, int max, int step, String unit, ValueChanged<int> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less $label',
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 72,
            child: Text('$value $unit', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ),
          IconButton(
            tooltip: 'More $label',
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _stepper('Focus', _s.focusMin, 5, 90, 5, 'min', (v) => setState(() => _s = _s.copyWith(focusMin: v))),
            _stepper('Short break', _s.shortMin, 1, 30, 1, 'min', (v) => setState(() => _s = _s.copyWith(shortMin: v))),
            _stepper('Long break', _s.longMin, 5, 60, 5, 'min', (v) => setState(() => _s = _s.copyWith(longMin: v))),
            _stepper('Long break after', _s.longEvery, 2, 8, 1, 'focus',
                (v) => setState(() => _s = _s.copyWith(longEvery: v))),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Do Not Disturb while focusing'),
              subtitle: const Text('Silences notifications during focus, turns back off after.'),
              value: _s.useDnd,
              onChanged: _toggleDnd,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(context, _s), child: const Text('Save')),
            const SizedBox(height: 8),
            Text(
              'No account, no internet. Settings stay on this phone.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
