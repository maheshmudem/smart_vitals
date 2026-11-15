import 'package:flutter/material.dart';

import '../../core/domain/algorithms/vision_engines.dart';
import '../../core/domain/entities/vision_protocol.dart';
import 'vision_run_controller.dart';

/// S-H10 Test area: full-screen tap surface. "Wait…" on dark, then the
/// screen flashes green (visual block) or the phone beeps (sound block).
class ReactionTestView extends StatefulWidget {
  const ReactionTestView({super.key, required this.run});

  final VisionRunController run;

  @override
  State<ReactionTestView> createState() => _ReactionTestViewState();
}

class _ReactionTestViewState extends State<ReactionTestView> {
  @override
  Widget build(BuildContext context) {
    final r = widget.run;
    final shown = r.stimulus == StimulusState.shown;
    final visual = r.currentBlock == ReactionBlock.visual;
    if (shown && visual) {
      // Onset = the frame that paints the flash.
      WidgetsBinding.instance.addPostFrameCallback((_) => r.markOnset());
    }
    final bg = shown && visual
        ? const Color(0xFF22C55E)
        : r.stimulus == StimulusState.feedback && r.lastLatencyMs != null
        ? const Color(0xFF0F2A24)
        : const Color(0xFF070D19);
    final headline = switch (r.stimulus) {
      StimulusState.idle =>
        r.phase == VisionPhase.idle ? 'Tap Start when ready' : '',
      StimulusState.waiting => 'Wait…',
      StimulusState.shown => visual ? 'TAP!' : 'Beep — TAP!',
      StimulusState.feedback =>
        r.lastLatencyMs == null
            ? 'Too early'
            : '${r.lastLatencyMs!.round()} ms',
    };
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => r.onReactionTap(),
      child: Container(
        key: const ValueKey('vis_reaction_surface'),
        color: bg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              visual ? Icons.flash_on_rounded : Icons.volume_up_rounded,
              size: 44,
              color: Colors.white.withValues(alpha: shown ? 1 : 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: shown ? 44 : 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${r.validInBlock} of ${ReactionTimeAnalyzer.trialsPerBlock} · ${visual ? 'flash' : 'beep'} block'
              '${r.falseStartsInBlock > 0 ? ' · ${r.falseStartsInBlock} too early' : ''}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
