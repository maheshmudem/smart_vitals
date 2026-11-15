import 'package:flutter/material.dart';

import '../../core/design_system/mirror_theme.dart';
import '../../core/design_system/mirror_ui.dart';
import '../../core/state/app_state.dart';
import 'member_screens.dart';

/// Account-switcher style bottom sheet: pick the active family member,
/// add a new one, or open member management.
Future<void> showMemberSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _MemberSwitcherSheet(),
  );
}

class _MemberSwitcherSheet extends StatelessWidget {
  const _MemberSwitcherSheet();

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final nav = Navigator.of(context);

    void openAfterClose(Widget screen) {
      nav.pop();
      nav.push(MaterialPageRoute<void>(builder: (_) => screen));
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, MirrorSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Who is checking in?', style: t.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Scans and results are saved to this person',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: MirrorSpace.sm),
                itemCount: appState.subjects.length,
                itemBuilder: (context, i) {
                  final s = appState.subjects[i];
                  final selected = i == appState.activeSubjectIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      key: ValueKey('member_switch_${s.id}'),
                      selected: selected,
                      selectedTileColor: scheme.primary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MirrorRadius.md),
                      ),
                      leading: MemberAvatar(name: s.fullName),
                      title: Text(
                        s.fullName,
                        style: t.titleSmall?.copyWith(
                          color: selected ? scheme.primary : null,
                        ),
                      ),
                      subtitle: Text(memberSubtitle(s)),
                      trailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                key: const ValueKey('on'),
                                color: scheme.primary,
                              )
                            : const SizedBox(key: ValueKey('off'), width: 24),
                      ),
                      onTap: () {
                        appState.selectSubject(i);
                        nav.pop();
                      },
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: MirrorSpace.sm),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MirrorSpace.sm),
              child: Column(
                children: [
                  ListTile(
                    key: const ValueKey('member_switch_add'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MirrorRadius.md),
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      foregroundColor: scheme.primary,
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 20,
                      ),
                    ),
                    title: const Text('Add member'),
                    onTap: () => openAfterClose(const MemberFormScreen()),
                  ),
                  ListTile(
                    key: const ValueKey('member_switch_manage'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MirrorRadius.md),
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.onSurfaceVariant,
                      child: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 20,
                      ),
                    ),
                    title: const Text('Manage members'),
                    onTap: () => openAfterClose(const ManageMembersScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MirrorSpace.sm),
          ],
        ),
      ),
    );
  }
}
