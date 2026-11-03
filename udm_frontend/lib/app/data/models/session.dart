import '../../core/storage/token_store.dart';

/// The identity summary the API returns beside a fresh token pair.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        emailVerified: json['is_email_verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'is_email_verified': emailVerified,
      };
}

/// A signed-in student: usable tokens plus who they belong to.
class Session {
  const Session({required this.tokens, required this.user});

  final StoredTokens tokens;
  final AuthUser user;

  factory Session.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    final refresh = json['refresh'];
    final user = json['user'];
    if (access is! String || refresh is! String) {
      throw const FormatException('Expected access and refresh tokens.');
    }
    if (user is! Map<String, dynamic>) {
      throw const FormatException('Expected a user summary.');
    }
    return Session(
      tokens: StoredTokens(access: access, refresh: refresh),
      user: AuthUser.fromJson(user),
    );
  }
}
