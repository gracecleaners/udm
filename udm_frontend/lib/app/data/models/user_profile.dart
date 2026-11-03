/// The signed-in student's own profile, field-for-field with `GET /api/v1/users/me/`.
///
/// The rules the server enforces (`year_of_study` range, interest count and
/// length) are mirrored here as constants so the edit form rejects exactly the
/// input the API would, instead of round-tripping an error the user could have
/// been warned about first.
class UserProfile {
  const UserProfile({
    required this.email,
    required this.displayName,
    this.emailVerified = false,
    this.fullName = '',
    this.phoneNumber = '',
    this.photoUrl,
    this.gender = UserProfile.unspecifiedGender,
    this.country = '',
    this.city = '',
    this.university = '',
    this.campus = '',
    this.course = '',
    this.yearOfStudy,
    this.church = '',
    this.interests = const [],
    this.preferredTranslationCode = 'kjv',
  });

  static const String unspecifiedGender = 'unspecified';
  static const int minYearOfStudy = 1;
  static const int maxYearOfStudy = 13;
  static const int maxInterests = 12;
  static const int maxInterestLength = 40;
  static const List<String> genderValues = ['male', 'female', 'unspecified'];

  final String email;
  final String displayName;
  final bool emailVerified;
  final String fullName;
  final String phoneNumber;
  final String? photoUrl;
  final String gender;
  final String country;
  final String city;
  final String university;
  final String campus;
  final String course;
  final int? yearOfStudy;
  final String church;
  final List<String> interests;
  final String preferredTranslationCode;

  bool get hasCompletedDetails => university.trim().isNotEmpty && yearOfStudy != null;

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return email.isEmpty ? '?' : _initial(email);
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) return _initial(parts.first);
    return '${_initial(parts.first)}${_initial(parts.last)}';
  }

  static String _initial(String word) => word.substring(0, 1).toUpperCase();

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        emailVerified: json['is_email_verified'] as bool? ?? false,
        fullName: json['full_name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        photoUrl: json['photo'] as String?,
        gender: json['gender'] as String? ?? unspecifiedGender,
        country: json['country'] as String? ?? '',
        city: json['city'] as String? ?? '',
        university: json['university'] as String? ?? '',
        campus: json['campus'] as String? ?? '',
        course: json['course'] as String? ?? '',
        yearOfStudy: (json['year_of_study'] as num?)?.toInt(),
        church: json['church'] as String? ?? '',
        interests: (json['interests'] as List<dynamic>? ?? []).whereType<String>().toList(),
        preferredTranslationCode: json['preferred_translation_code'] as String? ?? 'kjv',
      );

  Map<String, dynamic> toJson() => {
        'email': email,
        'display_name': displayName,
        'is_email_verified': emailVerified,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'photo': photoUrl,
        'gender': gender,
        'country': country,
        'city': city,
        'university': university,
        'campus': campus,
        'course': course,
        'year_of_study': yearOfStudy,
        'church': church,
        'interests': interests,
        'preferred_translation_code': preferredTranslationCode,
      };

  /// Body for `PATCH /api/v1/users/me/`. Read-only fields are dropped so a
  /// stale photo URL can never be echoed back as if the client could write it.
  Map<String, dynamic> patchPayload() => Map.of(toJson())
    ..removeWhere((key, _) => const ['photo', 'email', 'display_name', 'is_email_verified'].contains(key));

  UserProfile copyWith({
    String? fullName,
    String? phoneNumber,
    String? gender,
    String? country,
    String? city,
    String? university,
    String? campus,
    String? course,
    int? yearOfStudy,
    String? church,
    List<String>? interests,
    String? preferredTranslationCode,
  }) =>
      UserProfile(
        email: email,
        displayName: displayName,
        emailVerified: emailVerified,
        fullName: fullName ?? this.fullName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        photoUrl: photoUrl,
        gender: gender ?? this.gender,
        country: country ?? this.country,
        city: city ?? this.city,
        university: university ?? this.university,
        campus: campus ?? this.campus,
        course: course ?? this.course,
        yearOfStudy: yearOfStudy ?? this.yearOfStudy,
        church: church ?? this.church,
        interests: interests ?? this.interests,
        preferredTranslationCode: preferredTranslationCode ?? this.preferredTranslationCode,
      );

  @override
  String toString() => 'UserProfile($email)';
}
