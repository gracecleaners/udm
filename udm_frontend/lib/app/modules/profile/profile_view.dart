import 'package:udm_frontend/app/core/widgets/app_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_art.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_kit.dart';
import '../../core/widgets/state_view.dart';
import '../../core/widgets/udm_widgets.dart';
import '../../data/models/user_profile.dart';
import '../session/session_controller.dart';
import '../shell/shell_controller.dart';
import 'profile_controller.dart';

/// The Profile tab: who the student is on the server's copy, an editor for the
/// fields the API lets them write, and the only way to sign out.
class ProfileView extends GetView<SessionController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const AppText('Profile'),
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(AppIcons.settings),
          onPressed: () => Get.toNamed(AppRoutes.settings),
        ),
      ],
    ),
    body: SafeArea(
      child: Obx(
        () => switch (controller.status.value) {
          SessionStatus.unknown ||
          SessionStatus.restoring => const CenteredSlot(
            child: UdmProgress(label: 'Checking your session…'),
          ),
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
        Obx(
          () => NoticeBanner(
            message: controller.error.value,
            tone: NoticeTone.problem,
          ),
        ),
        Obx(() => NoticeBanner(message: controller.notice.value)),
        MessagePanel(
          icon: AppIcons.person,
          title: 'Not signed in',
          message:
              'Devotions, verses and articles stay readable without an account. '
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
    final result = await showModalBottomSheet<_ProfileEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProfileEditorSheet(initial: profile),
    );
    if (result != null) await session.save(result.profile, photo: result.photo);
  }

  @override
  Widget build(BuildContext context) {
    // One `Obx` over the whole body: the screen is a view of `profile`, and a
    // save changes that without changing `status`. Observing only the fields
    // read by the outer switch would leave the old values on screen.
    return Obx(() {
      final profile = session.profile.value;
      final notice = session.notice.value;
      final error = session.error.value;

      if (profile == null) {
        return const CenteredSlot(
          child: UdmProgress(
            label: 'Your profile is on this device, but not loaded yet.',
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.xl,
        ),
        children: [
          NoticeBanner(message: notice),
          NoticeBanner(message: error, tone: NoticeTone.problem),
          _IdentityCard(profile: profile, onEdit: () => _edit(context)),
          const SizedBox(height: AppSpacing.lg),
          const _WalkTiles(),
          const SizedBox(height: AppSpacing.lg),
          const _AccountRows(),
          const SizedBox(height: AppSpacing.md),
          _AccountAction(
            icon: AppIcons.settings,
            title: 'Account Settings',
            subtitle: 'Manage your account and preferences.',
            onTap: () => Get.toNamed(AppRoutes.settings),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AccountAction(
            icon: AppIcons.logout,
            title: 'Log Out',
            subtitle: 'Sign out from your account.',
            danger: true,
            onTap: () => _confirmSignOut(context, session),
          ),
        ],
      );
    });
  }
}

/// The three numbers the server keeps about this student's own walk.
///
/// Every one is counted from rows the app could also list — the devotionals
/// marked read, the guides finished — so a tile and the screen behind it can
/// never disagree. They belong to an account, so a visitor is shown the sign-in
/// path instead of three zeroes dressed up as progress.
class _WalkTiles extends GetView<ProfileController> {
  const _WalkTiles();

  @override
  Widget build(BuildContext context) => Obx(() {
    final theme = Theme.of(context);
    final numbers = controller.summary.value;
    if (numbers == null) {
      if (!controller.loadingPrivate.value) return const SizedBox.shrink();
      // The account's numbers are on their way, so the space is kept and
      // filled with the shimmer the rest of the app uses for a first load.
      return Panel(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: const Row(
          children: [
            Expanded(child: Center(child: SkeletonBox(height: 46, width: 64))),
            Expanded(child: Center(child: SkeletonBox(height: 46, width: 64))),
            Expanded(child: Center(child: SkeletonBox(height: 46, width: 64))),
          ],
        ),
      );
    }
    return Panel(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tile(
            value: '${numbers.dayStreak}',
            label: 'day streak',
            icon: AppIcons.sun,
            color: AppColors.gold,
          ),
          _Tile(
            value: '${numbers.guidesCompleted}',
            label: numbers.guidesCompleted == 1
                ? 'guide finished'
                : 'guides finished',
            icon: AppIcons.school,
            color: theme.colorScheme.primary,
          ),
          _Tile(
            value: '${numbers.readingsCompleted}',
            label: numbers.readingsCompleted == 1
                ? 'devotional read'
                : 'devotionals read',
            icon: AppIcons.bookOpen,
            color: AppColors.success,
            last: true,
          ),
        ],
      ),
    );
  });
}

/// One number, big, with the word that says what it counts.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.last = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          AppText(
            value,
            style: AppTypography.statValue(theme.textTheme.bodyLarge!.color!),
          ),
          const SizedBox(height: 2),
          AppText(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The four places a student goes from their own name.
///
/// Bookmarks are not a screen of their own: the saved verses and notes are read
/// and written in the Bible tab, where the chapter they came from is still on
/// the stack. This row moves the tab rather than opening a second copy.
class _AccountRows extends StatelessWidget {
  const _AccountRows();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(
          'Your things',
          color: theme.colorScheme.primary,
          icon: AppIcons.bookmark,
        ),
        const SizedBox(height: AppSpacing.sm),
        Panel(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              NavRow(
                icon: AppIcons.bookmarks,
                label: 'My bookmarks',
                subtitle: 'Saved verses and private notes, in the Bible tab.',
                onTap: () => Get.find<ShellController>().select(
                  ShellController.bibleTab,
                ),
              ),
              NavRow(
                icon: AppIcons.history,
                label: 'Reading history',
                subtitle: 'What you have finished, by the day you did it.',
                onTap: () => Get.toNamed(AppRoutes.readingHistory),
              ),
              NavRow(
                icon: AppIcons.school,
                label: 'My courses',
                subtitle: 'The ministry\'s guided reading, one step at a time.',
                onTap: () => Get.toNamed(AppRoutes.courses),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.deepBlue;
    return Material(
      key: danger ? const Key('udm.signOut') : null,
      color: danger ? const Color(0xFFFFEEF1) : AppColors.lightBlue,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    AppText(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.chevron, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one card on this screen that should look like the brand: the student's
/// own initials on the gradient, name and email over it.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile, required this.onEdit});

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppShadows.float,
        border: Border.all(color: AppColors.mist.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 132,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AppArt.profileCrossBanner,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                Container(color: AppColors.primaryBlue.withValues(alpha: .12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Transform.translate(
              offset: const Offset(0, -42),
              child: Column(
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: UdmAvatar(
                              initials: profile.initials,
                              size: 112,
                              photoUrl: profile.photoUrl ?? '',
                            ),
                          ),
                          Positioned(
                            right: -1,
                            bottom: 0,
                            child: Material(
                              color: AppColors.primaryBlue,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: onEdit,
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(
                                    AppIcons.camera,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              profile.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepBlue,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AppText(
                              profile.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const MetaPill(
                              icon: AppIcons.crown,
                              label: 'Learner',
                              tone: AppColors.gold,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('udm.editProfile'),
                      onPressed: onEdit,
                      icon: const Icon(AppIcons.edit, size: 18),
                      label: const AppText('Edit Profile'),
                    ),
                  ),
                  if (!profile.emailVerified) ...[
                    const SizedBox(height: 8),
                    const AppText(
                      'Email verification is not available in this build yet.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const AppText(
                    'Growing in Christ, one day at a time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditResult {
  const _ProfileEditResult(this.profile, this.photo);
  final UserProfile profile;
  final XFile? photo;
}

Future<void> _confirmSignOut(
  BuildContext context,
  SessionController session,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const AppText('Sign out?'),
      content: const AppText(
        'Your content stays readable. Your saved profile and progress stay on your account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const AppText('Cancel'),
        ),
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

/// The editable part of the profile. Produces a draft and hands it back; the
/// network call belongs to the session controller, so the sheet stays a form.
class ProfileEditorSheet extends StatefulWidget {
  const ProfileEditorSheet({super.key, required this.initial});

  static const List<
    ({String key, String label, int maxLength, TextInputType keyboard})
  >
  textFields = [
    (
      key: 'full_name',
      label: 'Full name',
      maxLength: 150,
      keyboard: TextInputType.name,
    ),
    (
      key: 'phone_number',
      label: 'Phone number',
      maxLength: 32,
      keyboard: TextInputType.phone,
    ),
    (
      key: 'university',
      label: 'University',
      maxLength: 200,
      keyboard: TextInputType.text,
    ),
    (
      key: 'campus',
      label: 'Campus',
      maxLength: 200,
      keyboard: TextInputType.text,
    ),
    (
      key: 'course',
      label: 'Course',
      maxLength: 200,
      keyboard: TextInputType.text,
    ),
    (
      key: 'church',
      label: 'Church or fellowship',
      maxLength: 200,
      keyboard: TextInputType.text,
    ),
    (key: 'city', label: 'City', maxLength: 80, keyboard: TextInputType.text),
    (
      key: 'country',
      label: 'Country',
      maxLength: 80,
      keyboard: TextInputType.text,
    ),
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

  static String translationLabel(String code) =>
      translations[code] ?? code.toUpperCase();

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
  XFile? _photo;
  Uint8List? _photoBytes;

  Future<void> _choosePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted)
        Get.snackbar(
          'Picture too large',
          'Choose a picture smaller than 5 MB.',
        );
      return;
    }
    if (mounted)
      setState(() {
        _photo = picked;
        _photoBytes = bytes;
      });
  }

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
          labelText: 'Year of study',
          counterText: '',
        ),
        validator: _validateYear,
      );
    }
    final field = ProfileEditorSheet.textFields.firstWhere(
      (entry) => entry.key == key,
    );
    return TextFormField(
      key: Key('udm.field.$key'),
      controller: _fields[key],
      maxLength: field.maxLength,
      keyboardType: field.keyboard,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: field.label, counterText: ''),
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
      Get.snackbar(
        'Interests',
        'Choose at most ${UserProfile.maxInterests} interests.',
      );
      return;
    }
    setState(() => _interests.add(label));
  }

  UserProfile _draft() {
    final year = int.tryParse(_year.text.trim());
    return UserProfile.fromJson({
      ...widget.initial.toJson(),
      for (final field in ProfileEditorSheet.textFields)
        field.key: _fields[field.key]!.text.trim(),
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
    if (year == null ||
        year < UserProfile.minYearOfStudy ||
        year > UserProfile.maxYearOfStudy) {
      return 'Between ${UserProfile.minYearOfStudy} and ${UserProfile.maxYearOfStudy}.';
    }
    return null;
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _ProfileEditResult(_draft(), _photo));
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                AppSpacing.sm,
              ),
              child: AppText(
                'Edit your details',
                style: AppTypography.editorialTitle(
                  theme.textTheme.bodyLarge!.color!,
                  size: 26,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _photoBytes != null
                          ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                          : UdmAvatar(
                              initials: widget.initial.initials,
                              photoUrl: widget.initial.photoUrl ?? '',
                              size: 64,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppText(
                          'Profile picture',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const AppText(
                          'Choose a new picture for your account',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _choosePhoto,
                    icon: const Icon(AppIcons.camera, size: 17),
                    label: const AppText('Change'),
                  ),
                ],
              ),
            ),
            // The fields scroll; the decision to save or drop stays reachable.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
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
                        decoration: InputDecoration(labelText: 'Bible version'),
                        items: ProfileEditorSheet.translations.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: AppText(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _translation = value ?? _translation,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Eyebrow(
                        'Gender',
                        color: theme.colorScheme.primary,
                        icon: AppIcons.person,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Three equal segments would clip 'Prefer not to say' on a
                      // narrow phone, so the row keeps its own width and scrolls
                      // instead of cutting a choice in half.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: ProfileEditorSheet.genders.entries
                              .map(
                                (entry) => ButtonSegment(
                                  value: entry.key,
                                  label: AppText(entry.value),
                                ),
                              )
                              .toList(),
                          selected: {_gender},
                          showSelectedIcon: false,
                          onSelectionChanged: (value) =>
                              setState(() => _gender = value.first),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Eyebrow(
                        'Interests',
                        color: theme.colorScheme.primary,
                        icon: AppIcons.sparkles,
                      ),
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
                                  onDeleted: () => setState(
                                    () => _interests.remove(interest),
                                  ),
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
                                labelText: 'Add an interest',
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.md,
              ),
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
