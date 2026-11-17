/// Pure focus-timer logic. No Flutter, no clock of its own: every call takes `now`,
/// so it is easy to test and survives the app being closed (we keep the end time, not a tick count).
library;

enum Phase { focus, shortBreak, longBreak }

class TimerSettings {
  const TimerSettings({
    this.focusMin = 25,
    this.shortMin = 5,
    this.longMin = 15,
    this.longEvery = 4,
    this.useDnd = false,
  });

  final int focusMin;
  final int shortMin;
  final int longMin;

  /// A long break comes after this many finished focus sessions.
  final int longEvery;

  /// Turn on Do Not Disturb during focus sessions.
  final bool useDnd;

  TimerSettings copyWith({int? focusMin, int? shortMin, int? longMin, int? longEvery, bool? useDnd}) =>
      TimerSettings(
        focusMin: focusMin ?? this.focusMin,
        shortMin: shortMin ?? this.shortMin,
        longMin: longMin ?? this.longMin,
        longEvery: longEvery ?? this.longEvery,
        useDnd: useDnd ?? this.useDnd,
      );

  int secondsFor(Phase p) => switch (p) {
        Phase.focus => focusMin * 60,
        Phase.shortBreak => shortMin * 60,
        Phase.longBreak => longMin * 60,
      };
}

class TimerEngine {
  TimerEngine(this.settings, {this.phase = Phase.focus, this.endAt, int? remainingSec, this.doneCount = 0})
      : _remainingSec = remainingSec ?? settings.secondsFor(phase);

  TimerSettings settings;
  Phase phase;

  /// Set while running; null while paused/idle.
  DateTime? endAt;
  int _remainingSec;

  /// Focus sessions finished in this cycle (drives the long break).
  int doneCount;

  bool get isRunning => endAt != null;
  int get totalSec => settings.secondsFor(phase);

  /// Raw paused value, for saving.
  int get storedRemainingSec => _remainingSec;

  int remainingSec(DateTime now) {
    final end = endAt;
    if (end == null) return _remainingSec;
    final ms = end.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// 0.0 at the start of a phase, 1.0 when it is over.
  double progress(DateTime now) {
    final total = totalSec;
    if (total == 0) return 1;
    return (1 - remainingSec(now) / total).clamp(0.0, 1.0);
  }

  bool isFinished(DateTime now) => isRunning && remainingSec(now) == 0;

  void start(DateTime now) {
    if (isRunning) return;
    endAt = now.add(Duration(seconds: _remainingSec));
  }

  void pause(DateTime now) {
    if (!isRunning) return;
    _remainingSec = remainingSec(now);
    endAt = null;
  }

  void reset() {
    endAt = null;
    _remainingSec = totalSec;
  }

  /// The phase that follows the current one. Only a finished (counted) focus can lead to a long break.
  Phase nextPhase({bool counted = true}) {
    if (phase != Phase.focus) return Phase.focus;
    if (counted && (doneCount + 1) % settings.longEvery == 0) return Phase.longBreak;
    return Phase.shortBreak;
  }

  /// Time ran out. Focus sessions count toward the long break.
  void completePhase() {
    final next = nextPhase();
    if (phase == Phase.focus) doneCount++;
    if (phase == Phase.longBreak) doneCount = 0;
    _goTo(next);
  }

  /// User skipped: move on without counting the focus session.
  void skip() {
    final next = nextPhase(counted: false);
    if (phase == Phase.longBreak) doneCount = 0;
    _goTo(next);
  }

  /// User tapped a phase chip.
  void select(Phase p) => _goTo(p);

  /// Settings changed: an untouched timer picks up the new length; a started/paused one keeps its time.
  void applySettings(TimerSettings s) {
    final wasFresh = !isRunning && _remainingSec == totalSec;
    settings = s;
    if (wasFresh) _remainingSec = totalSec;
  }

  void _goTo(Phase p) {
    phase = p;
    endAt = null;
    _remainingSec = settings.secondsFor(p);
  }
}

String formatClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
