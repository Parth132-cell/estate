import 'package:estatex_app/favorites/favorites_cache.dart';
import 'package:estatex_app/favorites/favorites_controller.dart';
import 'package:estatex_app/favorites/favorites_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final favoritesServiceProvider = Provider<FavoritesService>(
  (ref) => FavoritesService(),
);

final favoritesCacheProvider = Provider<FavoritesCache>(
  (ref) => SharedPrefsFavoritesCache(),
);

final favoritesControllerProvider =
    StateNotifierProvider.autoDispose<
      StateNotifier<FavoritesState>,
      FavoritesState
    >((ref) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return _GuestFavoritesController();
      }

      final controller = FavoritesController(
        service: ref.watch(favoritesServiceProvider),
        cache: ref.watch(favoritesCacheProvider),
        userId: userId,
      );

      controller.initialize();
      return controller;
    });

final isFavoriteProvider = Provider.family<bool, String>((ref, propertyId) {
  final state = ref.watch(favoritesControllerProvider);
  return state.isFavorite(propertyId);
});

final favoriteActionPendingProvider = Provider.family<bool, String>((
  ref,
  propertyId,
) {
  final state = ref.watch(favoritesControllerProvider);
  return state.isPending(propertyId);
});

class _GuestFavoritesController extends StateNotifier<FavoritesState> {
  _GuestFavoritesController()
    : super(const FavoritesState(isInitialized: true));
}
