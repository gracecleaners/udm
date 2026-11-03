import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/user_profile.dart';
import '../session/session_controller.dart';

/// The Profile tab: who the student is on the server's copy, an editor for the
/// fields the API lets them write, and the only way to sign out.
class ProfileView extends GetView<SessionController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            Obx(
              () => controller.isSignedIn
                  ? IconButton(
                      key: const Key('udm.signOutAction'),
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => _confirmSignOut(context, controller),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: SafeArea(
          child: Obx(
            () => switch (controller.status.value) {
              SessionStatus.unknown || SessionStatus.restoring =>
                const CenteredSlot(child: UdmProgress(label: 'Checking your session…')),
              SessionStatus.signedOut => const _SignedOut(),
              SessionStatus.signedIn => _ProfileBody(session: controller),
            },
          ),
        ),
      );
}

class _SignedOut extends GetView<SessionController> {
  const _SignedOut();

  @override
  Widget build(BuildContext context) => CenteredSlot(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // What the last sign-out left behind has to survive the screen
            // change, or the student never learns the session is still live on
            // the server.
            Obx(() => NoticeBanner(message: controller.error.value, tone: NoticeTone.problem)),
            Obx(() => NoticeBanner(message: controller.notice.value)),
            MessagePanel(
              icon: Icons.person_outline_rounded,
              title: 'Not signed in',
              message: 'Devotions, verses and articles stay readable without an account. '
                  'Sign in to save your campus details and your reading progress.',
              actionLabel: 'Sign in',
              onAction: () => Get.toNamed(AppRoutes.signIn),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              key: const Key('udm.registerFromProfile'),
              onPressed: () => Get.toNamed(AppRoutes.register),
              child: const Text('Create an account'),
            ),
          ],
        ),
      );
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.session});

  final SessionController session;

  Future<void> _edit(BuildContext context) async {
    final profile = session.profile.value;
    if (profile == null) return;
    final draft = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProfileEditorSheet(initial: profile),
    );
    if (draft != null) await session.save(draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // One `Obx` over the whole body: the screen is a view of `profile`, and a
    // save changes that without changing `status`. Observing only the fields
    // read by the outer switch would leave the old values on screen.
    return Obx(() {
      final profile = session.profile.value;
      final notice = session.notice.value;
      final error = session.error.value;

      if (profile == null) {
        return const CenteredSlot(
          child: UdmProgress(label: 'Your profile is on this device, but not loaded yet.'),
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.xl),
        children: [
          NoticeBanner(message: notice),
          NoticeBanner(message: error, tone: NoticeTone.problem),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.lightBlue,
                    foregroundColor: AppColors.primaryBlue,
                    child: Text(profile.initials, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(profile.email, style: theme.textTheme.bodySmall),
                        if (!profile.emailVerified) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Email verification is not available in this build yet.',
                            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Your details',
            subtitle: 'Saved to your account on the UDM service.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                _DetailRow(icon: Icons.school_outlined, label: 'University', value: profile.university),
                _DetailRow(icon: Icons.place_outlined, label: 'Campus', value: profile.campus),
                _DetailRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Course',
                  value: profile.course,
                ),
                _DetailRow(
                  icon: Icons.stairs_outlined,
                  label: 'Year of study',
                  value: profile.yearOfStudy == null ? '' : 'Year ${profile.yearOfStudy}',
                ),
                _DetailRow(icon: Icons.church_outlined, label: 'Church', value: profile.church),
                _DetailRow(
                  icon: Icons.location_city_outlined,
                  label: 'Where you live',
                  value: [profile.city, profile.country].where((part) => part.isNotEmpty).join(', '),
                ),
                _DetailRow(
                  icon: Icons.translate_rounded,
                  label: 'Bible preference',
                  value: ProfileEditorSheet.translationLabel(profile.preferredTranslationCode),
                ),
              ],
            ),
          ),
          if (profile.interests.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: profile.interests.map((interest) => Chip(label: Text(interest))).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('udm.editProfile'),
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit details'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('udm.signOut'),
            onPressed: () => _confirmSignOut(context, session),
            child: const Text('Sign out'),
          ),
        ],
      );
    });
  }
}

Future<void> _confirmSignOut(BuildContext context, SessionController session) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text('Your content stays readable. Your saved profile and progress stay on your account.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(
          key: const Key('udm.confirmSignOut'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await session.signOut();
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filled = value.trim().isNotEmpty;
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: Text(
          filled ? value : 'Not added',
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: filled ? theme.textTheme.bodyLarge?.color : AppColors.secondaryText,
            fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// The editable part of the profile. Produces a draft and hands it back; the
/// network call belongs to the session controller, so the sheet stays a form.
class ProfileEditorSheet extends StatefulWidget {
  const ProfileEditorSheet({super.key, required this.initial});

  static const List<({String key, String label, int maxLength, TextInputType keyboard})> textFields = [
    (key: 'full_name', label: 'Full name', maxLength: 150, keyboard: TextInputType.name),
    (key: 'phone_number', label: 'Phone number', maxLength: 32, keyboard: TextInputType.phone),
    (key: 'university', label: 'University', maxLength: 200, keyboard: TextInputType.text),
    (key: 'campus', label: 'Campus', maxLength: 200, keyboard: TextInputType.text),
    (key: 'course', label: 'Course', maxLength: 200, keyboard: TextInputType.text),
    (key: 'church', label: 'Church or fellowship', maxLength: 200, keyboard: TextInputType.text),
    (key: 'city', label: 'City', maxLength: 80, keyboard: TextInputType.text),
    (key: 'country', label: 'Country', maxLength: 80, keyboard: TextInputType.text),
  ];

  /// Mirrors `UDM_FEATURED_VERSE_TRANSLATIONS` on the server. All three are
  /// public-domain; a code the API does not recognise comes back as a field
  /// error rather than being saved.
  static const Map<String, String> translations = {
    'kjv': 'King James Version',
    'web': 'World English Bible',
    'asv': 'American Standard Version',
  };

  static const Map<String, String> genders = {
    'male': 'Male',
    'female': 'Female',
    'unspecified': 'Prefer not to say',
  };

  final UserProfile initial;

  static String translationLabel(String code) => translations[code] ?? code.toUpperCase();

  @override
  State<ProfileEditorSheet> createState() => _ProfileEditorSheetState();
}

class _ProfileEditorSheetState extends State<ProfileEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _year = TextEditingController();
  final TextEditingController _interest = TextEditingController();
  late final Map<String, TextEditingController> _fields;
  late String _gender;
  late String _translation;
  late List<String> _interests;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _fields = {
      for (final field in ProfileEditorSheet.textFields)
        field.key: TextEditingController(text: _valueOf(initial, field.key)),
    };
    _year.text = initial.yearOfStudy?.toString() ?? '';
    _gender = initial.gender;
    _translation = initial.preferredTranslationCode;
    _interests = List.of(initial.interests);
  }

  static String _valueOf(UserProfile profile, String key) => switch (key) {
        'full_name' => profile.fullName,
        'phone_number' => profile.phoneNumber,
        'university' => profile.university,
        'campus' => profile.campus,
        'course' => profile.course,
        'church' => profile.church,
        'city' => profile.city,
        'country' => profile.country,
        _ => '',
      };

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _year.dispose();
    _interest.dispose();
    super.dispose();
  }

  void _addInterest() {
    final label = _interest.text.trim();
    setState(_interest.clear);
    if (label.isEmpty || _interests.contains(label)) return;
    if (_interests.length >= UserProfile.maxInterests) {
      Get.snackbar('Interests', 'Choose at most ${UserProfile.maxInterests} interests.');
      return;
    }
    setState(() => _interests.add(label));
  }

  UserProfile _draft() {
    final year = int.tryParse(_year.text.trim());
    return UserProfile.fromJson({
      ...widget.initial.toJson(),
      for (final field in ProfileEditorSheet.textFields) field.key: _fields[field.key]!.text.trim(),
      'year_of_study': year,
      'gender': _gender,
      'preferred_translation_code': _translation,
      'interests': _interests,
    });
  }

  String? _validateYear(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final year = int.tryParse(text);
    if (year == null || year < UserProfile.minYearOfStudy || year > UserProfile.maxYearOfStudy) {
      return 'Between ${UserProfile.minYearOfStudy} and ${UserProfile.maxYearOfStudy}.';
    }
    return null;
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _draft());
      return;
    }
    // The offending field can be scrolled out of sight, so the reason has to
    // be stated where the button is.
    setState(() => _invalid = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.sm),
              child: Text('Edit your details', style: theme.textTheme.titleLarge),
            ),
            // The fields scroll; the decision to save or drop stays reachable.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final field in ProfileEditorSheet.textFields) ...[
                        TextFormField(
                          key: Key('udm.field.${field.key}'),
                          controller: _fields[field.key],
                          maxLength: field.maxLength,
                          keyboardType: field.keyboard,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: field.label,
                            counterText: '',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      TextFormField(
                        key: const Key('udm.field.year_of_study'),
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Year of study',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateYear,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Full width, not half a row: 'American Standard Version'
                      // needs the space on a 320dp phone.
                      DropdownButtonFormField<String>(
                        key: const Key('udm.field.translation'),
                        initialValue: _translation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bible version',
                          border: OutlineInputBorder(),
                        ),
                        items: ProfileEditorSheet.translations.entries
                            .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                            .toList(),
                        onChanged: (value) => setState(() => _translation = value ?? _translation),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Gender', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<String>(
                        segments: ProfileEditorSheet.genders.entries
                            .map((entry) => ButtonSegment(value: entry.key, label: Text(entry.value)))
                            .toList(),
                        selected: {_gender},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) => setState(() => _gender = value.first),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Interests', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Used to suggest devotion and group content. Up to ${UserProfile.maxInterests}.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (_interests.isNotEmpty)
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: _interests
                              .map(
                                (interest) => Chip(
                                  label: Text(interest),
                                  onDeleted: () => setState(() => _interests.remove(interest)),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('udm.field.interest'),
                              controller: _interest,
                              maxLength: UserProfile.maxInterestLength,
                              decoration: const InputDecoration(
                                labelText: 'Add an interest',
                                counterText: '',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _addInterest(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filled(
                            key: const Key('udm.addInterest'),
                            onPressed: _addInterest,
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_invalid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: const NoticeBanner(
                        message: 'Check the fields marked above before saving.',
                        tone: NoticeTone.problem,
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const Key('udm.saveProfile'),
                          onPressed: _save,
                          child: const Text('Save changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
