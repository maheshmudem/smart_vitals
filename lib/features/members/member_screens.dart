import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/mirror_motion.dart';
import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';
import '../../core/domain/entities/enums.dart';
import '../../core/domain/entities/member_profile.dart';
import '../../core/state/app_state.dart';
import '../anaemia/anaemia_ui_kit.dart';

/// "Daughter · 7 years" / "Newborn · 72 hours" — short label for lists.
String memberSubtitle(SubjectProfile s) {
  final relation = relationOf(s);
  if (s.isNewborn) return '$relation · ${s.ageHoursForNewborn} hours old';
  return '$relation · ${s.ageYears} ${s.ageYears == 1 ? "year" : "years"}';
}

/// The relationship word without the "(26y Adult)" suffix.
String relationOf(SubjectProfile s) => s.relationship.split(' (').first.trim();

const List<String> kRelations = [
  'Self',
  'Spouse',
  'Son',
  'Daughter',
  'Father',
  'Mother',
  'Grandparent',
  'Sibling',
  'Other',
];

const List<String> kActivityLevels = ['Low', 'Moderate', 'High'];

/// Builds the stored relationship label in the app's existing style,
/// e.g. `Daughter (7y Child)` or `Son (Newborn 72h)`.
String buildRelationshipLabel(
  String relation, {
  required int ageYears,
  int? newbornHours,
}) {
  if (newbornHours != null) return '$relation (Newborn ${newbornHours}h)';
  final stage = ageYears < 13
      ? 'Child'
      : ageYears < 18
      ? 'Teen'
      : ageYears < 60
      ? 'Adult'
      : 'Senior';
  return '$relation (${ageYears}y $stage)';
}

/// S-B05 / S-B06: list, edit and remove family members.
class ManageMembersScreen extends StatelessWidget {
  const ManageMembersScreen({super.key});

  Future<void> _confirmRemove(
    BuildContext context,
    AppState appState,
    SubjectProfile s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_remove_outlined),
        title: Text('Remove ${s.fullName.split(' ').first}?'),
        content: const Text(
          'Their profile is removed from this device. Saved results stay in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('member_remove_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: MirrorColors.dangerFg,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      appState.removeMember(s.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${s.fullName} removed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    void edit(SubjectProfile s) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => MemberFormScreen(member: s)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Family Members')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('members_add_fab'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const MemberFormScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add member'),
      ),
      body: ListView(
        padding: MirrorSpace.screen.copyWith(bottom: 96),
        children: [
          PageHeading(
            title: 'Your family',
            subtitle:
                '${appState.subjects.length} ${appState.subjects.length == 1 ? "profile" : "profiles"} · tap one to edit',
          ),
          FadeSlideIn(
            child: MirrorGroupCard(
              children: [
                for (var i = 0; i < appState.subjects.length; i++)
                  _memberRow(context, appState, i, edit, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberRow(
    BuildContext context,
    AppState appState,
    int i,
    void Function(SubjectProfile) edit,
    ColorScheme scheme,
  ) {
    final s = appState.subjects[i];
    final owner = appState.isAccountOwner(s.id);
    final active = i == appState.activeSubjectIndex;
    return ListTile(
      key: ValueKey('member_row_${s.id}'),
      contentPadding: const EdgeInsets.only(left: MirrorSpace.lg, right: 4),
      leading: MemberAvatar(name: s.fullName),
      title: Row(
        children: [
          Flexible(child: Text(s.fullName, overflow: TextOverflow.ellipsis)),
          if (owner) ...[
            const SizedBox(width: 6),
            const MirrorPill(label: 'You'),
          ],
          if (active) ...[
            const SizedBox(width: 6),
            const MirrorPill(label: 'Active', color: MirrorColors.successFg),
          ],
        ],
      ),
      subtitle: Text(memberSubtitle(s)),
      onTap: () => edit(s),
      trailing: PopupMenuButton<String>(
        key: ValueKey('member_menu_${s.id}'),
        tooltip: 'More',
        icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
        position: PopupMenuPosition.under,
        onSelected: (v) {
          switch (v) {
            case 'switch':
              appState.selectSubject(i);
            case 'edit':
              edit(s);
            case 'remove':
              _confirmRemove(context, appState, s);
          }
        },
        itemBuilder: (_) => [
          if (!active)
            const PopupMenuItem(
              value: 'switch',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.swap_horiz_rounded),
                title: Text('Make active'),
              ),
            ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit'),
            ),
          ),
          if (!owner)
            const PopupMenuItem(
              value: 'remove',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: MirrorColors.dangerFg,
                ),
                title: Text(
                  'Remove',
                  style: TextStyle(color: MirrorColors.dangerFg),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Add (member == null) or edit a family member.
class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.member});

  final SubjectProfile? member;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _hours;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  String? _relation;
  bool _relationError = false;
  late BiologicalSex _sex;
  late bool _newborn;
  late bool _pregnant;
  late String _activity;

  bool get _isEdit => widget.member != null;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _name = TextEditingController(text: m?.fullName ?? '');
    _age = TextEditingController(
      text: m == null || m.isNewborn ? '' : '${m.ageYears}',
    );
    _hours = TextEditingController(
      text: m?.ageHoursForNewborn?.toString() ?? '',
    );
    _height = TextEditingController(
      text: m?.heightCm?.toStringAsFixed(0) ?? '',
    );
    _weight = TextEditingController(
      text: m?.weightKg?.toStringAsFixed(1) ?? '',
    );
    if (m != null) {
      final rel = relationOf(m);
      _relation = kRelations.contains(rel) ? rel : 'Other';
    }
    _sex = m?.sex ?? BiologicalSex.female;
    _newborn = m?.isNewborn ?? false;
    _pregnant = m?.isPregnant ?? false;
    _activity = kActivityLevels.contains(m?.activityLevel)
        ? m!.activityLevel
        : 'Moderate';
  }

  @override
  void dispose() {
    for (final c in [_name, _age, _hours, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _ageYears => _newborn ? 0 : (int.tryParse(_age.text) ?? 0);

  bool get _canBePregnant =>
      _sex == BiologicalSex.female && !_newborn && _ageYears >= 12;

  void _save() {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _relationError = _relation == null);
    if (!formOk || _relation == null) return;
    final appState = AppStateScope.of(context);
    final hours = _newborn ? int.tryParse(_hours.text) : null;
    final label = buildRelationshipLabel(
      _relation!,
      ageYears: _ageYears,
      newbornHours: hours,
    );
    final old = widget.member;
    final selfName = appState.subjects.first.fullName;
    final profile = SubjectProfile(
      id: old?.id ?? appState.newMemberId(),
      fullName: _name.text.trim(),
      relationship: label,
      ageYears: _ageYears,
      ageHoursForNewborn: hours,
      gestationWeeksForNewborn: _newborn
          ? (old?.gestationWeeksForNewborn ?? 39)
          : null,
      sex: _sex,
      heightCm: double.tryParse(_height.text),
      weightKg: double.tryParse(_weight.text),
      waistCm: old?.waistCm,
      isPregnant: _canBePregnant && _pregnant,
      pregnancyWeeks: _canBePregnant && _pregnant ? old?.pregnancyWeeks : null,
      hasFamilyHistoryDiabetes: old?.hasFamilyHistoryDiabetes ?? false,
      hasKnownDiabetes: old?.hasKnownDiabetes ?? false,
      hasKnownHypertension: old?.hasKnownHypertension ?? false,
      usesTobaccoOrAreca: old?.usesTobaccoOrAreca ?? false,
      activityLevel: _activity,
      educationYears: old?.educationYears ?? 12,
      isHeartFailureEnrolled: old?.isHeartFailureEnrolled ?? false,
      hfBaselineDaysCompleted: old?.hfBaselineDaysCompleted ?? 0,
      consents:
          old?.consents ??
          appState.consentsFor(guardian: _ageYears < 18 ? selfName : null),
      bpCalibration: old?.bpCalibration,
    );
    if (_isEdit) {
      appState.updateMember(profile.id, profile);
    } else {
      appState.addMember(profile);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEdit
              ? '${profile.fullName} updated'
              : '${profile.fullName} added and selected',
        ),
      ),
    );
  }

  String? _range(String? v, int min, int max, String what) {
    final n = int.tryParse(v ?? '');
    if (n == null) return 'Enter $what';
    if (n < min || n > max) return '$what must be $min–$max';
    return null;
  }

  String? _optionalNumber(String? v, double min, double max) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < min || n > max) return '$min–$max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimals = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Member' : 'Add Member')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: MirrorSpace.screen,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: MirrorSpace.md),
                child: ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (_, v, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: MemberAvatar(
                      key: ValueKey(v.text.trim()),
                      name: v.text.trim().isEmpty ? '?' : v.text,
                      radius: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SectionHeader(title: 'About'),
            TextFormField(
              key: const ValueKey('member_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Enter a name' : null,
            ),
            const SizedBox(height: MirrorSpace.md),
            MirrorDropdownField<String>(
              key: const ValueKey('member_relation'),
              label: 'Relationship',
              icon: Icons.diversity_3_outlined,
              value: _relation,
              items: [for (final r in kRelations) (r, r)],
              errorText: _relationError ? 'Choose a relationship' : null,
              onChanged: (v) => setState(() {
                _relation = v ?? _relation;
                _relationError = false;
              }),
            ),
            const SizedBox(height: MirrorSpace.lg),
            Text('Sex', style: t.labelLarge),
            const SizedBox(height: MirrorSpace.sm),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<BiologicalSex>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: BiologicalSex.female,
                    label: Text('Female'),
                    icon: Icon(Icons.female_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: BiologicalSex.male,
                    label: Text('Male'),
                    icon: Icon(Icons.male_rounded, size: 18),
                  ),
                ],
                selected: {_sex},
                onSelectionChanged: (s) => setState(() => _sex = s.first),
              ),
            ),
            const SizedBox(height: MirrorSpace.xl),
            const SectionHeader(title: 'Age'),
            Card(
              child: SwitchListTile(
                title: const Text('Newborn (under 4 weeks)'),
                subtitle: const Text('Enables the newborn jaundice check'),
                value: _newborn,
                onChanged: (v) => setState(() => _newborn = v),
              ),
            ),
            const SizedBox(height: MirrorSpace.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _newborn
                  ? TextFormField(
                      key: const ValueKey('member_hours'),
                      controller: _hours,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        suffixText: 'hours',
                        prefixIcon: Icon(Icons.child_friendly_outlined),
                      ),
                      validator: (v) => _range(v, 1, 672, 'Hours'),
                    )
                  : TextFormField(
                      key: const ValueKey('member_age'),
                      controller: _age,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        suffixText: 'years',
                        prefixIcon: Icon(Icons.cake_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => _range(v, 1, 120, 'Age'),
                    ),
            ),
            const SizedBox(height: MirrorSpace.xl),
            const SectionHeader(
              title: 'Body & lifestyle',
              subtitle: 'Optional · used for BMI and fitness formulas',
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _height,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: decimals,
                    decoration: const InputDecoration(
                      labelText: 'Height',
                      suffixText: 'cm',
                    ),
                    validator: (v) => _optionalNumber(v, 30, 250),
                  ),
                ),
                const SizedBox(width: MirrorSpace.md),
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: decimals,
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      suffixText: 'kg',
                    ),
                    validator: (v) => _optionalNumber(v, 1, 300),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MirrorSpace.md),
            MirrorDropdownField<String>(
              label: 'Activity level',
              icon: Icons.directions_run_rounded,
              value: _activity,
              items: [for (final a in kActivityLevels) (a, a)],
              onChanged: (v) => setState(() => _activity = v ?? _activity),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _canBePregnant
                  ? Padding(
                      padding: const EdgeInsets.only(top: MirrorSpace.md),
                      child: Card(
                        child: SwitchListTile(
                          title: const Text('Currently pregnant'),
                          subtitle: const Text(
                            'Uses the pregnancy anaemia cut-off',
                          ),
                          value: _pregnant,
                          onChanged: (v) => setState(() => _pregnant = v),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        key: const ValueKey('member_save'),
        label: _isEdit ? 'Save changes' : 'Add member',
        icon: Icons.check_rounded,
        onPressed: _save,
      ),
    );
  }
}
