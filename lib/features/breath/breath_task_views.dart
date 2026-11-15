import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/breath_engines.dart';
import '../../core/domain/entities/breath_protocol.dart';
import 'breath_illustrations.dart';
import 'breath_run_controller.dart';

const Color _teal = Color(0xFF0B7A75);
const Color _green = Color(0xFF22C55E);
const Color _amber = Color(0xFFFBBF24);
const Color _red = Color(0xFFEF4444);

/// Picture + "What to do" steps + what the phone listens for + when it
/// stops, shown before a task (idle / between) and read aloud.
class BreathTaskBriefCard extends StatelessWidget {
  const BreathTaskBriefCard({
    super.key,
    required this.task,
    required this.title,
    this.subtitle,
    this.extra,
  });

  final BreathTask task;
  final String title;
  final String? subtitle;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final b = task.brief;
    return Center(
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 84, 20, 230),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: BreathIllustrationView(
                kind: task.illustration ?? BreathIllustration.phoneAtArm,
                size: 132,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              key: const ValueKey('breath_brief_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ],
            if (extra != null) ...[const SizedBox(height: 12), extra!],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WHAT TO DO',
                    style: TextStyle(
                      color: _teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (b == null)
                    Text(
                      task.instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    )
                  else
                    for (var i = 0; i < b.whatToDo.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: _teal,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                b.whatToDo[i],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (b != null) ...[
                    const Divider(color: Colors.white12, height: 14),
                    _line(Icons.hearing_rounded, 'Listens for', b.listensFor),
                    const SizedBox(height: 4),
                    _line(Icons.timer_outlined, 'Stops', b.stopsWhen),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String k, String v) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: Colors.white54),
      const SizedBox(width: 8),
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$k: ',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: v),
            ],
          ),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}

/// One questionnaire item per card with large answer buttons (yes / no,
/// mMRC sentences, exposure choices).
class BreathQuestionView extends StatelessWidget {
  const BreathQuestionView({super.key, required this.run});
  final BreathRunController run;

  @override
  Widget build(BuildContext context) {
    final q = run.questionnaire;
    final item = run.currentQuestion;
    if (q == null || item == null) return const SizedBox.shrink();
    final current = run.answers[item.id];
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${q.title} · Question ${run.questionNumber} of ${run.questionTotal}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (run.questionIndex > 0)
                TextButton.icon(
                  key: const ValueKey('breath_back_question'),
                  onPressed: run.backQuestion,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Back'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: run.questionNumber / math.max(1, run.questionTotal),
            minHeight: 5,
            backgroundColor: Colors.white12,
            color: _teal,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 18),
          Text(
            q.stem,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.text,
            key: ValueKey('breath_q_${item.id}'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          if (item.help.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.help,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 18),
          for (var v = 0; v < item.options.length; v++) ...[
            FilledButton(
              key: ValueKey('breath_answer_$v'),
              onPressed: run.phase == BreathPhase.running
                  ? () => run.answerQuestion(v)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: current == v
                    ? _teal
                    : Colors.white.withValues(alpha: 0.10),
                foregroundColor: Colors.white,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      item.options.length == 2 ? (v == 0 ? 'N' : 'Y') : '$v',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.options[v],
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Live banner line (clipping red / room noise amber) shown above a task.
class BreathLiveBanner extends StatelessWidget {
  const BreathLiveBanner({super.key, required this.run});
  final BreathRunController run;

  @override
  Widget build(BuildContext context) {
    final running = run.phase == BreathPhase.running;
    String? text;
    Color color = _amber;
    IconData icon = Icons.volume_up_rounded;
    if (running && run.clipping) {
      text = 'Too loud — move the phone further away';
      color = _red;
      icon = Icons.graphic_eq_rounded;
    } else if (running && run.roomTooNoisy) {
      text =
          'Room noise ${run.liveDba?.toStringAsFixed(0) ?? '—'} dBA (limit 45) — quieter room';
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: text == null
          ? const SizedBox(key: ValueKey('none'), height: 0)
          : Container(
              key: ValueKey(text),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      key: const ValueKey('breath_live_banner'),
                      style: TextStyle(
                        color: color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Cough task (AUD-01): the circle turns green, a live 0 / 3 counter with
/// ticks and a "+1" pulse per accepted burst, a line for rejected bursts,
/// level bars, attempt label.
class CoughTaskView extends StatefulWidget {
  const CoughTaskView({super.key, required this.run});
  final BreathRunController run;

  @override
  State<CoughTaskView> createState() => _CoughTaskViewState();
}

class _CoughTaskViewState extends State<CoughTaskView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  int _seen = 0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final t = run.currentTask;
    final running = run.phase == BreathPhase.running;
    final green = running && run.circleGreen;
    final n = run.liveCoughs;
    if (run.pulseSerial != _seen) {
      _seen = run.pulseSerial;
      _pulse.forward(from: 0);
    }
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
      child: Column(
        children: [
          BreathLiveBanner(run: run),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final k = 1 + 0.08 * math.sin(_pulse.value * math.pi);
              return Transform.scale(scale: k, child: child);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (green ? _green : Colors.white).withValues(
                  alpha: green ? 0.18 : 0.06,
                ),
                border: Border.all(
                  color: green ? _green : Colors.white38,
                  width: 5,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sick_outlined,
                    size: 46,
                    color: green ? _green : Colors.white60,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    green
                        ? 'Cough now'
                        : running
                        ? 'Get ready…'
                        : 'Tap Start',
                    key: const ValueKey('breath_cough_cue'),
                    style: TextStyle(
                      color: green ? _green : Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$n',
                key: const ValueKey('breath_cough_count'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Text(
                ' / 3',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 16),
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    i < n
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: i < n ? _green : Colors.white30,
                    size: 26,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            n >= 3
                ? 'Three coughs heard — tap "I\'m done" or keep going'
                : run.lastRejectReason != null && running
                ? 'A sound was ${run.lastRejectReason} to be a cough — cough a little harder'
                : 'coughs heard · only coughs count, please don\'t speak',
            key: const ValueKey('breath_cough_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: run.lastRejectReason != null && n < 3
                  ? _amber
                  : Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LevelBars(
                level: running ? run.level : 0,
                clipping: run.clipping,
              ),
              const SizedBox(width: 14),
              Text(
                running ? '${run.secondsLeft} s' : '${t.seconds} s',
                key: const ValueKey('breath_seconds'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Attempt ${run.attempt} of ${t.attempts} · phone at arm\'s length',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _DoneButton(run: run, label: "I'm done", waitLabel: 'Needs 3 coughs'),
        ],
      ),
    );
  }
}

/// Sustained "aaa" / "sss" / "zzz" or the sentence: big cue, a timer that
/// counts while the phone hears you, level bars.
class PhonationTaskView extends StatelessWidget {
  const PhonationTaskView({super.key, required this.run});
  final BreathRunController run;

  @override
  Widget build(BuildContext context) {
    final t = run.currentTask;
    final kind = t.phonation ?? PhonationKind.aaa;
    final running = run.phase == BreathPhase.running;
    final sentence = kind == PhonationKind.sentence;
    final label = BreathTexts.phonationLabel(kind);
    final ceiling = t.seconds.toDouble();
    final progress = (run.voicedS / ceiling).clamp(0.0, 1.0);
    final color = switch (kind) {
      PhonationKind.aaa => _teal,
      PhonationKind.sss => const Color(0xFF60A5FA),
      PhonationKind.zzz => _amber,
      PhonationKind.sentence => _teal,
    };
    final target = kind == PhonationKind.aaa
        ? VoiceQuality.mptMinAdultS / ceiling
        : null;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BreathLiveBanner(run: run),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (run.hearingVoice && running ? _green : color)
                    .withValues(alpha: 0.7),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  sentence
                      ? 'Read at your normal pace'
                      : 'Deep breath, then hold',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  key: const ValueKey('breath_phonation_cue'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sentence ? 24 : 54,
                    fontWeight: FontWeight.w900,
                    height: sentence ? 1.4 : 1,
                    letterSpacing: sentence ? 0 : 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${run.voicedS.toStringAsFixed(1)} s',
                key: const ValueKey('breath_voiced_seconds'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: running ? progress : 0,
                        minHeight: 12,
                        backgroundColor: Colors.white12,
                        color: color,
                      ),
                    ),
                    if (target != null)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: target,
                          child: const Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 2,
                              child: ColoredBox(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LevelBars(
                level: running ? run.level : 0,
                clipping: run.clipping,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !running
                ? 'The timer counts while the phone hears you'
                : run.hearingVoice
                ? (sentence ? 'Hearing you' : 'Hearing you — keep it steady')
                : run.voicedS > 0
                ? 'Stopped? The task ends after 1 s of silence'
                : (kind == PhonationKind.sss
                      ? 'Waiting for the hiss — a soft "sss" is enough'
                      : 'Waiting for your voice…'),
            key: const ValueKey('breath_phonation_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: run.hearingVoice ? _green : Colors.white70,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            switch (kind) {
              PhonationKind.aaa =>
                'Adult norm: 15 s or more (MPT, the white mark) · at least 3 s needed',
              PhonationKind.sentence =>
                'Pitch and rhythm are recorded for the clinician',
              PhonationKind.sss => 'The app divides "sss" time by "zzz" time',
              PhonationKind.zzz => 'Keep your voice on — like a bee',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Center(
            child: _DoneButton(
              run: run,
              label: "I'm done",
              waitLabel: 'At least ${t.minSeconds} s',
            ),
          ),
        ],
      ),
    );
  }
}

/// Deep breaths with a pacer ring (2 s in, 2 s out, four times).
class BreathSoundsTaskView extends StatelessWidget {
  const BreathSoundsTaskView({super.key, required this.run});
  final BreathRunController run;

  @override
  Widget build(BuildContext context) {
    final t = run.currentTask;
    final running = run.phase == BreathPhase.running;
    final phase = running ? run.pacerPhase : 0.0;
    final size = running
        ? 110 + 90 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
        : 110.0;
    final inhaling = running && run.inhaling;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
      child: Column(
        children: [
          BreathLiveBanner(run: run),
          SizedBox(
            height: 210,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (inhaling ? const Color(0xFF60A5FA) : _amber)
                      .withValues(alpha: 0.18),
                  border: Border.all(
                    color: inhaling ? const Color(0xFF60A5FA) : _amber,
                    width: 5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  running ? (inhaling ? 'IN' : 'OUT') : 'Ready',
                  key: const ValueKey('breath_pacer'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          Text(
            running
                ? (inhaling
                      ? 'Breathe in through your mouth…'
                      : 'and out, slowly…')
                : 'Breathe with the ring',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            running
                ? 'Breath ${run.breathNumber} of 4 · ${run.secondsLeft} s left'
                : '${t.seconds} s · four deep breaths',
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          _LevelBars(level: running ? run.level : 0, clipping: run.clipping),
          const SizedBox(height: 6),
          const Text(
            'The app listens for a whistling tone (wheeze) lasting 100 ms or more',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          _DoneButton(run: run, label: "I'm done", waitLabel: 'Keep breathing'),
        ],
      ),
    );
  }
}

/// Forced exhale (AUD-05): countdown → "BLOW!" with a live flow bar and
/// blow seconds (3 s mark), then effort cards with ticks and the
/// repeatability status.
class ExhaleTaskView extends StatelessWidget {
  const ExhaleTaskView({super.key, required this.run});
  final BreathRunController run;

  @override
  Widget build(BuildContext context) {
    final t = run.currentTask;
    final running = run.phase == BreathPhase.running;
    final counting = running && run.countdown > 0;
    final blowPhase = running && !run.awaitingBlow && run.countdown == 0;
    final est = run.liveEstimate;
    final needed = t.efforts;
    final cards = math.max(needed, run.efforts.length + (blowPhase ? 1 : 0));
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BreathLiveBanner(run: run),
          SizedBox(
            height: 150,
            child: Center(
              child: counting
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Deepest breath in…',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${run.countdown}',
                          key: const ValueKey('breath_countdown'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 84,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ],
                    )
                  : blowPhase
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            run.blowing ? 'KEEP PUSHING!' : 'BLOW!',
                            key: const ValueKey('breath_blow_cue'),
                            maxLines: 1,
                            style: const TextStyle(
                              color: _red,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          run.blowing
                              ? '${run.blowS.toStringAsFixed(1)} s${run.blowS >= 3 ? ' ✓' : ' · aim for 3 s or more'}'
                              : 'hard and fast, until empty',
                          key: const ValueKey('breath_blow_seconds'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: run.blowS >= 3 ? _green : Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : BreathIllustrationView(
                      kind: BreathIllustration.blowHard,
                      size: 150,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'flow',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: blowPhase ? run.flowLevel : 0,
                        minHeight: 18,
                        backgroundColor: Colors.white12,
                        color: run.clipping ? _amber : _red,
                      ),
                    ),
                    if (blowPhase && run.peakLevel > 0)
                      Positioned.fill(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: run.peakLevel.clamp(0.02, 1.0),
                          child: const Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: 3,
                              child: ColoredBox(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LevelBars(
                level: blowPhase ? run.level : 0,
                clipping: run.clipping,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < math.min(cards, t.maxEfforts); i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _effortCard(i, est, blowPhase, t)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            run.effortCoach.isNotEmpty
                ? run.effortCoach
                : needed == 1
                ? 'One blow of at least 3 s'
                : 'Three blows; the best two must agree within 10 %',
            key: const ValueKey('breath_effort_coach'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: _DoneButton(
              run: run,
              label: 'Stop the blow',
              waitLabel: 'Blowing…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _effortCard(
    int i,
    SpirometryEstimate? est,
    bool blowPhase,
    BreathTask t,
  ) {
    final done = i < run.efforts.length;
    final current = !done && blowPhase && i == run.efforts.length;
    final v = done && est != null ? est.efforts[i] : null;
    final valid = v?.valid ?? false;
    final best = est != null && est.bestIndex == i;
    final color = done
        ? (valid ? _green : _amber)
        : current
        ? _red
        : Colors.white24;
    return Container(
      key: ValueKey('breath_effort_$i'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: done || current ? 0.16 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Icon(
            done
                ? (valid
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded)
                : current
                ? Icons.air_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            'Blow ${i + 1}${best ? ' ★' : ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            v == null
                ? (current ? 'now' : '—')
                : valid
                ? '${v.effort.durationS.toStringAsFixed(1)} s · ${v.ratio.toStringAsFixed(2)}'
                : '${v.effort.durationS.toStringAsFixed(1)} s · short',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

/// Compact strip of the efforts recorded so far (between blows) with the
/// rest countdown.
class ExhaleEffortsStrip extends StatelessWidget {
  const ExhaleEffortsStrip({super.key, required this.run});
  final BreathRunController run;

  @override
  Widget build(BuildContext context) {
    final est = run.liveEstimate;
    return Column(
      children: [
        if (run.resting) ...[
          Text(
            'Rest · ${run.restLeftS.toStringAsFixed(0)} s',
            key: const ValueKey('breath_rest_left'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'breathe normally — tap the button below to skip the rest',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < run.efforts.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Blow ${i + 1}: ${run.efforts[i].durationS.toStringAsFixed(1)} s · ratio ${run.efforts[i].fev1Fraction.toStringAsFixed(2)}${est != null && est.bestIndex == i ? ' ★' : ''}${run.efforts[i].longEnough ? '' : ' (short)'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (est != null && est.validCount >= 2)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (est.repeatable ? _green : _amber).withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  est.repeatable
                      ? 'Repeatable ✓ (${(est.repeatabilityDiffPct ?? 0).toStringAsFixed(0)} % apart)'
                      : 'Not yet repeatable (${(est.repeatabilityDiffPct ?? 0).toStringAsFixed(0)} % apart, limit 10)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({
    required this.run,
    required this.label,
    required this.waitLabel,
  });
  final BreathRunController run;
  final String label;
  final String waitLabel;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('breath_done'),
    onPressed: run.canFinishEarly ? run.finishEarly : null,
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white30,
      side: BorderSide(
        color: run.canFinishEarly ? Colors.white60 : Colors.white12,
      ),
    ),
    icon: const Icon(Icons.stop_circle_outlined, size: 18),
    label: Text(run.canFinishEarly ? label : waitLabel),
  );
}

class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.level, this.clipping = false});
  final double level;
  final bool clipping;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 6,
            height: 10 + i * 7,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: level * 5 > i
                  ? (clipping || i == 4 && level > 0.95 ? _red : _green)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
