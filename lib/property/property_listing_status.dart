class PropertyVerificationStatus {
  static const String draft = 'draft';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  static const values = <String>{draft, pending, approved, rejected};
}

class PropertyListingStatus {
  static const String draft = 'draft';
  static const String active = 'active';
  static const String sold = 'sold';
  static const String archived = 'archived';

  static const values = <String>{draft, active, sold, archived};
}

String derivePropertyStatus({
  required String verificationStatus,
  required String listingStatus,
  String fallback = 'pending',
}) {
  if (listingStatus == PropertyListingStatus.sold) {
    return PropertyListingStatus.sold;
  }
  if (listingStatus == PropertyListingStatus.archived) {
    return PropertyListingStatus.archived;
  }
  if (verificationStatus == PropertyVerificationStatus.draft) {
    return PropertyListingStatus.draft;
  }
  return verificationStatus.isEmpty ? fallback : verificationStatus;
}

String propertyLifecycleLabel(Map<String, dynamic> data) {
  final listingStatus =
      (data['listingStatus'] ?? PropertyListingStatus.active).toString();
  final verificationStatus =
      (data['verificationStatus'] ?? PropertyVerificationStatus.pending)
          .toString();

  if (listingStatus == PropertyListingStatus.draft) {
    return 'Draft';
  }
  if (listingStatus == PropertyListingStatus.sold) {
    return 'Sold';
  }
  if (listingStatus == PropertyListingStatus.archived) {
    return 'Archived';
  }

  return switch (verificationStatus) {
    PropertyVerificationStatus.approved => 'Live',
    PropertyVerificationStatus.rejected => 'Rejected',
    PropertyVerificationStatus.pending => 'In review',
    _ => 'Draft',
  };
}
