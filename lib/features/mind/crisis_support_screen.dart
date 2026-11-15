import 'package:flutter/material.dart';

import '../../core/design_system/mirror_widgets.dart';
import '../../core/services/emergency_contacts.dart';
import '../anaemia/anaemia_ui_kit.dart';

/// S-G14 Crisis Support (Spec §8 AUD-11, G-37): shown immediately when
/// PHQ-9 item 9 > 0. Calm full-screen layout, helpline buttons, "Talk to
/// someone you trust", clinician notification, and an explicit "I'm safe
/// right now" acknowledgement. Back / swipe cannot dismiss it.
class CrisisSupportScreen extends StatefulWidget {
  const CrisisSupportScreen({
    super.key,
    required this.onAcknowledged,
    this.subjectName,
  });

  /// Called with whether the clinician should be notified.
  final void Function(bool notifyClinician) onAcknowledged;
  final String? subjectName;

  @override
  State<CrisisSupportScreen> createState() => _CrisisSupportScreenState();
}

class _CrisisSupportScreenState extends State<CrisisSupportScreen> {
  bool _notifyClinician = true;
  bool _safeTicked = false;

  static const Color _bg = Color(0xFF0F3D4C);
  static const Color _card = Color(0xFF155A6E);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFFCA5A5),
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "You're not alone",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Screen spec & gates (S-G14)',
                      icon: const Icon(
                        Icons.info_outline_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () =>
                          showScreenGateLifecycleSheet(context, 'S-G14'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You said you have had thoughts of being better off dead or of hurting yourself. Those thoughts are more common than people think, and help is available right now${widget.subjectName != null ? ', ${widget.subjectName}' : ''}.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Talk to someone now — free, 24 hours',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                for (final c in EmergencyContacts.crisis) ...[
                  _callButton(c),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk to someone you trust',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'A family member, a friend, a neighbour, a teacher or a faith leader. You can show them this screen. Stay with people tonight if you can, and keep medicines and sharp objects out of reach.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  child: SwitchListTile(
                    key: const ValueKey('mind_notify_clinician'),
                    value: _notifyClinician,
                    onChanged: (v) => setState(() => _notifyClinician = v),
                    activeThumbColor: const Color(0xFF5EEAD4),
                    title: const Text(
                      'Notify my pathway clinician',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'They are told today and will contact you (G-37).',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                CheckboxListTile(
                  key: const ValueKey('mind_safe_now'),
                  value: _safeTicked,
                  onChanged: (v) => setState(() => _safeTicked = v ?? false),
                  checkColor: _bg,
                  activeColor: const Color(0xFF5EEAD4),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "I'm safe right now",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: const Text(
                    'Tick this only if you are not in immediate danger. This screen cannot be closed by accident.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('mind_crisis_continue'),
                  onPressed: _safeTicked
                      ? () => widget.onAcknowledged(_notifyClinician)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5EEAD4),
                    foregroundColor: _bg,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tele-MANAS and 112 are shown as safe defaults; region-specific numbers are configured by the programme (Q-HELPLINE).',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _callButton(EmergencyContact c) {
    return FilledButton(
      key: ValueKey('mind_call_${c.number}'),
      onPressed: () async {
        final ok = await EmergencyContacts.dial(c.number);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dial ${c.number} from your phone app.')),
          );
        }
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AnaemiaUi.ink,
        minimumSize: const Size(0, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Row(
        children: [
          const Icon(Icons.call_rounded, color: Color(0xFF0B7A75)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  c.sub,
                  style: const TextStyle(
                    color: AnaemiaUi.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AnaemiaUi.muted),
        ],
      ),
    );
  }
}
