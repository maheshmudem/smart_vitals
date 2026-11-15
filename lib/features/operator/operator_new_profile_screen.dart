import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';
import '../anaemia/anaemia_ui_kit.dart';
import 'operator_store.dart';
import 'reference_readings_screen.dart';

const List<String> kOperatorLanguages = [
  'English',
  'Hindi',
  'Telugu',
  'Tamil',
  'Kannada',
  'Marathi',
  'Bengali',
];

/// Register a walk-in: name, sex, age or date of birth, body, phone and
/// preferred language. Continue opens their reference readings.
class OperatorNewProfileScreen extends StatefulWidget {
  const OperatorNewProfileScreen({super.key, this.store});

  final OperatorStore? store;

  @override
  State<OperatorNewProfileScreen> createState() =>
      _OperatorNewProfileScreenState();
}

class _OperatorNewProfileScreenState extends State<OperatorNewProfileScreen> {
  late final OperatorStore _store = widget.store ?? OperatorStore.instance;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _phone = TextEditingController();

  WalkInSex? _sex;
  bool _sexError = false;
  bool _useDob = false;
  DateTime? _dob;
  bool _dobError = false;
  String _language = 'English';

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _ageFromDob {
    final d = _dob;
    if (d == null) return null;
    final now = DateTime.now();
    var years = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) {
      years--;
    }
    return years;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobError = false;
      });
    }
  }

  String? _optionalRange(String? v, double min, double max, String unit) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < min || n > max) {
      return 'Enter ${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} $unit';
    }
    return null;
  }

  void _continue() {
    final okForm = _form.currentState?.validate() ?? false;
    setState(() {
      _sexError = _sex == null;
      _dobError = _useDob && _dob == null;
    });
    if (!okForm || _sex == null || (_useDob && _dob == null)) return;

    final age = _useDob ? _ageFromDob! : int.parse(_age.text);
    final person = _store.addWalkIn(
      fullName: _name.text.trim(),
      sex: _sex!,
      ageYears: age,
      dateOfBirth: _useDob ? _dob : null,
      heightCm: double.tryParse(_height.text),
      weightKg: double.tryParse(_weight.text),
      phone: _phone.text,
      language: _language,
    );
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReferenceReadingsScreen(
          person: person,
          store: _store,
          justCreated: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final decimals = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
    ];

    Widget label(String text, {String? hint}) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Text(text, style: t.labelLarge),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Text(hint, style: t.labelSmall),
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('New profile')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Live avatar preview
            Center(
              child: ValueListenableBuilder(
                valueListenable: _name,
                builder: (_, v, _) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: MirrorColors.brandGradient,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surface,
                        ),
                        child: MemberAvatar(
                          name: v.text.trim().isEmpty ? '?' : v.text,
                          radius: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.text.trim().isEmpty ? 'New walk-in' : v.text.trim(),
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Registered at ${_store.facilityName}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // About
            _section(
              context,
              icon: Icons.person_outline_rounded,
              title: 'About',
              children: [
                TextFormField(
                  key: const ValueKey('op_name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter the full name'
                      : null,
                ),
                const SizedBox(height: 16),
                label('Sex'),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<WalkInSex>(
                    key: const ValueKey('op_sex'),
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: WalkInSex.female,
                        label: Text('Female'),
                        icon: Icon(Icons.female_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: WalkInSex.male,
                        label: Text('Male'),
                        icon: Icon(Icons.male_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: WalkInSex.other,
                        label: Text('Other'),
                        icon: Icon(Icons.transgender_rounded, size: 18),
                      ),
                    ],
                    selected: {?_sex},
                    onSelectionChanged: (s) => setState(() {
                      _sex = s.isEmpty ? null : s.first;
                      _sexError = false;
                    }),
                  ),
                ),
                if (_sexError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 12),
                    child: Text(
                      'Choose one',
                      style: t.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Age
            _section(
              context,
              icon: Icons.cake_outlined,
              title: 'Age',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    key: const ValueKey('op_age_mode'),
                    showSelectedIcon: true,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Age in years')),
                      ButtonSegment(value: true, label: Text('Date of birth')),
                    ],
                    selected: {_useDob},
                    onSelectionChanged: (s) => setState(() {
                      _useDob = s.first;
                      _dobError = false;
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _useDob
                      ? Column(
                          key: const ValueKey('dob'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              key: const ValueKey('op_dob'),
                              borderRadius: BorderRadius.circular(
                                MirrorRadius.md,
                              ),
                              onTap: _pickDob,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Date of birth',
                                  prefixIcon: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.expand_more_rounded,
                                  ),
                                  errorText: _dobError
                                      ? 'Pick the date of birth'
                                      : null,
                                ),
                                child: Text(
                                  _dob == null
                                      ? 'Tap to choose'
                                      : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                                  style: t.bodyLarge?.copyWith(
                                    color: _dob == null
                                        ? scheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            if (_ageFromDob != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  left: 12,
                                ),
                                child: Text(
                                  '$_ageFromDob years old',
                                  style: t.bodySmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : TextFormField(
                          key: const ValueKey('op_age'),
                          controller: _age,
                          keyboardType: TextInputType.number,
                          inputFormatters: digits,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Age in years',
                            suffixText: 'years',
                            prefixIcon: Icon(Icons.hourglass_bottom_rounded),
                            helperText:
                                'Use this if you do not know the exact birthday.',
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null) return 'Enter the age';
                            if (n < 0 || n > 120) return 'Age must be 0–120';
                            return null;
                          },
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Body
            _section(
              context,
              icon: Icons.straighten_rounded,
              title: 'Body',
              hint: 'optional',
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('op_height'),
                        controller: _height,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: decimals,
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'cm',
                        ),
                        validator: (v) => _optionalRange(v, 40, 250, 'cm'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('op_weight'),
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: decimals,
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          suffixText: 'kg',
                        ),
                        validator: (v) => _optionalRange(v, 2, 300, 'kg'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact & language
            _section(
              context,
              icon: Icons.call_outlined,
              title: 'Contact & language',
              children: [
                TextFormField(
                  key: const ValueKey('op_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone number (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (d.isEmpty) return null;
                    if (d.length < 10 || d.length > 13) {
                      return 'Enter a 10-digit number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                MirrorDropdownField<String>(
                  key: const ValueKey('op_language'),
                  label: 'Language',
                  icon: Icons.translate_rounded,
                  value: _language,
                  items: [for (final l in kOperatorLanguages) (l, l)],
                  onChanged: (v) => setState(() => _language = v ?? _language),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'The voice coach and results use this language.',
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: PrimaryBottomButton(
        key: const ValueKey('op_continue'),
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        onPressed: _continue,
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? hint,
    required List<Widget> children,
  }) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(title, style: t.titleSmall),
                if (hint != null) ...[
                  const SizedBox(width: 6),
                  Text(hint, style: t.labelSmall),
                ],
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
