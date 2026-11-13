import 'package:udm_frontend/app/core/localization/localized_snackbar.dart';
import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../core/widgets/language_menu_button.dart';
import '../../data/models/user_profile.dart';
import '../session/session_controller.dart';

/// The Profile tab: who the student is on the server's copy, an editor for the
/// fields the API lets them write, and the only way to sign out.
class ProfileView extends GetView<SessionController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const AppText('Profile'),
          actions: [
            const LanguageMenuButton(),
            Obx(
              () => controller.isSignedIn
                  ? IconButton(
                      key: const Key('udm.signOutAction'),
                      tooltip: 'Sign out'.tr,
                      icon: const Icon(AppIcons.logout),
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
              icon: AppIcons.person,
              title: 'Not signed in',
              message: 'Devotions, verses and articles stay readable without an account. '
                  'Sign in to save your campus details and your reading progress.',
              actionLabel: 'Sign in',
              onAction: () => Get.toNamed(AppRoutes.signIn),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('udm.registerFromProfile'),
                onPressed: () => Get.toNamed(AppRoutes.register),
                icon: const Icon(AppIcons.personAdd, size: 18),
                label: const AppText('Create an account'),
              ),
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
    // One `Obx` over the whole body: the screen is a view of `profile`, and a
    // save changes that without changing `status`. Observing only the fields
    // read by the outer switch would leave the old values on screen.
    return Obx(() {
      final theme = Theme.of(context);
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
          _IdentityCard(profile: profile),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(
            eyebrow: 'On your account',
            title: 'Your details',
            subtitle: 'Saved to your account on the UDM service.',
          ),
          const SizedBox(height: AppSpacing.md),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Column(
              children: [
                _DetailRow(icon: AppIcons.school, label: 'University', value: profile.university),
                _DetailRow(icon: AppIcons.location, label: 'Campus', value: profile.campus),
                _DetailRow(icon: AppIcons.book, label: 'Course', value: profile.course),
                _DetailRow(
                  icon: AppIcons.list,
                  label: 'Year of study',
                  value: profile.yearOfStudy == null ? '' : 'Year ${profile.yearOfStudy}',
                ),
                _DetailRow(icon: AppIcons.church, label: 'Church', value: profile.church),
                _DetailRow(
                  icon: AppIcons.home,
                  label: 'Where you live',
                  value: [profile.city, profile.country].where((part) => part.isNotEmpty).join(', '),
                ),
                _DetailRow(
                  icon: AppIcons.language,
                  label: 'Bible version',
                  value: ProfileEditorSheet.translationLabel(profile.preferredTranslationCode),
                  last: true,
                ),
              ],
            ),
          ),
          if (profile.interests.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Eyebrow('Interests', color: theme.colorScheme.primary, icon: AppIcons.sparkles),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: profile.interests
                  .map((interest) => MetaPill(icon: AppIcons.check, label: interest, tone: AppColors.gold))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('udm.editProfile'),
            onPressed: () => _edit(context),
            icon: const Icon(AppIcons.edit, size: 18),
            label: const AppText('Edit details'),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('udm.signOut'),
              onPressed: () => _confirmSignOut(context, session),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(AppIcons.logout, size: 18),
              label: const AppText('Sign out'),
            ),
          ),
        ],
      );
    });
  }
}

/// The one card on this screen that should look like the brand: the student's
/// own initials on the gradient, name and email over it.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.hero,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
        boxShadow: AppShadows.float,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: Mark.backdrop(tint: AppColors.white, alpha: 0.16)),
          const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.sheen))),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: UdmAvatar(initials: profile.initials, size: 56),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            profile.displayName,
                            style: const TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 21,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: AppColors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            profile.email,
                            style: const TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!profile.emailVerified) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusField),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(AppIcons.info, size: 14, color: Colors.white70),
                        SizedBox(width: 6),
                        Expanded(
                          child: AppText(
                            'Email verification is not available in this build yet.',
                            style: TextStyle(
                              fontFamily: AppFonts.ui,
                              fontSize: 11.5,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, SessionController session) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const AppText('Sign out?'),
      content: const AppText('Your content stays readable. Your saved profile and progress stay on your account.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const AppText('Cancel')),
        FilledButton(
          key: const Key('udm.confirmSignOut'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const AppText('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) await session.signOut();
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value, this.last = false});

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final filled = value.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          child: Row(
            children: [
              IconBadge(icon: icon, size: 32, filled: false),
              const SizedBox(width: AppSpacing.md),
              // Both sides get a share of the row instead of a fixed trailing
              // width, so a long university name wraps onto a second line rather
              // than pushing the label off a 320dp screen.
              Expanded(
                flex: 6,
                child: AppText(label, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 6,
                child: AppText(
                  filled ? value : 'Not added',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: filled ? theme.textTheme.bodyLarge?.color : theme.textTheme.bodySmall?.color,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last) Divider(height: 1, thickness: 1, color: surfaces.hairline),
      ],
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

  /// Mirrors `UDM_MEMORY_VERSE_TRANSLATIONS` on the server. All three are
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

  /// The fields in the order the sheet shows them, which is the API's own
  /// order with the year of study set beside the course it belongs to.
  static const List<String> _order = [
    'full_name',
    'phone_number',
    'university',
    'campus',
    'course',
    'year_of_study',
    'church',
    'city',
    'country',
  ];

  /// The heading each group opens with, keyed by the first field under it.
  static const Map<String, String> _groupHeads = {
    'full_name': 'Who you are',
    'university': 'Where you study',
    'church': 'Where you gather',
  };

  static const Map<String, IconData> _groupIcons = {
    'full_name': AppIcons.person,
    'university': AppIcons.school,
    'church': AppIcons.church,
  };

  Widget _field(String key, ThemeData theme) {
    if (key == 'year_of_study') {
      return TextFormField(
        key: const Key('udm.field.year_of_study'),
        controller: _year,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Year of study'.tr,
          counterText: '',
        ),
        validator: _validateYear,
      );
    }
    final field = ProfileEditorSheet.textFields.firstWhere((entry) => entry.key == key);
    return TextFormField(
      key: Key('udm.field.$key'),
      controller: _fields[key],
      maxLength: field.maxLength,
      keyboardType: field.keyboard,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: field.label.tr,
        counterText: '',
      ),
    );
  }

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
      showLocalizedSnackbar('Interests', 'Choose at most ${UserProfile.maxInterests} interests.');
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
      return 'Between @min and @max.'.trParams({
        'min': '${UserProfile.minYearOfStudy}',
        'max': '${UserProfile.maxYearOfStudy}',
      });
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
              child: AppText(
                'Edit your details',
                style: AppTypography.editorialTitle(theme.textTheme.bodyLarge!.color!, size: 26),
              ),
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
                      // The fields are the server's, in the server's order; the
                      // headings only say what each handful of them is for.
                      for (final key in _order) ...[
                        if (_groupHeads.containsKey(key)) ...[
                          Eyebrow(
                            _groupHeads[key]!,
                            color: theme.colorScheme.primary,
                            icon: _groupIcons[key]!,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _field(key, theme),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // Full width, not half a row: 'American Standard Version'
                      // needs the space on a 320dp phone.
                      DropdownButtonFormField<String>(
                        key: const Key('udm.field.translation'),
                        initialValue: _translation,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Bible version'.tr,
                        ),
                        items: ProfileEditorSheet.translations.entries
                            .map((entry) => DropdownMenuItem(value: entry.key, child: AppText(entry.value)))
                            .toList(),
                        onChanged: (value) => setState(() => _translation = value ?? _translation),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Eyebrow('Gender', color: theme.colorScheme.primary, icon: AppIcons.person),
                      const SizedBox(height: AppSpacing.sm),
                      // Three equal segments would clip 'Prefer not to say' on a
                      // narrow phone, so the row keeps its own width and scrolls
                      // instead of cutting a choice in half.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: ProfileEditorSheet.genders.entries
                              .map((entry) => ButtonSegment(value: entry.key, label: AppText(entry.value)))
                              .toList(),
                          selected: {_gender},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) => setState(() => _gender = value.first),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Eyebrow('Interests', color: theme.colorScheme.primary, icon: AppIcons.sparkles),
                      const SizedBox(height: AppSpacing.sm),
                      AppText(
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
                                  label: AppText(interest),
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
                              decoration: InputDecoration(
                                labelText: 'Add an interest'.tr,
                                counterText: '',
                              ),
                              onSubmitted: (_) => _addInterest(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filled(
                            key: const Key('udm.addInterest'),
                            onPressed: _addInterest,
                            icon: const Icon(AppIcons.add),
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
                          child: const AppText('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          key: const Key('udm.saveProfile'),
                          onPressed: _save,
                          child: const AppText('Save changes'),
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
