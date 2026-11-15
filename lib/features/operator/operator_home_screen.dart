import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/design_system/mirror_ui.dart';
import 'operator_new_profile_screen.dart';
import 'operator_store.dart';
import 'reference_readings_screen.dart';

/// Operator mode home: facility header, today's numbers, search,
/// "Create new profile" and the recent walk-ins list.
class OperatorHomeScreen extends StatefulWidget {
  const OperatorHomeScreen({super.key, this.store});

  /// Defaults to [OperatorStore.instance].
  final OperatorStore? store;

  @override
  State<OperatorHomeScreen> createState() => _OperatorHomeScreenState();
}

class _OperatorHomeScreenState extends State<OperatorHomeScreen> {
  late final OperatorStore _store = widget.store ?? OperatorStore.instance;
  final _search = TextEditingController();
  String _filter = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Sign out of operator mode?'),
        content: const Text(
          'Walk-in profiles and readings stay saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('operator_signout_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).maybePop();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OperatorNewProfileScreen(store: _store),
      ),
    );
  }

  void _openReadings(WalkIn w, {ReadingKind? kind}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReferenceReadingsScreen(
          person: w,
          store: _store,
          initialKind: kind,
        ),
      ),
    );
  }

  /// True when the person's latest reading is outside the normal band.
  static bool _needsFollowUp(WalkIn w) {
    final latest = w.readings.firstOrNull;
    if (latest == null) return false;
    return interpretReading(latest, w).band != SemanticBand.normal;
  }

  static bool _isToday(DateTime t) {
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final found = _store.search(_search.text);
          final waiting = found.where((w) => w.readings.isEmpty).length;
          final checked = found.length - waiting;
          final followUp = found.where(_needsFollowUp).length;
          final people = switch (_filter) {
            'Waiting' => found.where((w) => w.readings.isEmpty).toList(),
            'Checked' => found.where((w) => w.readings.isNotEmpty).toList(),
            'Follow-up' => found.where(_needsFollowUp).toList(),
            _ => found,
          };
          final today = people.where((w) => _isToday(w.createdAt)).toList();
          final earlier = people.where((w) => !_isToday(w.createdAt)).toList();
          final searching = _search.text.trim().isNotEmpty;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _header(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _createProfileCard(context),
              ),
              const SizedBox(height: 18),
              _quickReadings(context),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      searching ? 'Search results' : 'Recent walk-ins',
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$waiting waiting · $checked checked'
                      '${followUp > 0 ? ' · $followUp need follow-up' : ''}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                key: const ValueKey('walkin_filter_row'),
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (label, n) in [
                      ('All', found.length),
                      ('Waiting', waiting),
                      ('Checked', checked),
                      ('Follow-up', followUp),
                    ]) ...[
                      _filterChip(context, label, n),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: people.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: EmptyState(
                          icon: searching
                              ? Icons.search_off_rounded
                              : _filter == 'Follow-up'
                              ? Icons.verified_rounded
                              : Icons.groups_2_outlined,
                          title: searching
                              ? 'No one found'
                              : _filter == 'All'
                              ? 'No walk-ins yet'
                              : _filter == 'Follow-up'
                              ? 'No follow-ups'
                              : 'No one here',
                          message: searching
                              ? 'Try another name or phone number.'
                              : _filter == 'All'
                              ? 'Create a profile to start checking someone.'
                              : _filter == 'Follow-up'
                              ? 'Every latest reading is in the normal range.'
                              : 'Nobody is in this list right now.',
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (today.isNotEmpty) ...[
                            _groupLabel(context, 'Today', today.length),
                            for (final w in today) ...[
                              _walkInCard(context, w),
                              const SizedBox(height: 10),
                            ],
                          ],
                          if (earlier.isNotEmpty) ...[
                            _groupLabel(context, 'Earlier', earlier.length),
                            for (final w in earlier) ...[
                              _walkInCard(context, w),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String label, int n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$n',
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: scheme.outline)),
        ],
      ),
    );
  }

  /// Row of reading-type shortcuts: pick a type, then a person.
  Widget _quickReadings(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    Color tone(Color c) => dark ? Color.lerp(c, Colors.white, 0.35)! : c;
    String short(ReadingKind k) => switch (k) {
      ReadingKind.bpCuff => 'BP',
      ReadingKind.oximeter => 'SpO2',
      ReadingKind.haemoglobin => 'Hb',
      ReadingKind.hba1c => 'HbA1c',
      ReadingKind.glucose => 'Glucose',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick reading',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            key: const ValueKey('quick_reading_row'),
            children: [
              for (final k in ReadingKind.values) ...[
                if (k != ReadingKind.values.first) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MirrorRadius.md),
                      side: BorderSide(color: scheme.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('quick_reading_${k.name}'),
                      onTap: () => _pickPersonFor(k),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: tone(
                                  readingColor(k),
                                ).withValues(alpha: dark ? 0.18 : 0.11),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                readingIcon(k),
                                size: 18,
                                color: tone(readingColor(k)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                short(k),
                                maxLines: 1,
                                style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom sheet: choose who the quick reading is for.
  Future<void> _pickPersonFor(ReadingKind kind) async {
    HapticFeedback.selectionClick();
    final people = _store.search('');
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final t = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    Icon(
                      readingIcon(kind),
                      size: 20,
                      color: readingColor(kind),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${kind.label} for…',
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Choose the person', style: t.bodySmall),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  children: [
                    ListTile(
                      key: const ValueKey('quick_pick_new'),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      title: const Text('New person'),
                      subtitle: const Text('Create a profile first'),
                      onTap: () => Navigator.of(context).pop('new'),
                    ),
                    for (final w in people)
                      ListTile(
                        key: ValueKey('quick_pick_${w.id}'),
                        leading: MemberAvatar(name: w.fullName, radius: 18),
                        title: Text(
                          w.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            '${w.ageYears} y · ${w.sex.label}',
                            if (w.phone != null) w.phone!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).pop(w),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || picked == null) return;
    if (picked == 'new') {
      _openProfile();
    } else if (picked is WalkIn) {
      _openReadings(picked, kind: kind);
    }
  }

  Widget _filterChip(BuildContext context, String label, int n) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _filter == label;
    final alert = label == 'Follow-up' && n > 0;
    final dark = scheme.brightness == Brightness.dark;
    final alertColor = dark
        ? Color.lerp(MirrorColors.dangerFg, Colors.white, 0.35)!
        : MirrorColors.dangerFg;
    return InkWell(
      key: ValueKey('walkin_filter_$label'),
      borderRadius: BorderRadius.circular(MirrorRadius.pill),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(MirrorRadius.pill),
          border: Border.all(color: selected ? scheme.primary : scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.onPrimary.withValues(alpha: 0.22)
                    : alert
                    ? alertColor
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(MirrorRadius.pill),
              ),
              child: Text(
                '$n',
                style: TextStyle(
                  color: selected
                      ? scheme.onPrimary
                      : alert
                      ? Colors.white
                      : scheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, top + 4, 16, 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07263A), Color(0xFF0B5F63), Color(0xFF0B7A75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(MirrorRadius.pill),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 14,
                            color: MirrorColors.accent,
                          ),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'OPERATOR MODE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MirrorColors.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const ValueKey('operator_signout'),
                  onPressed: _signOut,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sign out'),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _store.facilityName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              _todayLabel(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat(
                        '${_store.checksToday}',
                        'Checks today',
                        Icons.favorite_rounded,
                      ),
                      const SizedBox(width: 8),
                      _stat(
                        '${_store.walkInsToday}',
                        'Walk-ins today',
                        Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(width: 8),
                      _stat(
                        '${_store.walkIns.length}',
                        'All profiles',
                        Icons.groups_2_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('operator_search'),
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name or phone number',
                      hintStyle: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(
                                Icons.cancel_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MirrorRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MirrorRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MirrorRadius.md),
                        borderSide: const BorderSide(
                          color: MirrorColors.accent,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _todayLabel() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  Widget _stat(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: MirrorColors.accent),
                const SizedBox(width: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createProfileCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(MirrorRadius.lg + 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('operator_create_profile'),
        onTap: _openProfile,
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 16,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create new profile',
                          style: t.titleSmall?.copyWith(
                            fontSize: 15,
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Register a walk-in in under a minute',
                          style: t.bodySmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: scheme.onPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} days ago';
  }

  /// Compact walk-in card: identity row (with vitals button) + one slim
  /// latest-reading row ending in a chevron.
  Widget _walkInCard(BuildContext context, WalkIn w) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dark = scheme.brightness == Brightness.dark;
    final latest = w.readings.firstOrNull;
    final checked = latest != null;
    Color tone(Color c) => dark ? Color.lerp(c, Colors.white, 0.35)! : c;
    final statusColor = tone(
      checked ? MirrorColors.successFg : MirrorColors.warningFg,
    );

    // Latest reading strip content.
    late final Widget strip;
    if (latest != null) {
      final verdict = interpretReading(latest, w);
      final style = BandVisualStyle.forBand(verdict.band);
      final vc = tone(style.foreground);
      final kc = tone(readingColor(latest.kind));
      strip = Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            vc.withValues(alpha: dark ? 0.12 : 0.07),
            scheme.surface,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(readingIcon(latest.kind), size: 16, color: kc),
            const SizedBox(width: 8),
            Text(
              readingValueText(latest),
              style: t.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                verdict.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: vc,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (w.readings.length > 1)
              Text('+${w.readings.length - 1}', style: t.labelSmall),
          ],
        ),
      );
    } else {
      strip = Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, size: 15, color: statusColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Waiting for first reading · ${_ago(w.createdAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: scheme.onSurface),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: InkWell(
        key: ValueKey('walkin_row_${w.id}'),
        onTap: () => _openReadings(w),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MemberAvatar(name: w.fullName, radius: 19),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall?.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          [
                            '${w.ageYears} y · ${w.sex.label}',
                            if (w.phone != null) w.phone!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: ValueKey('walkin_vitals_${w.id}'),
                    tooltip: checked ? 'Add reading' : 'Start check',
                    onPressed: () => _openReadings(w),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(36, 36),
                      fixedSize: const Size(36, 36),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.monitor_heart_outlined, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(width: 50),
                  Expanded(child: strip),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 36,
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
