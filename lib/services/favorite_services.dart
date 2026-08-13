import 'package:estatex_app/services/saved_service.dart';

@Deprecated('Use SavedService directly for favorites.')
class FavoriteService {
  FavoriteService({SavedService? savedService})
    : _savedService = savedService ?? SavedService();

  final SavedService _savedService;

  Stream<bool> isSaved(String propertyId) {
    return _savedService.isFavorite(propertyId);
  }

  Future<void> toggleFavorite(String propertyId) {
    return _savedService.toggleFavorite(propertyId);
  }
}
