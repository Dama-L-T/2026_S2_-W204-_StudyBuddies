/// The existing /profile response. For another student, supply only fields
/// the backend has authorized the current viewer to see.
class StudentProfile {
  const StudentProfile({
    required this.name,
    this.userId = '',
    this.personalDetails = '',
    this.courses = '',
    this.interests = '',
    this.preferences = '',
    this.profileImage = '',
  });

  final String userId;
  final String name;
  final String personalDetails;
  final String courses;
  final String interests;
  final String preferences;
  final String profileImage;

  String? get imageUrl {
    final uri = Uri.tryParse(profileImage);
    return uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? profileImage
        : null;
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) => StudentProfile(
    userId: json['user_id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    personalDetails: json['personal_details'] as String? ?? '',
    courses: json['courses'] as String? ?? '',
    interests: json['interests'] as String? ?? '',
    preferences: json['preferences'] as String? ?? '',
    profileImage: json['profile_image'] as String? ?? '',
  );

  Map<String, String> toJson() => {
    'name': name,
    'personal_details': personalDetails,
    'courses': courses,
    'interests': interests,
    'preferences': preferences,
  };

  static List<String> values(String text) => text
      .split(RegExp(r'[,;\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
}
