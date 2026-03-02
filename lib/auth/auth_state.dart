class AppUser {
  final String uid;
  final String phone;
  final bool canUploadProperty;
  final bool canHostLiveTour;
  final String profileType; // individual | professional

  const AppUser({
    required this.uid,
    required this.phone,
    required this.canUploadProperty,
    required this.canHostLiveTour,
    required this.profileType,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic>? map) {
    if (map == null) {
      return AppUser(
        uid: uid,
        phone: '',
        canUploadProperty: false,
        canHostLiveTour: false,
        profileType: 'individual',
      );
    }

    return AppUser(
      uid: uid,
      phone: map['phone'] ?? '',
      canUploadProperty: map['canUploadProperty'] == true,
      canHostLiveTour: map['canHostLiveTour'] == true,
      profileType: map['profileType'] ?? 'individual',
    );
  }
}
