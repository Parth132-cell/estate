import 'package:estatex_app/services/saved_service.dart';

@Deprecated('Use SavedService directly for comparison selections.')
class ComparisonService {
  ComparisonService({SavedService? savedService})
    : _savedService = savedService ?? SavedService();

  final SavedService _savedService;

  Stream<List<String>> comparisonIds() {
    return _savedService.comparisonIds();
  }

  Future<ComparisonToggleResult> toggleComparison(String propertyId) {
    return _savedService.toggleComparison(propertyId);
  }
}
