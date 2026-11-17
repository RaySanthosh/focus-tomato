import 'package:flutter_test/flutter_test.dart';
import 'package:focus_tomato/timer_engine.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 9);
  const s = TimerSettings(); // 25 / 5 / 15, long every 4

  test('starts at the full focus length', () {
    final e = TimerEngine(s);
    expect(e.remainingSec(t0), 25 * 60);
    expect(e.isRunning, isFalse);
  });

  test('counts down from the end time, survives a pause', () {
    final e = TimerEngine(s)..start(t0);
    expect(e.remainingSec(t0.add(const Duration(minutes: 10))), 15 * 60);
    e.pause(t0.add(const Duration(minutes: 10)));
    expect(e.remainingSec(t0.add(const Duration(hours: 3))), 15 * 60);
    e.start(t0.add(const Duration(hours: 3)));
    expect(e.isFinished(t0.add(const Duration(hours: 3, minutes: 15))), isTrue);
  });

  test('finished focus goes to short break, 4th goes to long break, then cycle restarts', () {
    final e = TimerEngine(s);
    for (var i = 1; i <= 3; i++) {
      expect(e.phase, Phase.focus);
      e.completePhase();
      expect(e.phase, Phase.shortBreak, reason: 'after focus $i');
      e.completePhase();
    }
    e.completePhase(); // 4th focus
    expect(e.phase, Phase.longBreak);
    expect(e.remainingSec(t0), 15 * 60);
    e.completePhase();
    expect(e.phase, Phase.focus);
    expect(e.doneCount, 0);
  });

  test('skipping focus does not count toward the long break', () {
    final e = TimerEngine(s, doneCount: 3);
    e.skip();
    expect(e.phase, Phase.shortBreak);
    expect(e.doneCount, 3);
  });

  test('settings change applies to an untouched timer, not a started one', () {
    final fresh = TimerEngine(s)..applySettings(s.copyWith(focusMin: 50));
    expect(fresh.remainingSec(t0), 50 * 60);

    final started = TimerEngine(s)..start(t0);
    started.pause(t0.add(const Duration(minutes: 5)));
    started.applySettings(s.copyWith(focusMin: 50));
    expect(started.remainingSec(t0), 20 * 60);
  });

  test('progress and clock text', () {
    final e = TimerEngine(s)..start(t0);
    expect(e.progress(t0.add(const Duration(minutes: 12, seconds: 30))), closeTo(0.5, 0.001));
    expect(formatClock(25 * 60), '25:00');
    expect(formatClock(65), '01:05');
  });
}
