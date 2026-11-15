import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/algorithms/mind_engines.dart';
import '../../core/domain/entities/mind_protocol.dart';
import '../../core/services/emergency_contacts.dart';
import '../../core/services/live_camera_service.dart';
import 'mind_illustrations.dart';
import 'mind_run_controller.dart';

/// Stroke speech when recognition is unavailable or heard nothing: a helper
/// listens and judges the repeated sentence (MOV-08 fallback [DER]).
class HelperJudgeView extends StatelessWidget {
  const HelperJudgeView({super.key, required this.run});
  final MindRunController run;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'What did you hear?',
            key: ValueKey('mind_helper_title'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            run.helperPrompt,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < SpeechAbnormality.helperLabels.length; i++) ...[
            FilledButton.icon(
              key: ValueKey('mind_speech_judge_$i'),
              onPressed: () => run.judgeSpeech(i),
              style: FilledButton.styleFrom(
                backgroundColor: switch (i) {
                  0 => const Color(0xFF16A34A),
                  1 => const Color(0xFFD97706),
                  _ => const Color(0xFFDC2626),
                },
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                alignment: Alignment.centerLeft,
              ),
              icon: Icon(switch (i) {
                0 => Icons.check_circle_outline_rounded,
                1 => Icons.record_voice_over_outlined,
                _ => Icons.voice_over_off_rounded,
              }),
              label: Text(
                SpeechAbnormality.helperLabels[i],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('mind_helper_retry'),
                  onPressed: run.retryTask,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Try again'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('mind_helper_call'),
                  onPressed: () => EmergencyContacts.dial('108'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFCA5A5),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call 108'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Numbered "what to do" steps for a task (idle / between card).
class TaskStepsList extends StatelessWidget {
  const TaskStepsList({super.key, required this.steps});
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
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
          for (var i = 0; i < steps.length; i++)
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
                      steps[i],
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
        ],
      ),
    );
  }
}

const Color _teal = Color(0xFF0B7A75);

/// One PHQ-9 / GAD-7 item per card with four large answer buttons.
class QuestionnaireView extends StatelessWidget {
  const QuestionnaireView({super.key, required this.run});
  final MindRunController run;

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
                  key: const ValueKey('mind_back_question'),
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
            key: ValueKey('mind_q_${item.id}'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          for (var v = 0; v < MindQuestionnaire.options.length; v++) ...[
            SizedBox(
              height: 54,
              child: FilledButton(
                key: ValueKey('mind_answer_$v'),
                onPressed: run.phase == MindPhase.running
                    ? () => run.answerQuestion(v)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: current == v
                      ? _teal
                      : Colors.white.withValues(alpha: 0.10),
                  foregroundColor: Colors.white,
                  alignment: Alignment.centerLeft,
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
                        '$v',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        MindQuestionnaire.options[v],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// Speech tasks. Sentence tasks (HF daily, stroke) put the sentence first
/// and large with a slim timer; naming / description tasks show the
/// stimulus, a timer ring, live level bars and chips of what was recognised.
class SpeechTaskView extends StatelessWidget {
  const SpeechTaskView({
    super.key,
    required this.run,
    this.sttAvailable = true,
  });
  final MindRunController run;
  final bool sttAvailable;

  @override
  Widget build(BuildContext context) {
    final t = run.currentTask;
    final running = run.phase == MindPhase.running;
    final total = t.seconds;
    final progress = total == 0 ? 0.0 : (run.elapsedS / total).clamp(0.0, 1.0);
    final sentence = t.sentenceKey == null
        ? null
        : MindTexts.sentence(t.sentenceKey!, run.language);
    final transcribe = t.type == MindTaskType.speechTranscribe;
    final showTally = transcribe && !sttAvailable && t.id == 'fluency';
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 90, 16, 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (run.helperMode) ...[
            HelperJudgeView(run: run),
            const SizedBox(height: 12),
          ],
          if (sentence != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _teal.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    t.id == 'hf_sentence'
                        ? 'Read aloud, again and again'
                        : 'Say this sentence clearly',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sentence,
                    key: const ValueKey('mind_sentence'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!run.helperMode)
              Row(
                children: [
                  Text(
                    running ? '${run.secondsLeft} s' : '$total s',
                    key: const ValueKey('mind_seconds'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: running ? progress : 0,
                        minHeight: 10,
                        backgroundColor: Colors.white12,
                        color: _teal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _LevelBars(level: running ? run.level : 0),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              running
                  ? (run.quietForS <= 3
                        ? 'Hearing you — keep reading'
                        : 'Speak a little louder, closer to the phone')
                  : 'Tap Start, then read at your normal pace',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: running && run.quietForS > 3
                    ? const Color(0xFFFBBF24)
                    : Colors.white70,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (transcribe) ...[
              const SizedBox(height: 8),
              Text(
                run.transcript.isEmpty
                    ? (running ? 'Listening…' : ' ')
                    : 'Heard: “${_tail(run.transcript, 12)}”',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ] else ...[
            if (t.id == 'picture')
              Center(
                child: LayoutBuilder(
                  builder: (context, c) =>
                      ParkSceneView(width: math.min(c.maxWidth, 340)),
                ),
              )
            else
              Center(
                child: MindIllustrationView(
                  kind: t.illustration ?? MindIllustration.speakToPhone,
                  size: 104,
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              height: 124,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: CircularProgressIndicator(
                      value: running ? progress : 0,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      color: _teal,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        running ? '${run.secondsLeft}' : '$total',
                        key: const ValueKey('mind_seconds'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'seconds',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 0,
                    child: _LevelBars(level: running ? run.level : 0),
                  ),
                  if (transcribe)
                    Positioned(
                      left: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${run.liveCount}',
                            key: const ValueKey('mind_live_count'),
                            style: const TextStyle(
                              color: _teal,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Text(
                            run.liveCountLabel.isEmpty
                                ? (t.id == 'fluency' ? 'animals' : 'details')
                                : run.liveCountLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (transcribe && run.liveItems.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final it
                      in run.liveItems.length > 14
                          ? run.liveItems.sublist(run.liveItems.length - 14)
                          : run.liveItems)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _teal.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        it,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              )
            else
              SizedBox(
                height: 34,
                child: Text(
                  transcribe
                      ? (run.transcript.isEmpty
                            ? (running
                                  ? (sttAvailable
                                        ? 'Listening…'
                                        : 'Speech recognition off — helper taps +1 per animal')
                                  : ' ')
                            : _tail(run.transcript, 9))
                      : (running ? 'Recording… keep talking' : ' '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            if (showTally) ...[
              const SizedBox(height: 6),
              FilledButton.tonal(
                key: const ValueKey('mind_tally'),
                onPressed: running ? run.addManualTally : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text(
                  '+1 animal (helper)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              running && run.quietForS > 3 && transcribe && sttAvailable
                  ? 'Speak a little louder, closer to the phone'
                  : ' ',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (!run.helperMode)
            Center(
              child: OutlinedButton.icon(
                key: const ValueKey('mind_done'),
                onPressed: run.canFinishEarly ? run.finishEarly : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white30,
                  side: BorderSide(
                    color: run.canFinishEarly ? Colors.white60 : Colors.white12,
                  ),
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(
                  run.canFinishEarly
                      ? "I'm done"
                      : 'Keep going — at least ${t.minSeconds} s',
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _tail(String text, int words) {
    final ws = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (ws.isEmpty) return '';
    return (ws.length > words ? '… ' : '') +
        ws.skip(math.max(0, ws.length - words)).join(' ');
  }
}

class _LevelBars extends StatelessWidget {
  const _LevelBars({required this.level});
  final double level;

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
              color: level * 5 > i ? const Color(0xFF22C55E) : Colors.white12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Front-camera face task (MOV-06): oval guide, stage text, countdown and
/// live symmetry read-out.
class SmileTaskView extends StatelessWidget {
  const SmileTaskView({super.key, required this.run, this.camera});
  final MindRunController run;
  final BiometricCameraController? camera;

  @override
  Widget build(BuildContext context) {
    final running = run.phase == MindPhase.running;
    final smile = run.faceStage == FaceStage.smile;
    final cam = camera;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 90, 16, 196),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: cam != null && cam.isCameraReady
                  ? LiveBiometricCameraSurface(
                      controller: cam,
                      overlayPainter: FaceOvalPainter(
                        ok: run.faceSeen,
                        smile: smile,
                      ),
                      fullBleed: true,
                    )
                  : Container(
                      color: Colors.white.withValues(alpha: 0.06),
                      child: CustomPaint(
                        painter: FaceOvalPainter(
                          ok: run.faceSeen,
                          smile: smile,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              cam == null
                                  ? 'Camera not available — simulated face'
                                  : cam.permissionDenied
                                  ? 'Camera not allowed (G-11) — this step will be recorded as not assessed. Allow the camera in Settings or skip.'
                                  : (cam.statusNote ?? 'Starting camera…'),
                              key: const ValueKey('mind_face_camera_note'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            !running
                ? 'Face in the oval'
                : switch (run.faceStage) {
                    FaceStage.finding => 'Find your face in the oval',
                    FaceStage.rest => 'Relax your face…',
                    FaceStage.smile => 'SMILE as wide as you can!',
                  },
            key: const ValueKey('mind_face_stage'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: smile
                  ? const Color(0xFF22C55E)
                  : (running && run.faceStage == FaceStage.finding
                        ? const Color(0xFFFBBF24)
                        : Colors.white),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            running
                ? switch (run.faceStage) {
                    FaceStage.finding =>
                      run.faceSeen
                          ? 'Face found — hold still'
                          : 'Arm\'s length, good light · ${run.faceStageLeftS.ceil()} s',
                    FaceStage.rest =>
                      'Rest ${run.faceStageLeftS.ceil()} s · ${run.restFrames} frames',
                    FaceStage.smile =>
                      'Smile ${run.faceStageLeftS.ceil()} s · ${run.smileFrames} frames${run.liveAsymmetry == null ? '' : ' · symmetry ${run.liveAsymmetry!.toStringAsFixed(2)}'}',
                  }
                : 'Arm\'s length, good light',
            key: const ValueKey('mind_face_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class FaceOvalPainter extends CustomPainter {
  const FaceOvalPainter({required this.ok, required this.smile});
  final bool ok;
  final bool smile;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.62,
      height: size.height * 0.78,
    );
    final p = Paint()
      ..color = smile ? const Color(0xFF22C55E) : (ok ? _teal : Colors.white60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(r, p);
  }

  @override
  bool shouldRepaint(covariant FaceOvalPainter old) =>
      old.ok != ok || old.smile != smile;
}

/// Arm-hold task (MOV-07 stand-in): big countdown, eyes-closed cue, live
/// tilt bar.
class ArmDriftTaskView extends StatelessWidget {
  const ArmDriftTaskView({super.key, required this.run});
  final MindRunController run;

  @override
  Widget build(BuildContext context) {
    final t = run.currentTask;
    final running = run.phase == MindPhase.running;
    final left = t.arm == 'left';
    final drop = run.liveDropDeg;
    final cm = ArmDrift.dropCm(drop);
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 200),
      child: Column(
        children: [
          MindIllustrationView(
            kind: MindIllustration.armsOutEyesClosed,
            size: 150,
          ),
          const SizedBox(height: 14),
          Text(
            '${left ? 'LEFT' : 'RIGHT'} ARM',
            style: TextStyle(
              color: left ? const Color(0xFF60A5FA) : const Color(0xFFF87171),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            !running
                ? '${t.seconds}'
                : run.armSettling
                ? '…'
                : '${run.secondsLeft}',
            key: const ValueKey('mind_arm_seconds'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            !running
                ? 'phone flat in the palm, arm straight out'
                : run.armSettling
                ? 'arm straight out at shoulder height… hold still'
                : 'eyes closed · hold still · the voice counts down',
            key: const ValueKey('mind_arm_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'drift',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (cm / 30).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    color: cm >= ArmDrift.thresholdCm
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cm.toStringAsFixed(0)} cm',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
